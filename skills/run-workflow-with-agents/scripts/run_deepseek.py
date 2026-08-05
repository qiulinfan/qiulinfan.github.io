#!/usr/bin/env python3
"""Run staged skills through Claude Code backed by DeepSeek."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any


DEFAULT_MODEL = "deepseek-v4-flash"
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
    agents: dict[str, dict[str, Any]], model: str
) -> dict[str, dict[str, Any]]:
    normalized: dict[str, dict[str, Any]] = {}
    for name, definition in agents.items():
        current = dict(definition)
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


def deepseek_environment(args: argparse.Namespace) -> dict[str, str]:
    environment = os.environ.copy()
    environment.pop("ANTHROPIC_API_KEY", None)
    if args.key_file:
        key_path = args.key_file.expanduser()
        try:
            key = key_path.read_text(encoding="utf-8").strip()
        except OSError as error:
            raise SystemExit(f"cannot read DeepSeek credential file: {key_path}") from error
        if not key or "\n" in key or "\r" in key:
            raise SystemExit("DeepSeek credential file must contain exactly one non-empty line")
        environment["ANTHROPIC_AUTH_TOKEN"] = key
    elif not environment.get("ANTHROPIC_AUTH_TOKEN"):
        key = environment.get("DEEPSEEK_API_KEY")
        if key:
            environment["ANTHROPIC_AUTH_TOKEN"] = key
        else:
            raise SystemExit(
                "provide --key-file, ANTHROPIC_AUTH_TOKEN, or DEEPSEEK_API_KEY"
            )

    environment["ANTHROPIC_BASE_URL"] = "https://api.deepseek.com/anthropic"
    environment["ANTHROPIC_MODEL"] = args.model
    environment["ANTHROPIC_DEFAULT_OPUS_MODEL"] = args.model
    environment["ANTHROPIC_DEFAULT_SONNET_MODEL"] = args.model
    environment["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = args.model
    environment["CLAUDE_CODE_SUBAGENT_MODEL"] = args.model
    environment["CLAUDE_CODE_EFFORT_LEVEL"] = args.effort
    if args.agent_teams:
        environment["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
    return environment


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, type=Path)
    prompt_group = parser.add_mutually_exclusive_group(required=True)
    prompt_group.add_argument("--prompt")
    prompt_group.add_argument("--prompt-file", type=Path)
    parser.add_argument("--key-file", type=Path)
    parser.add_argument("--model", default=DEFAULT_MODEL)
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

    project = args.project.expanduser().resolve()
    if not project.is_dir():
        raise SystemExit(f"project directory does not exist: {project}")
    prompt = read_prompt(args)

    if args.agents_file:
        agents = read_agents(args.agents_file)
        if args.skill:
            raise SystemExit("put per-agent skills in --agents-file; do not combine it with --skill")
        primary_agent = args.primary_agent
        if not primary_agent:
            raise SystemExit("--primary-agent is required with --agents-file")
    else:
        if args.primary_agent:
            raise SystemExit("--primary-agent requires --agents-file")
        agents, primary_agent = single_agent(args.skill)

    agents = normalize_agents(agents, args.model)
    if primary_agent not in agents:
        raise SystemExit(f"primary agent {primary_agent!r} is not defined")
    agents = resolve_preloaded_skills(project, agents)

    command = [
        "claude",
        "--print",
        "--output-format",
        args.output_format,
        "--setting-sources",
        "project",
        "--strict-mcp-config",
        "--permission-mode",
        args.permission_mode,
        "--model",
        args.model,
        "--agents",
        json.dumps(agents, separators=(",", ":")),
        "--agent",
        primary_agent,
    ]
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
        print(json.dumps({"command": command, "model": args.model}, indent=2))
        return

    result = subprocess.run(
        command,
        cwd=project,
        env=deepseek_environment(args),
        check=False,
    )
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
