#!/usr/bin/env python3
"""Produce a deterministic, non-extracting audit of an asset archive or directory."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path, PurePosixPath
import zipfile


EXECUTABLE_SUFFIXES = {".bat", ".cmd", ".com", ".dll", ".exe", ".js", ".msi", ".ps1", ".scr", ".vbs"}
LICENSE_NAMES = {"copying", "copyright", "license", "licence", "notice", "readme"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_unsafe(name: str) -> bool:
    normalized = name.replace("\\", "/")
    path = PurePosixPath(normalized)
    return path.is_absolute() or ".." in path.parts or bool(path.parts and ":" in path.parts[0])


def looks_like_license(name: str) -> bool:
    stem = "".join(character for character in Path(name).stem.lower() if character.isalnum())
    return any(token in stem for token in LICENSE_NAMES)


def summarize_entries(entries: list[tuple[str, int]]) -> dict[str, object]:
    suffixes = Counter((Path(name).suffix.lower() or "[no extension]") for name, _ in entries if not name.endswith("/"))
    files = [(name, size) for name, size in entries if not name.endswith("/")]
    return {
        "file_count": len(files),
        "total_uncompressed_bytes": sum(size for _, size in files),
        "extensions": dict(sorted(suffixes.items())),
        "license_candidates": sorted(name for name, _ in files if looks_like_license(name)),
        "unexpected_executables": sorted(name for name, _ in files if Path(name).suffix.lower() in EXECUTABLE_SUFFIXES),
        "unsafe_paths": sorted(name for name, _ in files if is_unsafe(name)),
        "files": [{"path": name, "size_bytes": size} for name, size in sorted(files)],
    }


def audit(path: Path) -> dict[str, object]:
    if path.is_dir():
        entries = [(item.relative_to(path).as_posix(), item.stat().st_size) for item in path.rglob("*") if item.is_file()]
        return {"path": str(path.resolve()), "kind": "directory", **summarize_entries(entries)}

    if not path.is_file():
        raise FileNotFoundError(path)

    base: dict[str, object] = {
        "path": str(path.resolve()),
        "kind": "file",
        "size_bytes": path.stat().st_size,
        "sha256": sha256(path),
    }
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as archive:
            entries = [(item.filename, item.file_size) for item in archive.infolist()]
        base["kind"] = "zip"
        base.update(summarize_entries(entries))
    return base


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="Asset archive, file, or extracted directory")
    parser.add_argument("--output", type=Path, help="Optional JSON output path")
    args = parser.parse_args()
    result = audit(args.path)
    payload = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    print(payload, end="")
    return 1 if result.get("unsafe_paths") or result.get("unexpected_executables") else 0


if __name__ == "__main__":
    raise SystemExit(main())
