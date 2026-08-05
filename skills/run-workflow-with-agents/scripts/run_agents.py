#!/usr/bin/env python3
"""Run staged skills through the configured machine-local external agent."""

from __future__ import annotations

import argparse
import json
import os
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

NAME_LINE_RE = re.compile(r"(?m)^name:\s*([^\s#]+)\s*$")


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
        if not isinstance(name, str) or not name:
            raise SystemExit("every agent must have a non-empty string name")
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


def resolve_staged_skill(project: Path, requested: str) -> str:
    root = project / ".claude" / "skills"
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
    project: Path, agents: dict[str, dict[str, Any]]
) -> dict[str, dict[str, Any]]:
    resolved: dict[str, dict[str, Any]] = {}
    for agent_name, definition in agents.items():
        current = dict(definition)
        current["skills"] = [
            resolve_staged_skill(project, skill_name)
            for skill_name in definition.get("skills", [])
        ]
        resolved[agent_name] = current
    return resolved


def runtime_environment(
    args: argparse.Namespace, profile: dict[str, Any], model: str | None
) -> dict[str, str]:
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
    if authentication["mode"] == "api":
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
    if args.agent_teams:
        environment["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
    return environment


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
    parser.add_argument("--persist-session", action="store_true")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate and print the credential-free Claude command without launching it",
    )
    args = parser.parse_args()

    profile_path = args.runtime_profile.expanduser().resolve()
    try:
        profile = require_ready_profile(profile_path)
    except ProfileError as error:
        raise SystemExit(f"runtime profile gate stopped before workflow work:\n{error}") from error
    model = args.model or profile.get("runtime", {}).get("model")

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

    agents = normalize_agents(agents, model)
    if primary_agent not in agents:
        raise SystemExit(f"primary agent {primary_agent!r} is not defined")
    agents = resolve_preloaded_skills(project, agents)

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
        if args.max_budget_usd <= 0:
            raise SystemExit("--max-budget-usd must be positive")
        command.extend(["--max-budget-usd", str(args.max_budget_usd)])
    command.append(prompt)

    if args.dry_run:
        print(
            json.dumps(
                {
                    "command": command,
                    "runtime_profile": str(profile_path),
                    "runtime_agent": runtime["id"],
                    "workflow": args.workflow,
                    "auth_mode": profile["authentication"]["mode"],
                    "model": model or "runtime-default",
                },
                indent=2,
            )
        )
        return

    result = subprocess.run(
        command,
        cwd=project,
        env=runtime_environment(args, profile, model),
        check=False,
    )
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
