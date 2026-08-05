#!/usr/bin/env python3
"""Stage one or more Agent Skills into a supported external-agent project."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
from pathlib import Path

from runtime_profile import (
    ProfileError,
    default_profile_path,
    require_ready_profile,
    resolve_agent_id,
    selected_agent_record,
)


NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


def skill_name(skill_md: Path) -> str:
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError(f"SKILL.md has no YAML frontmatter: {skill_md}")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise ValueError(f"SKILL.md frontmatter is not closed: {skill_md}")
    match = re.search(r"(?m)^name:\s*([^\s#]+)\s*$", text[4:end])
    if not match:
        raise ValueError(f"SKILL.md frontmatter has no name: {skill_md}")
    name = match.group(1).strip("'\"")
    if not NAME_RE.fullmatch(name):
        raise ValueError(f"invalid skill name {name!r}: {skill_md}")
    return name


def codex_home() -> Path:
    configured = os.environ.get("CODEX_HOME")
    return Path(configured).expanduser() if configured else Path.home() / ".codex"


def default_roots() -> list[Path]:
    home = codex_home()
    return [
        Path.cwd() / ".codex" / "skills",
        home / "skills",
        home / "system-skills",
        home / "plugins" / "cache",
    ]


def manifests_under(root: Path) -> list[Path]:
    root = root.expanduser()
    if not root.exists():
        return []
    if root.is_file():
        return [root.resolve()] if root.name == "SKILL.md" else []
    direct = root / "SKILL.md"
    if direct.is_file():
        return [direct.resolve()]
    return sorted(path.resolve() for path in root.rglob("SKILL.md") if path.is_file())


def resolve_named_skill(name: str, roots: list[Path]) -> Path:
    for root in roots:
        matches: dict[Path, None] = {}
        for manifest in manifests_under(root):
            try:
                declared_name = skill_name(manifest)
            except (OSError, UnicodeError, ValueError):
                continue
            if declared_name == name or manifest.parent.name == name:
                matches[manifest.parent] = None
        candidates = list(matches)
        if len(candidates) > 1:
            options = "\n".join(f"  - {path}" for path in candidates)
            raise SystemExit(
                f"Codex skill {name!r} is ambiguous under {root}; "
                f"pass an explicit path:\n{options}"
            )
        if candidates:
            return candidates[0]
    searched = ", ".join(str(root.expanduser()) for root in roots)
    raise SystemExit(f"Codex skill {name!r} was not found under: {searched}")


def resolve_skill(spec: str, roots: list[Path]) -> Path:
    candidate = Path(spec).expanduser()
    looks_like_path = candidate.exists() or candidate.is_absolute() or "/" in spec
    if looks_like_path:
        source = candidate.resolve()
        manifest = source / "SKILL.md"
        if not source.is_dir() or not manifest.is_file():
            raise SystemExit(f"not a skill directory: {source}")
        return source
    if not NAME_RE.fullmatch(spec):
        raise SystemExit(f"invalid skill name or path: {spec!r}")
    return resolve_named_skill(spec, roots)


def destination_for(project: Path, runtime: str, name: str) -> Path:
    roots = {
        "claude-code": project / ".claude" / "skills",
        "codex": project / ".agents" / "skills",
        "opencode": project / ".opencode" / "skills",
    }
    try:
        return roots[runtime] / name
    except KeyError as error:
        raise SystemExit(f"unsupported runtime: {runtime}") from error


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--skill",
        required=True,
        action="append",
        help="Codex skill name or explicit skill directory; repeat for multiple skills",
    )
    parser.add_argument(
        "--skill-root",
        action="append",
        default=[],
        type=Path,
        help="additional skill search root, checked before default Codex roots",
    )
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--runtime-profile", type=Path, default=default_profile_path())
    parser.add_argument("--workflow", default="run-workflow-with-agents")
    parser.add_argument("--runtime", choices=("claude-code", "codex", "opencode"))
    args = parser.parse_args()

    try:
        profile = require_ready_profile(args.runtime_profile.expanduser().resolve())
    except ProfileError as error:
        raise SystemExit(f"runtime profile gate stopped before staging:\n{error}") from error

    project = args.project.expanduser().resolve()
    project.mkdir(parents=True, exist_ok=True)
    roots = [*args.skill_root, *default_roots()]
    sources: dict[Path, str] = {}
    for spec in args.skill:
        source = resolve_skill(spec, roots)
        manifest = source / "SKILL.md"
        try:
            name = skill_name(manifest)
        except (OSError, UnicodeError, ValueError) as error:
            raise SystemExit(str(error)) from error
        sources[source] = name

    routed_pairs = [
        (name, resolve_agent_id(profile, workflow=args.workflow, skill=name))
        for name in sources.values()
    ]
    routed_agents = {agent_id for _, agent_id in routed_pairs}
    if len(routed_agents) != 1:
        details = ", ".join(f"{skill} -> {agent}" for skill, agent in routed_pairs)
        raise SystemExit(
            "cached routes require heterogeneous staging runtimes, which one project "
            f"cannot represent: {details}"
        )
    routed = next(iter(routed_agents))
    route_skill = routed_pairs[0][0]
    try:
        selected_agent_record(profile, workflow=args.workflow, skill=route_skill)
    except ProfileError as error:
        raise SystemExit(f"cached agent route is not runnable:\n{error}") from error
    runtime = args.runtime or routed
    if runtime != routed:
        raise SystemExit(
            f"requested runtime {runtime!r} differs from cached route {routed!r}"
        )

    staged: list[dict[str, str]] = []
    seen_names: dict[str, Path] = {}
    for source, name in sources.items():
        prior = seen_names.get(name)
        if prior and prior != source:
            raise SystemExit(f"two sources define skill {name!r}: {prior}, {source}")
        seen_names[name] = source
        destination = destination_for(project, runtime, name)
        if destination.exists() or destination.is_symlink():
            if destination.resolve() == source:
                staged.append(
                    {"name": name, "source": str(source), "destination": str(destination)}
                )
                continue
            raise SystemExit(f"destination already exists: {destination}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, destination, symlinks=False)

        staged_manifest = destination / "SKILL.md"
        if staged_manifest.is_symlink() or not staged_manifest.is_file():
            raise SystemExit(f"staged SKILL.md is not a regular file: {staged_manifest}")
        staged.append(
            {"name": name, "source": str(source), "destination": str(destination)}
        )

    print(json.dumps({"runtime": runtime, "skills": staged}, indent=2))


if __name__ == "__main__":
    main()
