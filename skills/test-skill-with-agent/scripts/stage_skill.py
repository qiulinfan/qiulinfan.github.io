#!/usr/bin/env python3
"""Stage an Agent Skill into an isolated project as physical files."""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path


NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def skill_name(skill_md: Path) -> str:
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise SystemExit("SKILL.md has no YAML frontmatter")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise SystemExit("SKILL.md frontmatter is not closed")
    match = re.search(r"(?m)^name:\s*([^\s#]+)\s*$", text[4:end])
    if not match:
        raise SystemExit("SKILL.md frontmatter has no name")
    name = match.group(1).strip("'\"")
    if not NAME_RE.fullmatch(name):
        raise SystemExit(f"invalid skill name: {name}")
    return name


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skill", required=True, type=Path)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--runtime", required=True, choices=("claude-code",))
    args = parser.parse_args()

    source = args.skill.expanduser().resolve()
    project = args.project.expanduser().resolve()
    manifest = source / "SKILL.md"
    if not source.is_dir() or not manifest.is_file():
        raise SystemExit(f"not a skill directory: {source}")

    name = skill_name(manifest)
    if source.name != name:
        raise SystemExit(
            f"skill folder {source.name!r} does not match frontmatter name {name!r}"
        )

    if args.runtime == "claude-code":
        destination = project / ".claude" / "skills" / name
    else:  # pragma: no cover - argparse currently prevents this
        raise SystemExit(f"unsupported runtime: {args.runtime}")

    if destination.exists() or destination.is_symlink():
        raise SystemExit(f"destination already exists: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination, symlinks=False)

    staged_manifest = destination / "SKILL.md"
    if staged_manifest.is_symlink() or not staged_manifest.is_file():
        raise SystemExit("staged SKILL.md is not a regular file")
    print(destination)


if __name__ == "__main__":
    main()
