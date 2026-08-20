#!/usr/bin/env python3
"""Snapshot a fixture and report file changes or credential leakage."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def inventory(root: Path) -> dict[str, str]:
    files: dict[str, str] = {}
    for current, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d != ".git")
        base = Path(current)
        for name in sorted(names):
            path = base / name
            relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                files[relative] = "symlink:" + os.readlink(path)
            elif path.is_file():
                files[relative] = "sha256:" + digest(path)
    return files


def load_secret(path: Path) -> bytes:
    secret = path.expanduser().read_bytes().strip()
    if not secret:
        raise SystemExit(f"secret file is empty: {path}")
    return secret


def leakage(root: Path, secrets: list[Path]) -> list[str]:
    values = [(path, load_secret(path)) for path in secrets]
    hits: set[str] = set()
    for relative in inventory(root):
        path = root / relative
        if not path.is_file() or path.is_symlink():
            continue
        try:
            data = path.read_bytes()
        except OSError:
            continue
        if any(secret in data for _, secret in values):
            hits.add(relative)
    return sorted(hits)


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    snapshot = subparsers.add_parser("snapshot")
    snapshot.add_argument("root", type=Path)
    snapshot.add_argument("--output", required=True, type=Path)

    verify = subparsers.add_parser("verify")
    verify.add_argument("root", type=Path)
    verify.add_argument("--snapshot", required=True, type=Path)
    verify.add_argument("--secret-file", action="append", default=[], type=Path)
    verify.add_argument("--fail-on-leak", action="store_true")

    args = parser.parse_args()
    root = args.root.expanduser().resolve()
    if not root.is_dir():
        raise SystemExit(f"fixture root is not a directory: {root}")

    if args.command == "snapshot":
        output = args.output.expanduser().resolve()
        if output == root or root in output.parents:
            raise SystemExit("store the snapshot outside the fixture root")
        output.parent.mkdir(parents=True, exist_ok=True)
        payload = {"schema": "skill-test-workspace-v1", "files": inventory(root)}
        output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        print(json.dumps({"files": len(payload["files"]), "snapshot": str(output)}))
        return

    baseline = json.loads(args.snapshot.expanduser().read_text())
    if baseline.get("schema") != "skill-test-workspace-v1":
        raise SystemExit("unsupported snapshot schema")
    before = baseline["files"]
    after = inventory(root)
    before_names = set(before)
    after_names = set(after)
    result = {
        "added": sorted(after_names - before_names),
        "changed": sorted(
            name for name in before_names & after_names if before[name] != after[name]
        ),
        "deleted": sorted(before_names - after_names),
        "credential_occurrences": leakage(root, args.secret_file),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.fail_on_leak and result["credential_occurrences"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
