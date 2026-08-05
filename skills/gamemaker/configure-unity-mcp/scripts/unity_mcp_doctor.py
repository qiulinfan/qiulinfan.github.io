#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# ///
"""Cross-platform, read-only diagnostics for a Unity MCP project."""

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import socket
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import tomllib


@dataclass
class Check:
    name: str
    status: str
    detail: str


def add(checks: list[Check], name: str, status: str, detail: str) -> None:
    checks.append(Check(name=name, status=status, detail=detail))


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise TypeError(f"{path} must contain a JSON object")
    return value


def read_toml(path: Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        value = tomllib.load(handle)
    if not isinstance(value, dict):
        raise TypeError(f"{path} must contain a TOML table")
    return value


def mcp_entry(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    data = read_toml(path)
    servers = data.get("mcp_servers", {})
    if not isinstance(servers, dict):
        return None
    entry = servers.get("unityMCP")
    return entry if isinstance(entry, dict) else None


def tail_text(path: Path, max_bytes: int = 8 * 1024 * 1024) -> str:
    size = path.stat().st_size
    with path.open("rb") as handle:
        if size > max_bytes:
            handle.seek(size - max_bytes)
        return handle.read().decode("utf-8", errors="replace")


def find_unity_editors() -> list[str]:
    home = Path.home()
    system = platform.system()
    patterns: list[Path]
    if system == "Darwin":
        patterns = [Path("/Applications/Unity/Hub/Editor")]
        suffix = "Unity.app/Contents/MacOS/Unity"
    elif system == "Windows":
        roots = [
            Path(os.environ.get("ProgramFiles", r"C:\Program Files"))
            / "Unity/Hub/Editor",
            Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"))
            / "Unity/Hub/Editor",
        ]
        patterns = roots
        suffix = "Editor/Unity.exe"
    else:
        patterns = [
            home / "Unity/Hub/Editor",
            Path("/opt/unityhub/Editor"),
            Path("/opt/Unity/Hub/Editor"),
        ]
        suffix = "Editor/Unity"

    results: list[str] = []
    for root in patterns:
        if not root.is_dir():
            continue
        for version_dir in root.iterdir():
            candidate = version_dir / suffix
            if candidate.is_file():
                results.append(str(candidate))
    return sorted(results)


def port_owner(host: str, port: int) -> str | None:
    system = platform.system()
    commands: list[list[str]]
    if system == "Windows":
        commands = [["netstat", "-ano"]]
    else:
        commands = [
            ["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"],
            ["ss", "-ltnp"],
        ]

    for command in commands:
        if shutil.which(command[0]) is None:
            continue
        try:
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        lines = [
            line.strip()
            for line in completed.stdout.splitlines()
            if str(port) in line and (host in line or f":{port}" in line)
        ]
        if lines:
            return " | ".join(lines[:3])
    return None


def tcp_listening(host: str, port: int, timeout: float = 1.0) -> tuple[bool, str]:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True, f"{host}:{port} accepted a TCP connection"
    except OSError as exc:
        return False, f"{host}:{port} is not reachable: {exc}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default=".", help="Unity project root")
    parser.add_argument(
        "--url",
        help="Override MCP URL; otherwise read project/global Codex config",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    args = parser.parse_args()

    project = Path(args.project).expanduser().resolve()
    checks: list[Check] = []
    recommendations: list[str] = []

    add(
        checks,
        "host",
        "PASS",
        f"{platform.system()} {platform.release()} ({platform.machine()})",
    )

    required_dirs = [
        project / "Assets",
        project / "Packages",
        project / "ProjectSettings",
    ]
    missing_dirs = [str(path.name) for path in required_dirs if not path.is_dir()]
    if missing_dirs:
        add(
            checks,
            "unity_project",
            "FAIL",
            f"{project} is missing: {', '.join(missing_dirs)}",
        )
    else:
        add(checks, "unity_project", "PASS", str(project))

    version_path = project / "ProjectSettings/ProjectVersion.txt"
    if version_path.is_file():
        text = version_path.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"m_EditorVersion:\s*(\S+)", text)
        version = match.group(1) if match else text.strip().splitlines()[0]
        add(checks, "unity_version", "PASS", version)
    else:
        add(checks, "unity_version", "WARN", "ProjectVersion.txt not found")

    manifest_path = project / "Packages/manifest.json"
    manifest: dict[str, Any] = {}
    if manifest_path.is_file():
        try:
            manifest = read_json(manifest_path)
            add(checks, "manifest", "PASS", str(manifest_path))
        except (OSError, TypeError, ValueError, json.JSONDecodeError) as exc:
            add(checks, "manifest", "FAIL", str(exc))
    else:
        add(checks, "manifest", "FAIL", "Packages/manifest.json not found")

    dependencies = manifest.get("dependencies", {})
    package_spec = (
        dependencies.get("com.coplaydev.unity-mcp")
        if isinstance(dependencies, dict)
        else None
    )
    if isinstance(package_spec, str):
        status = (
            "PASS"
            if "github.com/CoplayDev/unity-mcp" in package_spec and "#" in package_spec
            else "WARN"
        )
        add(checks, "unity_mcp_package", status, package_spec)
        if status == "WARN":
            recommendations.append(
                "Pin MCP for Unity to a verified official release tag."
            )
    else:
        add(checks, "unity_mcp_package", "WARN", "Package is not installed")
        recommendations.append("Add com.coplaydev.unity-mcp to Packages/manifest.json.")

    lock_path = project / "Packages/packages-lock.json"
    if lock_path.is_file():
        try:
            lock = read_json(lock_path)
            locked = lock.get("dependencies", {}).get("com.coplaydev.unity-mcp")
            if isinstance(locked, dict):
                add(
                    checks,
                    "package_lock",
                    "PASS",
                    str(locked.get("version", "resolved")),
                )
            else:
                add(
                    checks,
                    "package_lock",
                    "WARN",
                    "MCP package is absent from packages-lock.json",
                )
        except (OSError, TypeError, ValueError, json.JSONDecodeError) as exc:
            add(checks, "package_lock", "FAIL", str(exc))
    else:
        add(checks, "package_lock", "WARN", "packages-lock.json not found")

    project_config = project / ".codex/config.toml"
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")).expanduser()
    global_config = codex_home / "config.toml"
    project_entry: dict[str, Any] | None = None
    global_entry: dict[str, Any] | None = None
    try:
        project_entry = mcp_entry(project_config)
        global_entry = mcp_entry(global_config)
    except (OSError, TypeError, ValueError, tomllib.TOMLDecodeError) as exc:
        add(checks, "codex_config", "FAIL", str(exc))

    if project_entry:
        add(
            checks,
            "project_mcp_config",
            "PASS",
            f"{project_config}: {project_entry.get('url')}",
        )
    else:
        add(
            checks,
            "project_mcp_config",
            "WARN",
            f"No unityMCP entry in {project_config}",
        )
        recommendations.append("Create a project-scoped .codex/config.toml.")

    if global_entry:
        status = "WARN" if project_entry else "PASS"
        add(
            checks,
            "global_mcp_config",
            status,
            f"{global_config}: {global_entry.get('url')}",
        )
        if project_entry:
            recommendations.append(
                "Review the duplicate global unityMCP entry and keep only the intended scope."
            )

    configured_url = args.url
    if not configured_url and project_entry:
        configured_url = project_entry.get("url")
    if not configured_url and global_entry:
        configured_url = global_entry.get("url")
    if not isinstance(configured_url, str):
        configured_url = "http://127.0.0.1:8080/mcp"

    parsed = urlparse(configured_url)
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    if parsed.path.rstrip("/") != "/mcp":
        add(
            checks,
            "mcp_url",
            "WARN",
            f"{configured_url} does not use the expected /mcp path",
        )
    else:
        add(checks, "mcp_url", "PASS", configured_url)

    listening, detail = tcp_listening(host, port)
    add(checks, "mcp_port", "PASS" if listening else "WARN", detail)
    owner = port_owner(host, port)
    if owner:
        add(checks, "port_owner", "PASS", owner)
    elif listening:
        add(checks, "port_owner", "WARN", "Listener found, owner not resolved")
    else:
        recommendations.append(
            "Start the local HTTP server from the MCP for Unity window."
        )

    for executable in ("uv", "uvx", "codex", "git"):
        found = shutil.which(executable)
        add(
            checks,
            executable,
            "PASS" if found else "WARN",
            found or f"{executable} is not on PATH",
        )
        if not found and executable in {"uv", "uvx"}:
            recommendations.append(
                "Install uv/uvx from the official Astral instructions."
            )

    editors = find_unity_editors()
    add(
        checks,
        "unity_editors",
        "PASS" if editors else "WARN",
        ", ".join(editors[-5:]) if editors else "No common Unity Editor path found",
    )

    log_dir = project / "Library/MCPForUnity/Logs"
    launch_logs = (
        sorted(
            log_dir.glob("server-launch-*.log"), key=lambda path: path.stat().st_mtime
        )
        if log_dir.is_dir()
        else []
    )
    if launch_logs:
        latest = launch_logs[-1]
        text = tail_text(latest, 2 * 1024 * 1024)
        evidence = []
        for pattern, label in (
            (r"Uvicorn running on ([^\s]+)", "server"),
            (r"Plugin registered: ([^\r\n]+)", "plugin"),
            (r"Registered (\d+) tools", "unity_tools"),
        ):
            matches = re.findall(pattern, text)
            if matches:
                evidence.append(f"{label}={matches[-1]}")
        add(
            checks,
            "launch_log",
            "PASS" if evidence else "WARN",
            f"{latest}: " + (", ".join(evidence) or "no registration evidence"),
        )
    else:
        add(checks, "launch_log", "WARN", "No MCP launch log found")

    editor_log = project / "Logs/Editor.log"
    if editor_log.is_file():
        text = tail_text(editor_log)
        errors = re.findall(r"^.*error CS\d+.*$", text, flags=re.MULTILINE)
        add(
            checks,
            "compiler_errors",
            "FAIL" if errors else "PASS",
            f"{len(errors)} C# compiler error line(s) in recent project Editor.log",
        )
        if errors:
            recommendations.append(
                "Resolve C# compiler errors before testing Play Mode or Inspector mutation."
            )
    else:
        add(
            checks,
            "compiler_errors",
            "WARN",
            "Project-local Logs/Editor.log not found; inspect the Unity Editor log",
        )

    counts = {
        status: sum(check.status == status for check in checks)
        for status in ("PASS", "WARN", "FAIL")
    }
    payload = {
        "project": str(project),
        "url": configured_url,
        "summary": counts,
        "checks": [asdict(check) for check in checks],
        "recommendations": list(dict.fromkeys(recommendations)),
    }

    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        for check in checks:
            print(f"[{check.status:4}] {check.name}: {check.detail}")
        print(
            f"\nSummary: {counts['PASS']} pass, {counts['WARN']} warn, "
            f"{counts['FAIL']} fail"
        )
        if recommendations:
            print("\nRecommended next actions:")
            for index, recommendation in enumerate(
                dict.fromkeys(recommendations), start=1
            ):
                print(f"{index}. {recommendation}")

    if counts["FAIL"]:
        return 2
    if counts["WARN"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
