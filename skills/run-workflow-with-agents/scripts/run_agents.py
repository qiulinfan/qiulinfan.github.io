#!/usr/bin/env python3
"""Run staged skills through Claude Code, Codex CLI, or OpenCode CLI."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any

from runtime_profile import (
    ProfileError,
    default_profile_path,
    require_ready_profile,
    resolve_agent_id,
    selected_agent_record,
)
from runtime_adapter import (
    codex_sandbox,
    install_opencode_config,
    isolate_runtime_state,
    opencode_permissions,
    provider_environment,
    skill_root,
)

NAME_LINE_RE = re.compile(r"(?m)^name:\s*([^\s#]+)\s*$")
AGENT_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")


def read_prompt(args: argparse.Namespace) -> str:
    if args.prompt_file:
        value = args.prompt_file.expanduser().read_text(encoding="utf-8")
    else:
        value = args.prompt
    if not value or not value.strip():
        raise SystemExit("the task prompt is empty")
    return value.strip()


def read_agents(path: Path) -> dict[str, dict[str, Any]]:
    try:
        value = json.loads(path.expanduser().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"cannot read agent definitions from {path}: {error}") from error
    if not isinstance(value, dict) or not value:
        raise SystemExit("agent definitions must be a non-empty JSON object")
    for name, definition in value.items():
        if not isinstance(name, str) or not AGENT_NAME_RE.fullmatch(name):
            raise SystemExit(
                "every agent name must use 1-64 ASCII letters, digits, underscores, or hyphens"
            )
        if not isinstance(definition, dict):
            raise SystemExit(f"agent {name!r} must map to a JSON object")
        if not isinstance(definition.get("description"), str):
            raise SystemExit(f"agent {name!r} must define a description")
        if not isinstance(definition.get("prompt"), str):
            raise SystemExit(f"agent {name!r} must define a prompt")
    return value


def single_agent(skills: list[str]) -> tuple[dict[str, dict[str, Any]], str]:
    return (
        {
            "worker": {
                "description": "Executes the requested task with the preloaded skills.",
                "prompt": (
                    "Complete the assigned task end to end. Follow every preloaded skill, "
                    "respect the requested scope, validate the result, and report concrete "
                    "artifacts and remaining uncertainty."
                ),
                "skills": skills,
            }
        },
        "worker",
    )


def normalize_agents(
    agents: dict[str, dict[str, Any]], model: str | None
) -> dict[str, dict[str, Any]]:
    normalized: dict[str, dict[str, Any]] = {}
    for name, definition in agents.items():
        current = dict(definition)
        if model:
            current.setdefault("model", model)
        skills = current.get("skills", [])
        if not isinstance(skills, list) or not all(
            isinstance(skill, str) and skill for skill in skills
        ):
            raise SystemExit(f"agent {name!r} has an invalid skills list")
        tools = current.get("tools", [])
        if not isinstance(tools, list) or not all(
            isinstance(tool, str) and tool for tool in tools
        ):
            raise SystemExit(f"agent {name!r} has an invalid tools list")
        normalized[name] = current
    return normalized


def manifest_name(manifest: Path) -> str:
    text = manifest.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError(f"staged skill has no YAML frontmatter: {manifest}")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise ValueError(f"staged skill frontmatter is not closed: {manifest}")
    match = NAME_LINE_RE.search(text[4:end])
    if not match:
        raise ValueError(f"staged skill has no name: {manifest}")
    return match.group(1).strip("'\"")


def resolve_staged_skill(project: Path, runtime: str, requested: str) -> str:
    root = skill_root(project, runtime)
    matches: list[tuple[str, Path]] = []
    if root.is_dir():
        for manifest in root.glob("*/SKILL.md"):
            if manifest.is_symlink() or not manifest.is_file():
                continue
            try:
                declared = manifest_name(manifest)
            except (OSError, UnicodeError, ValueError):
                continue
            if requested in (declared, manifest.parent.name) or requested.casefold() in (
                declared.casefold(),
                manifest.parent.name.casefold(),
            ):
                matches.append((declared, manifest))
    if not matches:
        raise SystemExit(f"preloaded skill is not staged as a physical file: {requested}")
    unique = {(declared, manifest.resolve()) for declared, manifest in matches}
    if len(unique) > 1:
        options = ", ".join(str(manifest) for _, manifest in sorted(unique))
        raise SystemExit(f"staged skill name {requested!r} is ambiguous: {options}")
    return next(iter(unique))[0]


def resolve_preloaded_skills(
    project: Path, runtime: str, agents: dict[str, dict[str, Any]]
) -> dict[str, dict[str, Any]]:
    resolved: dict[str, dict[str, Any]] = {}
    for agent_name, definition in agents.items():
        current = dict(definition)
        current["skills"] = [
            resolve_staged_skill(project, runtime, skill_name)
            for skill_name in definition.get("skills", [])
        ]
        resolved[agent_name] = current
    return resolved


def skill_instruction(definition: dict[str, Any]) -> str:
    skills = definition.get("skills", [])
    if not skills:
        return ""
    names = ", ".join(str(name) for name in skills)
    return f"\nLoad and follow these staged Agent Skills before work: {names}."


def role_prompt(definition: dict[str, Any]) -> str:
    return definition["prompt"].strip() + skill_instruction(definition)


def tool_name(tool: str) -> str:
    return tool.split("(", 1)[0]


def definition_tools(
    definition: dict[str, Any], global_tools: list[str]
) -> list[str]:
    tools = definition.get("tools", [])
    return [tool_name(tool) for tool in (tools or global_tools)]


def claude_command(
    args: argparse.Namespace,
    runtime: dict[str, Any],
    agents: dict[str, dict[str, Any]],
    primary_agent: str,
    model: str | None,
    prompt: str,
) -> list[str]:
    command = [
        runtime["path"],
        "--print",
        "--output-format",
        args.output_format,
        "--setting-sources",
        "project",
        "--strict-mcp-config",
        "--permission-mode",
        args.permission_mode,
        "--agents",
        json.dumps(agents, separators=(",", ":")),
        "--agent",
        primary_agent,
    ]
    if model:
        command[command.index("--agents"):command.index("--agents")] = ["--model", model]
    if not args.persist_session:
        command.append("--no-session-persistence")
    if args.output_format == "stream-json":
        command.append("--forward-subagent-text")
    if args.allowed_tool:
        command.extend(["--allowedTools", ",".join(args.allowed_tool)])
    if args.disallowed_tool:
        command.extend(["--disallowedTools", ",".join(args.disallowed_tool)])
    for config in args.mcp_config:
        command.extend(["--mcp-config", config])
    if args.max_budget_usd is not None:
        command.extend(["--max-budget-usd", str(args.max_budget_usd)])
    command.append(prompt)
    return command


def codex_prompt(
    agents: dict[str, dict[str, Any]], primary_agent: str, prompt: str
) -> str:
    primary = agents[primary_agent]
    workers = [name for name in agents if name != primary_agent]
    instructions = [
        f"Act as the {primary_agent!r} primary agent.",
        role_prompt(primary),
    ]
    if workers:
        names = ", ".join(workers)
        instructions.append(
            "Use Codex subagents for the bounded roles named here: "
            f"{names}. Spawn the required roles, keep their scopes separate, wait for "
            "their terminal results, verify their evidence, and synthesize the final result."
        )
    instructions.append(f"USER TASK:\n{prompt}")
    return "\n\n".join(instructions)


def codex_command(
    args: argparse.Namespace,
    runtime: dict[str, Any],
    project: Path,
    agents: dict[str, dict[str, Any]],
    primary_agent: str,
    model: str | None,
    prompt: str,
) -> list[str]:
    primary_tools = definition_tools(agents[primary_agent], args.allowed_tool)
    command = [runtime["path"], "exec"]
    if args.output_format != "text":
        command.append("--json")
    if not args.persist_session:
        command.append("--ephemeral")
    command.extend(
        [
            "--skip-git-repo-check",
            "--ignore-user-config",
            "--ignore-rules",
            "--sandbox",
            codex_sandbox(primary_tools, args.permission_mode),
            "-c",
            'approval_policy="never"',
            "-c",
            f'model_reasoning_effort="{args.effort}"',
        ]
    )
    if len(agents) > 1:
        command.extend(["--enable", "multi_agent"])
    if {"WebFetch", "WebSearch"}.intersection(primary_tools):
        command.extend(["-c", "sandbox_workspace_write.network_access=true"])
    all_skills = {
        skill
        for definition in agents.values()
        for skill in definition.get("skills", [])
    }
    primary_skills = set(agents[primary_agent].get("skills", []))
    disabled = sorted(all_skills - primary_skills)
    if disabled:
        values = ", ".join(
            f'{{ path = {toml_string(str(skill_root(project, "codex") / skill / "SKILL.md"))}, enabled = false }}'
            for skill in disabled
        )
        command.extend(["-c", f"skills.config=[{values}]"])
    if model:
        command.extend(["--model", model])
    command.append(codex_prompt(agents, primary_agent, prompt))
    return command


def toml_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def stage_codex_agents(
    project: Path,
    agents: dict[str, dict[str, Any]],
    primary_agent: str,
    effort: str,
    global_tools: list[str],
) -> list[Path]:
    root = project / ".codex" / "agents"
    all_skills = {
        skill
        for definition in agents.values()
        for skill in definition.get("skills", [])
    }
    paths: list[Path] = []
    for name, definition in agents.items():
        if name == primary_agent:
            continue
        path = root / f"{name}.toml"
        if path.exists() or path.is_symlink():
            raise SystemExit(f"Codex custom-agent destination already exists: {path}")
        tools = definition_tools(definition, global_tools)
        permission_mode = str(definition.get("permissionMode", "dontAsk"))
        lines = [
            f"name = {toml_string(name)}",
            f"description = {toml_string(definition['description'])}",
            f"developer_instructions = {toml_string(role_prompt(definition))}",
            f"model_reasoning_effort = {toml_string(str(definition.get('effort', effort)))}",
            f"sandbox_mode = {toml_string(codex_sandbox(tools, permission_mode))}",
        ]
        if definition.get("model"):
            lines.insert(3, f"model = {toml_string(str(definition['model']))}")
        disabled = sorted(all_skills - set(definition.get("skills", [])))
        for skill in disabled:
            lines.extend(
                [
                    "",
                    "[[skills.config]]",
                    f"path = {toml_string(str(skill_root(project, 'codex') / skill / 'SKILL.md'))}",
                    "enabled = false",
                ]
            )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


def opencode_agent_definitions(
    args: argparse.Namespace,
    agents: dict[str, dict[str, Any]],
    primary_agent: str,
) -> dict[str, Any]:
    workers = [name for name in agents if name != primary_agent]
    configured: dict[str, Any] = {}
    for name, definition in agents.items():
        tools = definition_tools(definition, args.allowed_tool)
        permission_mode = str(definition.get("permissionMode", args.permission_mode))
        permission = opencode_permissions(
            tools,
            args.disallowed_tool,
            permission_mode,
            skills=definition.get("skills", []),
        )
        if name == primary_agent and workers:
            permission["task"] = {"*": "deny", **{worker: "allow" for worker in workers}}
        elif name != primary_agent:
            permission["task"] = "deny"
        current: dict[str, Any] = {
            "description": definition["description"],
            "mode": "primary" if name == primary_agent else "subagent",
            "prompt": role_prompt(definition),
            "permission": permission,
        }
        if definition.get("model"):
            current["model"] = definition["model"]
        steps = definition.get("steps", definition.get("maxTurns"))
        if steps is not None:
            if not isinstance(steps, int) or steps < 1:
                raise SystemExit(f"agent {name!r} steps/maxTurns must be positive")
            current["steps"] = steps
        configured[name] = current
    return configured


def opencode_command(
    args: argparse.Namespace,
    runtime: dict[str, Any],
    primary_agent: str,
    model: str | None,
    prompt: str,
) -> list[str]:
    if model and "/" not in model:
        raise SystemExit("OpenCode models must use provider/model format")
    command = [runtime["path"], "run", "--pure", "--auto", "--agent", primary_agent]
    if args.output_format != "text":
        command.extend(["--format", "json"])
    if model:
        command.extend(["--model", model])
    command.extend(["--variant", args.effort, prompt])
    return command


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--runtime-profile", type=Path, default=default_profile_path())
    parser.add_argument("--workflow", default="run-workflow-with-agents")
    prompt_group = parser.add_mutually_exclusive_group(required=True)
    prompt_group.add_argument("--prompt")
    prompt_group.add_argument("--prompt-file", type=Path)
    parser.add_argument("--model")
    parser.add_argument(
        "--effort", default="max", choices=("low", "medium", "high", "xhigh", "max")
    )
    parser.add_argument(
        "--skill",
        action="append",
        default=[],
        help="staged skill to preload into the default single agent; repeat as needed",
    )
    parser.add_argument("--agents-file", type=Path)
    parser.add_argument("--primary-agent")
    parser.add_argument("--agent-teams", action="store_true")
    parser.add_argument("--allowed-tool", action="append", default=[])
    parser.add_argument("--disallowed-tool", action="append", default=[])
    parser.add_argument("--mcp-config", action="append", default=[])
    parser.add_argument(
        "--permission-mode",
        default="dontAsk",
        choices=("acceptEdits", "auto", "bypassPermissions", "manual", "dontAsk", "plan"),
    )
    parser.add_argument(
        "--output-format", default="json", choices=("json", "stream-json", "text")
    )
    parser.add_argument("--max-budget-usd", type=float)
    parser.add_argument("--timeout-seconds", type=float)
    parser.add_argument("--persist-session", action="store_true")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate and print the credential-free runtime command without launching it",
    )
    args = parser.parse_args()

    profile_path = args.runtime_profile.expanduser().resolve()
    try:
        profile = require_ready_profile(profile_path)
    except ProfileError as error:
        raise SystemExit(f"runtime profile gate stopped before workflow work:\n{error}") from error
    project = args.project.expanduser().resolve()
    if not project.is_dir():
        raise SystemExit(f"project directory does not exist: {project}")
    prompt = read_prompt(args)

    if args.agents_file:
        agents = read_agents(args.agents_file)
        if args.skill:
            raise SystemExit(
                "put per-agent skills in --agents-file; do not combine it with --skill"
            )
        primary_agent = args.primary_agent
        if not primary_agent:
            raise SystemExit("--primary-agent is required with --agents-file")
    else:
        if args.primary_agent:
            raise SystemExit("--primary-agent requires --agents-file")
        agents, primary_agent = single_agent(args.skill)

    if primary_agent not in agents:
        raise SystemExit(f"primary agent {primary_agent!r} is not defined")

    routed_pairs = [
        (skill, resolve_agent_id(profile, workflow=args.workflow, skill=skill))
        for definition in agents.values()
        for skill in definition.get("skills", [])
    ]
    if not routed_pairs:
        routed_pairs = [(None, resolve_agent_id(profile, workflow=args.workflow))]
    routed_agents = {agent_id for _, agent_id in routed_pairs}
    if len(routed_agents) != 1:
        details = ", ".join(
            f"{skill or args.workflow} -> {agent}" for skill, agent in routed_pairs
        )
        raise SystemExit(
            "cached routes require heterogeneous external runtimes, but this runner "
            f"uses one runtime per coordinated session: {details}"
        )
    route_skill = routed_pairs[0][0]
    try:
        runtime = selected_agent_record(
            profile, workflow=args.workflow, skill=route_skill
        )
    except ProfileError as error:
        raise SystemExit(f"cached agent route is not runnable:\n{error}") from error
    runtime_id = runtime["id"]
    runtime_configuration = runtime["configuration"]
    model = args.model or runtime_configuration["runtime"].get("model")
    agents = normalize_agents(agents, model)
    agents = resolve_preloaded_skills(project, runtime_id, agents)

    if args.max_budget_usd is not None and args.max_budget_usd <= 0:
        raise SystemExit("--max-budget-usd must be positive")
    if args.timeout_seconds is not None and args.timeout_seconds <= 0:
        raise SystemExit("--timeout-seconds must be positive")
    if args.max_budget_usd is not None and runtime_id != "claude-code":
        raise SystemExit(
            "--max-budget-usd is available only in Claude Code; "
            "use --timeout-seconds for Codex or OpenCode"
        )
    if args.agent_teams and runtime_id != "claude-code":
        raise SystemExit("--agent-teams is an experimental Claude Code-only mode")
    if args.mcp_config and runtime_id != "claude-code":
        raise SystemExit(
            "--mcp-config currently accepts Claude Code config only; configure MCP "
            "as project runtime state for Codex or OpenCode"
        )

    if runtime_id == "claude-code":
        command = claude_command(args, runtime, agents, primary_agent, model, prompt)
    elif runtime_id == "codex":
        command = codex_command(
            args, runtime, project, agents, primary_agent, model, prompt
        )
    elif runtime_id == "opencode":
        command = opencode_command(args, runtime, primary_agent, model, prompt)
    else:
        raise SystemExit(f"unsupported runtime: {runtime_id}")

    runtime_artifacts = (
        [str(project / ".codex" / "agents" / f"{name}.toml") for name in agents if name != primary_agent]
        if runtime_id == "codex"
        else []
    )

    if args.dry_run:
        print(
            json.dumps(
                {
                    "command": command,
                    "runtime_profile": str(profile_path),
                    "runtime_agent": runtime["id"],
                    "workflow": args.workflow,
                    "auth_mode": runtime_configuration["authentication"]["mode"],
                    "model": model or "runtime-default",
                    "runtime_artifacts": runtime_artifacts,
                    "timeout_seconds": args.timeout_seconds,
                },
                indent=2,
            )
        )
        return

    try:
        environment, _ = provider_environment(
            runtime_configuration,
            runtime_id,
            model,
            args.effort,
            agent_teams=args.agent_teams,
        )
    except RuntimeError as error:
        raise SystemExit(str(error)) from error

    if runtime_id == "codex" and len(agents) > 1:
        stage_codex_agents(
            project, agents, primary_agent, args.effort, args.allowed_tool
        )
    elif runtime_id == "opencode":
        primary_permissions = opencode_permissions(
            definition_tools(agents[primary_agent], args.allowed_tool),
            args.disallowed_tool,
            args.permission_mode,
            skills=agents[primary_agent].get("skills", []),
        )
        install_opencode_config(
            environment,
            permissions=primary_permissions,
            agents=opencode_agent_definitions(args, agents, primary_agent),
            provider_runtime=(
                runtime_configuration["runtime"]
                if runtime_configuration["authentication"]["mode"] == "api"
                else None
            ),
        )

    temporary_state = None
    if not args.persist_session:
        try:
            temporary_state = isolate_runtime_state(
                environment,
                runtime_id,
                runtime_configuration["authentication"]["mode"],
            )
        except RuntimeError as error:
            raise SystemExit(str(error)) from error
    try:
        try:
            result = subprocess.run(
                command,
                cwd=project,
                env=environment,
                check=False,
                timeout=args.timeout_seconds,
            )
        except subprocess.TimeoutExpired as error:
            raise SystemExit(
                f"runtime exceeded --timeout-seconds ({error.timeout}); process terminated"
            ) from error
    finally:
        if temporary_state is not None:
            temporary_state.cleanup()
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
