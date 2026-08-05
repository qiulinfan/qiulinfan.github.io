#!/usr/bin/env python3
"""Run isolated Claude Code trials against exactly one Agent Skill."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
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


def provider_environment(
    args: argparse.Namespace, profile: dict[str, Any], model: str | None
) -> tuple[dict[str, str], bytes | None]:
    environment = os.environ.copy()
    for name in (
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_AUTH_TOKEN",
        "ANTHROPIC_BASE_URL",
        "ANTHROPIC_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL",
        "ANTHROPIC_DEFAULT_SONNET_MODEL",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "CLAUDE_CODE_SUBAGENT_MODEL",
        "DEEPSEEK_API_KEY",
    ):
        environment.pop(name, None)

    authentication = profile["authentication"]
    if authentication["mode"] == "subscription":
        environment["CLAUDE_CODE_EFFORT_LEVEL"] = args.effort
        return environment, None

    runtime = profile["runtime"]
    key_path = Path(authentication["credential_file"])
    try:
        key = key_path.read_text(encoding="utf-8").strip()
    except OSError as error:
        raise SystemExit(f"cannot read configured credential file: {key_path}") from error
    if runtime.get("provider") != "deepseek" or not model:
        raise SystemExit("configured API runtime must be DeepSeek with a model")
    environment["ANTHROPIC_AUTH_TOKEN"] = key
    environment["ANTHROPIC_BASE_URL"] = runtime["base_url"]
    environment["ANTHROPIC_MODEL"] = model
    environment["ANTHROPIC_DEFAULT_OPUS_MODEL"] = model
    environment["ANTHROPIC_DEFAULT_SONNET_MODEL"] = model
    environment["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = model
    environment["CLAUDE_CODE_SUBAGENT_MODEL"] = model
    environment["CLAUDE_CODE_EFFORT_LEVEL"] = args.effort
    return environment, key.encode("utf-8")


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
    existing_skills = list((fixture / ".claude" / "skills").glob("*/SKILL.md"))
    if existing_skills:
        paths = ", ".join(str(path) for path in existing_skills)
        raise SystemExit(f"fixture must not contain preloaded skills: {paths}")
    for path in fixture.rglob("*"):
        if not path.is_symlink():
            continue
        target = path.resolve(strict=False)
        if target != fixture and fixture not in target.parents:
            raise SystemExit(f"fixture symlink escapes its root: {path} -> {target}")


def runtime_metrics(stdout: str) -> tuple[dict[str, Any], bool]:
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError:
        return {"json_parse_error": True}, False
    if not isinstance(payload, dict):
        return {"json_parse_error": True}, False
    fields = (
        "subtype",
        "is_error",
        "api_error_status",
        "terminal_reason",
        "duration_ms",
        "duration_api_ms",
        "num_turns",
        "total_cost_usd",
        "permission_denials",
        "usage",
        "modelUsage",
    )
    metrics = {field: payload[field] for field in fields if field in payload}
    return metrics, not bool(payload.get("is_error", False))


def trial_command(
    args: argparse.Namespace,
    runtime: dict[str, Any],
    skill: str,
    prompt: str,
    model: str | None,
) -> list[str]:
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


def stage_one(source: Path, name: str, project: Path) -> None:
    existing = list((project / ".claude" / "skills").glob("*/SKILL.md"))
    if existing:
        paths = ", ".join(str(path) for path in existing)
        raise RuntimeError(f"fixture already contains skills: {paths}")
    destination = project / ".claude" / "skills" / name
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
) -> dict[str, Any]:
    trial_id = f"trial-{index:04d}"
    project = output / "trials" / trial_id
    result_dir = output / "results" / trial_id
    shutil.copytree(fixture, project, symlinks=True)
    stage_one(source, name, project)
    before = inventory(project)
    command = trial_command(args, runtime, name, prompt, model)

    started = time.monotonic()
    completed = subprocess.run(
        command,
        cwd=project,
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    duration = time.monotonic() - started
    after = inventory(project)
    metrics, result_ok = runtime_metrics(completed.stdout)
    runtime_ok = completed.returncode == 0 and result_ok

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
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    profile_path = args.runtime_profile.expanduser().resolve()
    try:
        profile = require_ready_profile(profile_path)
    except ProfileError as error:
        raise SystemExit(f"runtime profile gate stopped before test work:\n{error}") from error
    model = args.model or profile.get("runtime", {}).get("model")

    if args.trials < 1 or args.parallel < 1:
        raise SystemExit("--trials and --parallel must be positive")
    if args.parallel > args.trials:
        raise SystemExit("--parallel cannot exceed --trials")
    if args.max_budget_usd_per_trial is not None and args.max_budget_usd_per_trial <= 0:
        raise SystemExit("--max-budget-usd-per-trial must be positive")

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
                    "auth_mode": profile["authentication"]["mode"],
                    "model": model or "runtime-default",
                    "trials": args.trials,
                    "parallel": args.parallel,
                    "command": command,
                },
                indent=2,
            )
        )
        return

    environment, secret = provider_environment(args, profile, model)
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
        "auth_mode": profile["authentication"]["mode"],
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
