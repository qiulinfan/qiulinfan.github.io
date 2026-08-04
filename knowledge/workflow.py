#!/usr/bin/env python3
"""Enforce qlblog's registered-source and changed-file curation workflow."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
ENGINE_SRC = REPO_ROOT / "vendor/kgdistiller/src"
if not (ENGINE_SRC / "kgdistiller").is_dir():
    raise SystemExit(
        "pinned kgdistiller submodule is missing; run: "
        "git submodule update --init vendor/kgdistiller"
    )
sys.path.insert(0, str(ENGINE_SRC))

from kgdistiller.cli import (  # noqa: E402
    SourceSpec,
    glob_matches_path,
    load_sources,
    matching_sources,
    relative_path,
)


POLICY_SCHEMA = "qlkg-host-workflow-v1"
SUPPORTED_SUFFIXES = {".md", ".typ", ".tex"}


class WorkflowError(RuntimeError):
    """Raised when a note bypasses registration or semantic curation."""


def safe_relative(value: str, *, field: str) -> str:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or not value.startswith("notes/"):
        raise WorkflowError(f"unsafe {field} path: {value!r}")
    return path.as_posix()


def load_policy(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schema") != POLICY_SCHEMA:
        raise WorkflowError(f"expected {POLICY_SCHEMA} workflow policy: {path}")
    ignored = []
    for raw in payload.get("ignored", []):
        if not isinstance(raw, dict) or not str(raw.get("reason", "")).strip():
            raise WorkflowError("each ignored source pattern needs a reason")
        pattern = safe_relative(str(raw.get("glob", "")), field="ignored glob")
        ignored.append({"glob": pattern, "reason": str(raw["reason"]).strip()})

    def exact_paths(key: str) -> list[str]:
        values = [safe_relative(str(item), field=key) for item in payload.get(key, [])]
        if len(values) != len(set(values)):
            raise WorkflowError(f"duplicate path in {key}")
        return sorted(values)

    return {
        "schema": POLICY_SCHEMA,
        "ignored": ignored,
        "legacy_unregistered": exact_paths("legacy_unregistered"),
        "legacy_pending_authorities": exact_paths("legacy_pending_authorities"),
    }


def git_paths(repo_root: Path, *arguments: str) -> list[str]:
    result = subprocess.run(
        ["git", *arguments],
        cwd=repo_root,
        check=True,
        capture_output=True,
    )
    return sorted(
        {
            raw.decode("utf-8")
            for raw in result.stdout.split(b"\0")
            if raw and Path(raw.decode("utf-8")).suffix.casefold() in SUPPORTED_SUFFIXES
        }
    )


def authority_candidates(repo_root: Path) -> list[str]:
    tracked = git_paths(repo_root, "ls-files", "-z", "--", "notes")
    untracked = git_paths(
        repo_root,
        "ls-files",
        "--others",
        "--exclude-standard",
        "-z",
        "--",
        "notes",
    )
    return sorted(set(tracked) | set(untracked))


def usable_base(value: str | None) -> str | None:
    candidate = (value or "").strip()
    if not candidate or set(candidate) == {"0"}:
        return None
    return candidate


def changed_authority_paths(repo_root: Path, changed_from: str | None) -> list[str]:
    changed = set(
        git_paths(repo_root, "diff", "--name-only", "--no-renames", "-z", "HEAD", "--", "notes")
    )
    changed.update(
        git_paths(
            repo_root,
            "ls-files",
            "--others",
            "--exclude-standard",
            "-z",
            "--",
            "notes",
        )
    )
    base = usable_base(changed_from)
    if base is None and not changed:
        parent = subprocess.run(
            ["git", "rev-parse", "--verify", "HEAD^"],
            cwd=repo_root,
            check=False,
            capture_output=True,
            text=True,
        )
        base = parent.stdout.strip() if parent.returncode == 0 else None
    if base is not None:
        changed.update(
            git_paths(
                repo_root,
                "diff",
                "--name-only",
                "--no-renames",
                "-z",
                base,
                "HEAD",
                "--",
                "notes",
            )
        )
    return sorted(changed)


def ignored_reason(path: str, policy: dict[str, Any]) -> str | None:
    relative = Path(path)
    for record in policy["ignored"]:
        if glob_matches_path(relative, record["glob"]):
            return str(record["reason"])
    return None


def evaluate_workflow(
    repo_root: Path,
    specs: list[SourceSpec],
    policy: dict[str, Any],
    candidates: Iterable[str],
    changed: Iterable[str],
) -> dict[str, Any]:
    candidate_set = set(candidates)
    changed_set = set(changed)
    legacy = set(policy["legacy_unregistered"])
    pending = set(policy["legacy_pending_authorities"])
    errors: list[str] = []
    registered: set[str] = set()
    ignored: set[str] = set()

    def owners_for(path: str) -> list[SourceSpec]:
        return matching_sources(specs, (repo_root / path).resolve())

    for path in sorted(candidate_set):
        owners = owners_for(path)
        if len(owners) > 1:
            errors.append(
                f"{path}: matches multiple sources ({', '.join(sorted(item.id for item in owners))})"
            )
        elif owners:
            registered.add(path)
            if path in legacy:
                errors.append(f"{path}: is registered but remains in legacy_unregistered")
        elif (reason := ignored_reason(path, policy)) is not None:
            ignored.add(path)
            if path in legacy:
                errors.append(f"{path}: is ignored ({reason}) but remains in legacy_unregistered")
        elif path not in legacy:
            errors.append(
                f"{path}: unregistered authority candidate; add exactly one source pattern "
                "or an explicit ignored-policy reason"
            )

    for path in sorted(legacy - candidate_set):
        errors.append(f"{path}: stale legacy_unregistered path")
    for path in sorted(pending):
        if path not in candidate_set:
            errors.append(f"{path}: stale legacy_pending_authorities path")
        elif len(owners_for(path)) != 1:
            errors.append(f"{path}: legacy pending authority is not uniquely registered")

    changed_legacy = sorted(changed_set & legacy)
    for path in changed_legacy:
        errors.append(
            f"{path}: changed legacy note must be registered and curated before export"
        )

    changed_unclassified = sorted(
        path
        for path in changed_set
        if Path(path).suffix.casefold() in SUPPORTED_SUFFIXES
        and path not in candidate_set
        and ignored_reason(path, policy) is None
        and not owners_for(path)
    )
    for path in changed_unclassified:
        errors.append(f"{path}: deleted or renamed note has no registry/policy classification")

    curate = sorted((registered - pending) | (registered & changed_set))
    return {
        "schema": POLICY_SCHEMA,
        "candidates": len(candidate_set),
        "registered": len(registered),
        "ignored": len(ignored),
        "legacy_unregistered": len(legacy),
        "legacy_pending": len(pending),
        "changed": sorted(changed_set),
        "curate": curate,
        "errors": sorted(set(errors)),
    }


def run_curation(repo_root: Path, authorities: list[str]) -> None:
    if not authorities:
        return
    command = [sys.executable, "knowledge/kgd.py", "curate-check"]
    for authority in authorities:
        command.extend(["--file", authority])
    result = subprocess.run(
        command,
        cwd=repo_root,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        if result.stdout:
            print(result.stdout, file=sys.stderr, end="")
        if result.stderr:
            print(result.stderr, file=sys.stderr, end="")
        raise WorkflowError("curation gate failed for registered authority files")


def check_workflow(
    repo_root: Path,
    *,
    policy_path: Path,
    registry_path: Path,
    changed_from: str | None,
    curation_runner: Callable[[Path, list[str]], None] = run_curation,
) -> dict[str, Any]:
    policy = load_policy(policy_path)
    specs = load_sources(repo_root, registry_path)
    report = evaluate_workflow(
        repo_root,
        specs,
        policy,
        authority_candidates(repo_root),
        changed_authority_paths(repo_root, changed_from),
    )
    if report["errors"]:
        raise WorkflowError("\n".join(report["errors"]))
    curation_runner(repo_root, report["curate"])
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--policy", type=Path, default=Path("knowledge/workflow-policy.json"))
    parser.add_argument("--registry", type=Path, default=Path("knowledge/sources.json"))
    parser.add_argument("--changed-from", default=os.environ.get("QLBLOG_CHANGED_FROM"))
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    policy_path = args.policy if args.policy.is_absolute() else repo_root / args.policy
    registry_path = args.registry if args.registry.is_absolute() else repo_root / args.registry
    try:
        report = check_workflow(
            repo_root,
            policy_path=policy_path,
            registry_path=registry_path,
            changed_from=args.changed_from,
        )
    except (WorkflowError, OSError, ValueError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print(f"knowledge workflow failed: {error}", file=sys.stderr)
        return 1
    print(
        "knowledge workflow: OK "
        f"(registered={report['registered']}, ignored={report['ignored']}, "
        f"legacy_unregistered={report['legacy_unregistered']}, "
        f"curated={len(report['curate'])})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
