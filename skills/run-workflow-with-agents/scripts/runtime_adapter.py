#!/usr/bin/env python3
"""Shared adapters for Claude Code, Codex CLI, and OpenCode CLI."""

from __future__ import annotations

import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Any


RUNTIMES = ("claude-code", "codex", "opencode")
SKILL_ROOTS = {
    "claude-code": Path(".claude/skills"),
    "codex": Path(".agents/skills"),
    "opencode": Path(".opencode/skills"),
}
TOOL_PERMISSIONS = {
    "Read": "read",
    "Grep": "grep",
    "Glob": "glob",
    "List": "list",
    "Bash": "bash",
    "Edit": "edit",
    "Write": "edit",
    "WebFetch": "webfetch",
    "WebSearch": "websearch",
    "Agent": "task",
    "Task": "task",
    "Skill": "skill",
}
SENSITIVE_ENVIRONMENT = (
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "CLAUDE_CODE_SUBAGENT_MODEL",
    "CLAUDE_CODE_EFFORT_LEVEL",
    "CODEX_API_KEY",
    "OPENAI_API_KEY",
    "OPENAI_BASE_URL",
    "DEEPSEEK_API_KEY",
    "OPENCODE_CONFIG",
    "OPENCODE_CONFIG_CONTENT",
    "OPENCODE_CONFIG_DIR",
)


def skill_root(project: Path, runtime: str) -> Path:
    try:
        return project / SKILL_ROOTS[runtime]
    except KeyError as error:
        raise ValueError(f"unsupported runtime: {runtime}") from error


def all_staged_manifests(project: Path) -> list[Path]:
    return sorted(
        manifest
        for relative in SKILL_ROOTS.values()
        for manifest in (project / relative).glob("*/SKILL.md")
    )


def provider_environment(
    profile: dict[str, Any],
    runtime: str,
    model: str | None,
    effort: str,
    *,
    agent_teams: bool = False,
) -> tuple[dict[str, str], bytes | None]:
    """Build a credential-safe child environment for one selected runtime."""
    environment = os.environ.copy()
    for name in SENSITIVE_ENVIRONMENT:
        environment.pop(name, None)

    authentication = profile["authentication"]
    if authentication["mode"] == "subscription":
        if runtime == "claude-code":
            environment["CLAUDE_CODE_EFFORT_LEVEL"] = effort
            if agent_teams:
                environment["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        return environment, None

    key_path = Path(authentication["credential_file"])
    try:
        key = key_path.read_text(encoding="utf-8").strip()
    except OSError as error:
        raise RuntimeError(f"cannot read configured credential file: {key_path}") from error
    config = profile["runtime"]
    provider = config.get("provider")
    if not model:
        raise RuntimeError("configured API runtime requires a model")

    if runtime == "claude-code":
        if provider != "deepseek":
            raise RuntimeError("Claude Code API execution requires provider=deepseek")
        environment.update(
            {
                "ANTHROPIC_AUTH_TOKEN": key,
                "ANTHROPIC_BASE_URL": config["base_url"],
                "ANTHROPIC_MODEL": model,
                "ANTHROPIC_DEFAULT_OPUS_MODEL": model,
                "ANTHROPIC_DEFAULT_SONNET_MODEL": model,
                "ANTHROPIC_DEFAULT_HAIKU_MODEL": model,
                "CLAUDE_CODE_SUBAGENT_MODEL": model,
                "CLAUDE_CODE_EFFORT_LEVEL": effort,
            }
        )
        if agent_teams:
            environment["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
    elif runtime == "codex":
        if provider != "openai":
            raise RuntimeError("Codex API execution requires provider=openai")
        environment["CODEX_API_KEY"] = key
        if config.get("base_url"):
            environment["OPENAI_BASE_URL"] = str(config["base_url"])
    elif runtime == "opencode":
        variable = {
            "anthropic": "ANTHROPIC_API_KEY",
            "deepseek": "DEEPSEEK_API_KEY",
            "openai": "OPENAI_API_KEY",
        }.get(str(provider))
        if variable is None:
            raise RuntimeError(f"unsupported OpenCode API provider: {provider}")
        environment[variable] = key
    else:
        raise RuntimeError(f"unsupported runtime: {runtime}")
    return environment, key.encode("utf-8")


def isolate_runtime_state(
    environment: dict[str, str], runtime: str, auth_mode: str
) -> tempfile.TemporaryDirectory[str] | None:
    """Isolate sessions and ambient Skills while preserving only cached login auth."""
    if runtime == "codex":
        temporary = tempfile.TemporaryDirectory(prefix="codex-agent-home-")
        source_home = Path(
            environment.get("CODEX_HOME", str(Path.home() / ".codex"))
        ).expanduser()
        if auth_mode == "subscription":
            source = source_home / "auth.json"
            if not source.is_file():
                temporary.cleanup()
                raise RuntimeError("Codex subscription auth.json is unavailable")
            destination = Path(temporary.name) / "auth.json"
            shutil.copy2(source, destination)
            destination.chmod(0o600)
        environment["CODEX_HOME"] = temporary.name
        return temporary

    if runtime == "opencode":
        temporary = tempfile.TemporaryDirectory(prefix="opencode-agent-state-")
        root = Path(temporary.name)
        data_home = root / "data"
        config_home = root / "config"
        if auth_mode == "subscription":
            source_data = Path(
                environment.get(
                    "XDG_DATA_HOME", str(Path.home() / ".local" / "share")
                )
            ).expanduser()
            source = source_data / "opencode" / "auth.json"
            if source.is_file():
                destination = data_home / "opencode" / "auth.json"
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
                destination.chmod(0o600)
        environment["XDG_DATA_HOME"] = str(data_home)
        environment["XDG_CONFIG_HOME"] = str(config_home)
        environment["OPENCODE_DISABLE_EXTERNAL_SKILLS"] = "1"
        environment["OPENCODE_DISABLE_CLAUDE_CODE_SKILLS"] = "1"
        return temporary
    return None


def codex_sandbox(allowed_tools: list[str], permission_mode: str) -> str:
    if permission_mode == "plan":
        return "read-only"
    if not allowed_tools:
        return "workspace-write"
    writable = {"Bash", "Edit", "Write"}
    return "workspace-write" if writable.intersection(allowed_tools) else "read-only"


def opencode_permissions(
    allowed_tools: list[str],
    disallowed_tools: list[str],
    permission_mode: str,
    *,
    skills: list[str],
) -> dict[str, Any]:
    permission: dict[str, Any]
    if allowed_tools:
        permission = {"*": "deny"}
        for tool in allowed_tools:
            permission[TOOL_PERMISSIONS.get(tool, tool)] = "allow"
    else:
        permission = {"*": "allow"}
    permission["external_directory"] = "deny"
    permission["question"] = "deny"
    permission["skill"] = {"*": "deny", **{name: "allow" for name in skills}}
    if permission_mode == "plan":
        permission["edit"] = "deny"
        permission["bash"] = "deny"
    for tool in disallowed_tools:
        permission[TOOL_PERMISSIONS.get(tool, tool)] = "deny"
    return permission


def install_opencode_config(
    environment: dict[str, str],
    *,
    permissions: dict[str, Any],
    agents: dict[str, Any] | None = None,
    provider_runtime: dict[str, Any] | None = None,
) -> None:
    config: dict[str, Any] = {
        "$schema": "https://opencode.ai/config.json",
        "share": "disabled",
        "autoupdate": False,
        "permission": permissions,
    }
    if agents:
        config["agent"] = agents
    if provider_runtime and provider_runtime.get("provider"):
        provider = str(provider_runtime["provider"])
        base_url = provider_runtime.get("base_url")
        if base_url:
            config["provider"] = {
                provider: {"options": {"baseURL": str(base_url)}}
            }
    environment["OPENCODE_CONFIG_CONTENT"] = json.dumps(
        config, separators=(",", ":"), ensure_ascii=False
    )


def runtime_metrics(runtime: str, stdout: str) -> tuple[dict[str, Any], bool]:
    if runtime == "claude-code":
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

    events: list[dict[str, Any]] = []
    parse_errors = 0
    for line in stdout.splitlines():
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            parse_errors += 1
            continue
        if isinstance(value, dict):
            events.append(value)
    if not events:
        return {"json_parse_error": True, "non_json_lines": parse_errors}, False

    if runtime == "codex":
        types = [str(event.get("type", "")) for event in events]
        completed = [event for event in events if event.get("type") == "turn.completed"]
        failed = any(
            event.get("type") in ("turn.failed", "error")
            for event in events
        )
        usage = completed[-1].get("usage") if completed else None
        metrics = {
            "event_count": len(events),
            "num_turns": types.count("turn.started"),
            "terminal_event": types[-1],
            "usage": usage,
            "non_json_lines": parse_errors,
        }
        return metrics, bool(completed) and not failed

    types = [str(event.get("type", "")) for event in events]
    failed = any(value in ("error", "session.error") for value in types)
    metrics = {
        "event_count": len(events),
        "num_steps": sum("step" in value and "start" in value for value in types),
        "terminal_event": types[-1],
        "non_json_lines": parse_errors,
    }
    return metrics, not failed
