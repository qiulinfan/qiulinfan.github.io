#!/usr/bin/env python3
"""Discover external agents and manage the shared machine-local runtime profile."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCHEMA = "qlblog-agent-runtime-profile-v1"
CACHE_NAME = ".agent-runtime-profile.local.json"
AGENT_COMMANDS = (
    ("claude-code", "claude", True),
    ("opencode", "opencode", False),
    ("codex", "codex", False),
    ("gemini-cli", "gemini", False),
    ("aider", "aider", False),
    ("cursor-agent", "cursor-agent", False),
    ("github-copilot-cli", "copilot", False),
)
DEEPSEEK_BASE_URL = "https://api.deepseek.com/anthropic"
DEEPSEEK_MODEL = "deepseek-v4-flash"


class ProfileError(RuntimeError):
    """Raised when the local runtime profile is absent or incomplete."""


def default_profile_path() -> Path:
    return Path(__file__).resolve().parents[2] / CACHE_NAME


def agent_version(command: str) -> str | None:
    try:
        result = subprocess.run(
            [command, "--version"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    first = (result.stdout or result.stderr).strip().splitlines()
    return first[0][:200] if first else None


def detect_agents() -> list[dict[str, Any]]:
    detected: list[dict[str, Any]] = []
    for agent_id, executable, supported in AGENT_COMMANDS:
        path = shutil.which(executable)
        if path is None:
            continue
        detected.append(
            {
                "id": agent_id,
                "command": executable,
                "path": str(Path(path).resolve()),
                "version": agent_version(path),
                "supported": supported,
            }
        )
    return detected


def read_profile(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    if not path.is_file():
        return None, None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return None, f"cannot read runtime profile: {error}"
    if not isinstance(value, dict):
        return None, "runtime profile must be a JSON object"
    if value.get("schema") != SCHEMA:
        return None, f"runtime profile schema must be {SCHEMA}"
    return value, None


def route_problem(route: Any, detected_ids: set[str]) -> str | None:
    if not isinstance(route, dict):
        return "route must be a JSON object"
    agent = route.get("agent")
    when = route.get("when")
    if not isinstance(agent, str) or not agent:
        return "route agent must be a non-empty string"
    if agent not in detected_ids:
        return f"route agent is not currently installed: {agent}"
    if not isinstance(when, dict):
        return "route when must be a JSON object"
    if not any(isinstance(when.get(key), str) and when.get(key) for key in ("workflow", "skill")):
        return "route when must define workflow, skill, or both"
    if any(key not in ("workflow", "skill") for key in when):
        return "route when contains an unsupported selector"
    return None


def resolve_agent_id(
    profile: dict[str, Any], *, workflow: str | None = None, skill: str | None = None
) -> str:
    selected = str(profile["selected_agent"])
    best_score = -1
    for route in profile.get("routes", []):
        if not isinstance(route, dict) or not isinstance(route.get("when"), dict):
            continue
        when = route["when"]
        selectors = {"workflow": workflow, "skill": skill}
        if not all(selectors.get(key) == value for key, value in when.items()):
            continue
        score = len(when)
        if score >= best_score and isinstance(route.get("agent"), str):
            selected = route["agent"]
            best_score = score
    return selected


def credential_problem(path_value: Any) -> str | None:
    if not isinstance(path_value, str) or not path_value.strip():
        return "credential_file is missing"
    path = Path(path_value).expanduser()
    if not path.is_absolute():
        return "credential_file must be an absolute path"
    if not path.is_file():
        return f"credential file does not exist: {path}"
    if os.name != "nt" and stat.S_IMODE(path.stat().st_mode) & 0o077:
        return f"credential file must have mode 0600: {path}"
    try:
        value = path.read_text(encoding="utf-8").strip()
    except OSError as error:
        return f"cannot read credential file: {error}"
    if not value or "\n" in value or "\r" in value:
        return "credential file must contain exactly one non-empty line"
    return None


def inspect_profile(path: Path) -> dict[str, Any]:
    detected = detect_agents()
    detected_by_id = {item["id"]: item for item in detected}
    profile, cache_error = read_profile(path)
    questions: list[dict[str, str]] = []
    route_warnings: list[str] = []
    selected: str | None = None

    if profile:
        raw_selected = profile.get("selected_agent")
        if isinstance(raw_selected, str):
            selected = raw_selected
    if selected not in detected_by_id:
        selected = detected[0]["id"] if len(detected) == 1 else None
        if len(detected) != 1:
            choices = ", ".join(
                f"{item['id']} "
                f"({'supported' if item['supported'] else 'detected; runner not implemented'})"
                for item in detected
            ) or "none"
            questions.append(
                {
                    "id": "selected_agent",
                    "question": (
                        "Which installed agent should these skills use? "
                        f"Choices: {choices}."
                    ),
                }
            )

    authentication = profile.get("authentication", {}) if profile else {}
    auth_mode = authentication.get("mode") if isinstance(authentication, dict) else None
    if auth_mode not in ("subscription", "api"):
        questions.append(
            {
                "id": "auth_mode",
                "question": (
                    "Does the selected agent use a subscription login or an "
                    "API credential?"
                ),
            }
        )
    elif auth_mode == "api":
        problem = credential_problem(authentication.get("credential_file"))
        if problem:
            questions.append(
                {
                    "id": "credential_file",
                    "question": (
                        "What is the absolute path of the one-line API credential file "
                        f"(mode 0600)? Current problem: {problem}"
                    ),
                }
            )
        runtime = profile.get("runtime", {}) if profile else {}
        if not isinstance(runtime, dict) or not all(
            isinstance(runtime.get(key), str) and runtime.get(key)
            for key in ("provider", "model", "base_url")
        ):
            questions.append(
                {
                    "id": "api_runtime",
                    "question": (
                        "Which API provider, endpoint, and model should the "
                        "selected agent use?"
                    ),
                }
            )

    if not detected:
        questions.insert(
            0,
            {
                "id": "installed_agent",
                "question": (
                    "No supported or known external agent executable was detected. "
                    "Which agent should be installed or configured?"
                ),
            },
        )
    elif not any(item["supported"] for item in detected):
        questions.insert(
            0,
            {
                "id": "supported_agent",
                "question": (
                    "External agents were detected, but this Skill currently supports "
                    "only Claude Code. Which supported runtime should be configured?"
                ),
            },
        )

    cached_agents = profile.get("installed_agents") if profile else None
    if profile and (not isinstance(cached_agents, list) or not cached_agents):
        questions.append(
            {
                "id": "refresh_profile",
                "question": (
                    "May the profile be refreshed with the currently detected "
                    "agent inventory?"
                ),
            }
        )

    routes = profile.get("routes", []) if profile else []
    if not isinstance(routes, list):
        route_warnings.append("routes must be a list; base_agent fallback will be used")
    else:
        detected_ids = set(detected_by_id)
        for index, route in enumerate(routes):
            problem = route_problem(route, detected_ids)
            if problem:
                route_warnings.append(f"routes[{index}]: {problem}")

    return {
        "schema": SCHEMA,
        "status": (
            "ready"
            if profile
            and not cache_error
            and not questions
            and detected_by_id.get(selected, {}).get("supported")
            else "incompatible"
            if profile and not questions and selected in detected_by_id
            else "needs_user_input"
        ),
        "profile_path": str(path),
        "cache_exists": path.is_file(),
        "cache_error": cache_error,
        "detected_agents": detected,
        "selected_agent": selected,
        "base_agent": selected,
        "auth_mode": auth_mode,
        "routes": routes if isinstance(routes, list) else [],
        "route_warnings": route_warnings,
        "questions": questions,
    }


def write_profile_value(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, prefix=f".{path.name}.", delete=False
    ) as stream:
        temporary = Path(stream.name)
        json.dump(value, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    temporary.chmod(0o600)
    os.replace(temporary, path)
    if os.name != "nt":
        path.chmod(0o600)


def write_profile(
    path: Path,
    selected_agent: str | None,
    auth_mode: str,
    credential_file: Path | None,
    provider: str,
    model: str,
    base_url: str,
) -> dict[str, Any]:
    prior, _ = read_profile(path)
    detected = detect_agents()
    if selected_agent is None and len(detected) == 1:
        selected_agent = detected[0]["id"]
    selected = next((item for item in detected if item["id"] == selected_agent), None)
    if selected is None:
        choices = ", ".join(item["id"] for item in detected) or "none"
        raise ProfileError(f"selected agent is not installed; detected: {choices}")

    authentication: dict[str, Any] = {"mode": auth_mode, "credential_file": None}
    runtime: dict[str, Any] = {"provider": None, "model": None, "base_url": None}
    if auth_mode == "api":
        if credential_file is None:
            raise ProfileError("--credential-file is required for API authentication")
        resolved = credential_file.expanduser().resolve()
        problem = credential_problem(str(resolved))
        if problem:
            raise ProfileError(problem)
        if selected_agent == "claude-code" and provider != "deepseek":
            raise ProfileError("the current Claude Code API runner supports provider=deepseek")
        authentication["credential_file"] = str(resolved)
        runtime = {"provider": provider, "model": model, "base_url": base_url}

    value = {
        "schema": SCHEMA,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "installed_agents": detected,
        "selected_agent": selected_agent,
        "authentication": authentication,
        "runtime": runtime,
        "routes": prior.get("routes", []) if prior else [],
    }
    write_profile_value(path, value)
    return value


def update_route(
    path: Path,
    *,
    agent: str | None,
    workflow: str | None,
    skill: str | None,
    remove: bool,
) -> dict[str, Any]:
    profile = require_ready_profile(path)
    when = {key: value for key, value in (("workflow", workflow), ("skill", skill)) if value}
    if not when:
        raise ProfileError("a route requires --workflow, --skill, or both")
    routes = profile.get("routes", [])
    if not isinstance(routes, list):
        routes = []
    routes = [
        route
        for route in routes
        if not (isinstance(route, dict) and route.get("when") == when)
    ]
    if not remove:
        detected_ids = {item["id"] for item in detect_agents()}
        if not agent:
            raise ProfileError("--agent is required unless --remove is used")
        if agent not in detected_ids:
            raise ProfileError(f"route agent is not installed: {agent}")
        routes.append({"when": when, "agent": agent})
    profile["routes"] = routes
    profile["updated_at"] = datetime.now(timezone.utc).isoformat()
    write_profile_value(path, profile)
    return profile


def require_ready_profile(path: Path) -> dict[str, Any]:
    status = inspect_profile(path)
    if status["status"] != "ready":
        raise ProfileError(json.dumps(status, indent=2, ensure_ascii=False))
    profile, error = read_profile(path)
    if profile is None:
        raise ProfileError(error or "runtime profile is unavailable")
    return profile


def selected_agent_record(
    profile: dict[str, Any], *, workflow: str | None = None, skill: str | None = None
) -> dict[str, Any]:
    selected = resolve_agent_id(profile, workflow=workflow, skill=skill)
    record = next((item for item in detect_agents() if item["id"] == selected), None)
    if record is None:
        raise ProfileError(f"selected agent is no longer available: {selected}")
    if not record["supported"]:
        raise ProfileError(
            f"cached route selects detected agent {selected}, but its runner is not implemented"
        )
    return record


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", type=Path, default=default_profile_path())
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("status")
    configure = subparsers.add_parser("configure")
    configure.add_argument("--selected-agent")
    configure.add_argument("--auth-mode", required=True, choices=("subscription", "api"))
    configure.add_argument("--credential-file", type=Path)
    configure.add_argument("--provider", default="deepseek")
    configure.add_argument("--model", default=DEEPSEEK_MODEL)
    configure.add_argument("--base-url", default=DEEPSEEK_BASE_URL)
    route = subparsers.add_parser("route")
    route.add_argument("--agent")
    route.add_argument("--workflow")
    route.add_argument("--skill")
    route.add_argument("--remove", action="store_true")
    args = parser.parse_args()
    path = args.profile.expanduser().resolve()

    if args.command == "status":
        status = inspect_profile(path)
        print(json.dumps(status, indent=2, ensure_ascii=False))
        raise SystemExit(0 if status["status"] == "ready" else 2)

    try:
        if args.command == "route":
            value = update_route(
                path,
                agent=args.agent,
                workflow=args.workflow,
                skill=args.skill,
                remove=args.remove,
            )
        else:
            value = write_profile(
                path,
                args.selected_agent,
                args.auth_mode,
                args.credential_file,
                args.provider,
                args.model,
                args.base_url,
            )
    except ProfileError as error:
        raise SystemExit(f"runtime profile: {error}") from error
    print(
        json.dumps(
            {
                "status": "ready",
                "profile_path": str(path),
                "selected_agent": value["selected_agent"],
                "auth_mode": value["authentication"]["mode"],
                "routes": value.get("routes", []),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
