#!/usr/bin/env python3
"""Run isolated external-agent trials against exactly one Agent Skill."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

from runtime_profile import (
    ProfileError,
    default_profile_path,
    require_ready_profile,
    selected_agent_record,
)
from runtime_adapter import (
    all_staged_manifests,
    codex_sandbox,
    install_opencode_config,
    isolate_runtime_state,
    opencode_permissions,
    provider_environment,
    runtime_metrics,
    skill_root,
)
from stage_skill import default_roots, resolve_skill, skill_name
from workspace_guard import inventory


def read_prompt(args: argparse.Namespace) -> str:
    if args.prompt_file:
        value = args.prompt_file.expanduser().read_text(encoding="utf-8")
    else:
        value = args.prompt
    if not value or not value.strip():
        raise SystemExit("the trial prompt is empty")
    return value.strip()


def credential_occurrences(root: Path, secret: bytes | None) -> list[str]:
    if secret is None:
        return []
    hits: list[str] = []
    for relative in inventory(root):
        path = root / relative
        if path.is_symlink() or not path.is_file():
            continue
        try:
            if secret in path.read_bytes():
                hits.append(relative)
        except OSError:
            continue
    return sorted(hits)


def workspace_diff(before: dict[str, str], after: dict[str, str]) -> dict[str, list[str]]:
    before_names = set(before)
    after_names = set(after)
    return {
        "added": sorted(after_names - before_names),
        "changed": sorted(
            name for name in before_names & after_names if before[name] != after[name]
        ),
        "deleted": sorted(before_names - after_names),
    }


def validate_fixture(fixture: Path) -> None:
    existing_skills = all_staged_manifests(fixture)
    if existing_skills:
        paths = ", ".join(str(path) for path in existing_skills)
        raise SystemExit(f"fixture must not contain preloaded skills: {paths}")
    for path in fixture.rglob("*"):
        if not path.is_symlink():
            continue
        target = path.resolve(strict=False)
        if target != fixture and fixture not in target.parents:
            raise SystemExit(f"fixture symlink escapes its root: {path} -> {target}")


def trial_command(
    args: argparse.Namespace,
    runtime: dict[str, Any],
    skill: str,
    prompt: str,
    model: str | None,
) -> list[str]:
    runtime_id = runtime["id"]
    skill_prompt = (
        f"Load and follow the staged {skill!r} Agent Skill before doing the task. "
        "Complete the request as an end user supplied it, stay inside the fixture, "
        "validate required artifacts, and report concrete results.\n\n"
        f"USER TASK:\n{prompt}"
    )
    if runtime_id == "codex":
        command = [
            runtime["path"],
            "exec",
            "--json",
            "--ephemeral",
            "--skip-git-repo-check",
            "--ignore-user-config",
            "--ignore-rules",
            "--sandbox",
            codex_sandbox(args.allowed_tool, args.permission_mode),
            "-c",
            'approval_policy="never"',
            "-c",
            f'model_reasoning_effort="{args.effort}"',
        ]
        if model:
            command.extend(["--model", model])
        if {"WebFetch", "WebSearch"}.intersection(args.allowed_tool):
            command.extend(["-c", "sandbox_workspace_write.network_access=true"])
        command.append(skill_prompt)
        return command

    if runtime_id == "opencode":
        if model and "/" not in model:
            raise SystemExit("OpenCode models must use provider/model format")
        command = [
            runtime["path"],
            "run",
            "--format",
            "json",
            "--pure",
            "--auto",
            "--agent",
            "build",
            "--variant",
            args.effort,
        ]
        if model:
            command.extend(["--model", model])
        command.append(skill_prompt)
        return command

    agent_definition: dict[str, Any] = {
        "description": "Executes one isolated natural task with the skill under test.",
        "prompt": (
            "Complete the assigned task as an end user requested it. Follow the "
            "preloaded skill exactly, stay within the fixture, validate required "
            "artifacts, and report concrete results."
        ),
        "skills": [skill],
    }
    if model:
        agent_definition["model"] = model
    agents = {
        "skill-trial": {
            **agent_definition,
        }
    }
    command = [
        runtime["path"],
        "--print",
        "--output-format",
        "json",
        "--no-session-persistence",
        "--setting-sources",
        "project",
        "--strict-mcp-config",
        "--permission-mode",
        args.permission_mode,
        "--agents",
        json.dumps(agents, separators=(",", ":")),
        "--agent",
        "skill-trial",
    ]
    if model:
        command[command.index("--agents"):command.index("--agents")] = ["--model", model]
    if args.allowed_tool:
        command.extend(["--allowedTools", ",".join(args.allowed_tool)])
    if args.disallowed_tool:
        command.extend(["--disallowedTools", ",".join(args.disallowed_tool)])
    for config in args.mcp_config:
        command.extend(["--mcp-config", config])
    if args.max_budget_usd_per_trial is not None:
        command.extend(
            ["--max-budget-usd", str(args.max_budget_usd_per_trial)]
        )
    command.append(prompt)
    return command


def stage_one(source: Path, name: str, project: Path, runtime: str) -> None:
    existing = all_staged_manifests(project)
    if existing:
        paths = ", ".join(str(path) for path in existing)
        raise RuntimeError(f"fixture already contains skills: {paths}")
    destination = skill_root(project, runtime) / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination, symlinks=False)
    manifest = destination / "SKILL.md"
    if manifest.is_symlink() or not manifest.is_file():
        raise RuntimeError(f"staged manifest is not a physical file: {manifest}")


def run_trial(
    index: int,
    args: argparse.Namespace,
    source: Path,
    name: str,
    fixture: Path,
    output: Path,
    prompt: str,
    environment: dict[str, str],
    secret: bytes | None,
    runtime: dict[str, Any],
    model: str | None,
    auth_mode: str,
    profile_runtime: dict[str, Any],
) -> dict[str, Any]:
    trial_id = f"trial-{index:04d}"
    project = output / "trials" / trial_id
    result_dir = output / "results" / trial_id
    shutil.copytree(fixture, project, symlinks=True)
    stage_one(source, name, project, runtime["id"])
    before = inventory(project)
    command = trial_command(args, runtime, name, prompt, model)
    trial_environment = environment.copy()
    if runtime["id"] == "opencode":
        install_opencode_config(
            trial_environment,
            permissions=opencode_permissions(
                args.allowed_tool,
                args.disallowed_tool,
                args.permission_mode,
                skills=[name],
            ),
            provider_runtime=(
                profile_runtime if auth_mode == "api" else None
            ),
        )
    temporary_state = isolate_runtime_state(
        trial_environment,
        runtime["id"],
        auth_mode,
    )

    started = time.monotonic()
    timed_out = False
    try:
        try:
            completed = subprocess.run(
                command,
                cwd=project,
                env=trial_environment,
                check=False,
                capture_output=True,
                text=True,
                timeout=args.timeout_seconds_per_trial,
            )
        except subprocess.TimeoutExpired as error:
            timed_out = True
            completed = subprocess.CompletedProcess(
                command,
                124,
                error.stdout or "",
                error.stderr or "",
            )
    finally:
        if temporary_state is not None:
            temporary_state.cleanup()
    duration = time.monotonic() - started
    if isinstance(completed.stdout, bytes):
        completed.stdout = completed.stdout.decode("utf-8", errors="replace")
    if isinstance(completed.stderr, bytes):
        completed.stderr = completed.stderr.decode("utf-8", errors="replace")
    after = inventory(project)
    metrics, result_ok = runtime_metrics(runtime["id"], completed.stdout)
    runtime_ok = completed.returncode == 0 and result_ok and not timed_out

    result_dir.mkdir(parents=True)
    (result_dir / "stdout.json").write_text(completed.stdout, encoding="utf-8")
    (result_dir / "stderr.txt").write_text(completed.stderr, encoding="utf-8")
    credential_hits = [
        f"project/{relative}"
        for relative in credential_occurrences(project, secret)
    ]
    if secret is not None and secret in completed.stdout.encode("utf-8"):
        credential_hits.append("result/stdout.json")
    if secret is not None and secret in completed.stderr.encode("utf-8"):
        credential_hits.append("result/stderr.txt")
    metadata = {
        "trial": trial_id,
        "project": str(project),
        "returncode": completed.returncode,
        "runtime_ok": runtime_ok,
        "timed_out": timed_out,
        "wall_seconds": duration,
        "runtime_agent": runtime["id"],
        "model_configured": model or "runtime-default",
        "runtime_metrics": metrics,
        "workspace": workspace_diff(before, after),
        "credential_occurrences": credential_hits,
    }
    (result_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skill", required=True)
    parser.add_argument("--skill-root", action="append", default=[], type=Path)
    parser.add_argument("--fixture", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--runtime-profile", type=Path, default=default_profile_path())
    prompt_group = parser.add_mutually_exclusive_group(required=True)
    prompt_group.add_argument("--prompt")
    prompt_group.add_argument("--prompt-file", type=Path)
    parser.add_argument("--model")
    parser.add_argument(
        "--effort", default="max", choices=("low", "medium", "high", "xhigh", "max")
    )
    parser.add_argument("--trials", type=int, default=1)
    parser.add_argument("--parallel", type=int, default=1)
    parser.add_argument("--allowed-tool", action="append", default=[])
    parser.add_argument("--disallowed-tool", action="append", default=[])
    parser.add_argument("--mcp-config", action="append", default=[])
    parser.add_argument(
        "--permission-mode",
        default="dontAsk",
        choices=("acceptEdits", "auto", "bypassPermissions", "manual", "dontAsk", "plan"),
    )
    parser.add_argument("--max-budget-usd-per-trial", type=float)
    parser.add_argument("--timeout-seconds-per-trial", type=float)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    profile_path = args.runtime_profile.expanduser().resolve()
    try:
        profile = require_ready_profile(profile_path)
    except ProfileError as error:
        raise SystemExit(f"runtime profile gate stopped before test work:\n{error}") from error
    if args.trials < 1 or args.parallel < 1:
        raise SystemExit("--trials and --parallel must be positive")
    if args.parallel > args.trials:
        raise SystemExit("--parallel cannot exceed --trials")
    if args.max_budget_usd_per_trial is not None and args.max_budget_usd_per_trial <= 0:
        raise SystemExit("--max-budget-usd-per-trial must be positive")
    if args.timeout_seconds_per_trial is not None and args.timeout_seconds_per_trial <= 0:
        raise SystemExit("--timeout-seconds-per-trial must be positive")

    fixture = args.fixture.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if not fixture.is_dir():
        raise SystemExit(f"fixture directory does not exist: {fixture}")
    validate_fixture(fixture)
    if output.exists():
        raise SystemExit(f"output path already exists: {output}")
    if fixture == output or fixture in output.parents:
        raise SystemExit("output must not be inside the fixture")
    roots = [*args.skill_root, *default_roots()]
    source = resolve_skill(args.skill, roots)
    if source == fixture or fixture in source.parents:
        raise SystemExit("target skill source must be outside the fixture")
    if source == output or source in output.parents:
        raise SystemExit("output must not be inside the target skill source")
    try:
        name = skill_name(source / "SKILL.md")
    except (OSError, UnicodeError, ValueError) as error:
        raise SystemExit(str(error)) from error
    try:
        runtime = selected_agent_record(
            profile, workflow="test-skill-with-agent", skill=name
        )
    except ProfileError as error:
        raise SystemExit(f"cached agent route is not runnable:\n{error}") from error
    runtime_configuration = runtime["configuration"]
    model = args.model or runtime_configuration["runtime"].get("model")
    if args.max_budget_usd_per_trial is not None and runtime["id"] != "claude-code":
        raise SystemExit(
            "--max-budget-usd-per-trial is available only in Claude Code; "
            "use --timeout-seconds-per-trial for Codex or OpenCode"
        )
    if args.mcp_config and runtime["id"] != "claude-code":
        raise SystemExit(
            "--mcp-config currently accepts Claude Code config only; configure MCP "
            "as project runtime state for Codex or OpenCode"
        )
    prompt = read_prompt(args)
    command = trial_command(args, runtime, name, prompt, model)
    if args.dry_run:
        print(
            json.dumps(
                {
                    "skill": name,
                    "source": str(source),
                    "runtime_profile": str(profile_path),
                    "runtime_agent": runtime["id"],
                    "auth_mode": runtime_configuration["authentication"]["mode"],
                    "model": model or "runtime-default",
                    "trials": args.trials,
                    "parallel": args.parallel,
                    "command": command,
                    "timeout_seconds_per_trial": args.timeout_seconds_per_trial,
                    "native_usd_budget": runtime["id"] == "claude-code",
                    "staged_skill_root": str(skill_root(fixture, runtime["id"])),
                },
                indent=2,
            )
        )
        return

    try:
        environment, secret = provider_environment(
            runtime_configuration, runtime["id"], model, args.effort
        )
    except RuntimeError as error:
        raise SystemExit(str(error)) from error
    (output / "trials").mkdir(parents=True)
    (output / "results").mkdir(parents=True)
    results: list[dict[str, Any]] = []
    harness_errors: list[dict[str, str]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.parallel) as executor:
        futures = {
            executor.submit(
                run_trial,
                index,
                args,
                source,
                name,
                fixture,
                output,
                prompt,
                environment,
                secret,
                runtime,
                model,
                runtime_configuration["authentication"]["mode"],
                runtime_configuration["runtime"],
            ): index
            for index in range(1, args.trials + 1)
        }
        for future in concurrent.futures.as_completed(futures):
            index = futures[future]
            try:
                results.append(future.result())
            except Exception as error:  # preserve every orchestration failure
                harness_errors.append(
                    {
                        "trial": f"trial-{index:04d}",
                        "error": f"{type(error).__name__}: {error}",
                    }
                )

    results.sort(key=lambda item: item["trial"])
    harness_errors.sort(key=lambda item: item["trial"])
    summary = {
        "skill": name,
        "source": str(source),
        "runtime_profile": str(profile_path),
        "runtime_agent": runtime["id"],
        "auth_mode": runtime_configuration["authentication"]["mode"],
        "model_configured": model or "runtime-default",
        "trials_requested": args.trials,
        "parallel": args.parallel,
        "runtime_ok": sum(1 for item in results if item["runtime_ok"]),
        "runtime_failed": sum(1 for item in results if not item["runtime_ok"]),
        "harness_errors": harness_errors,
        "results": results,
    }
    (output / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    if summary["runtime_failed"] or harness_errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
