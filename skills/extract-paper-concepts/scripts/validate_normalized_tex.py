#!/usr/bin/env python3
"""Validate the mechanical PDF-to-TeX normalization invariants."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


SCHEMA = "qlpaper-pdf-preflight-v1"
FORBIDDEN_MEDIA = {
    r"\includegraphics": "external image",
    r"\includepdf": "embedded PDF",
    r"\includesvg": "external SVG",
    r"\epsfig": "external EPS",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def compile_tex(tex: Path) -> None:
    latexmk = shutil.which("latexmk")
    if latexmk is None:
        raise RuntimeError("latexmk is required for --compile")
    with tempfile.TemporaryDirectory(prefix="qlpaper-tex-") as temporary:
        result = subprocess.run(
            [
                latexmk,
                "-pdf",
                "-interaction=nonstopmode",
                "-halt-on-error",
                f"-outdir={temporary}",
                str(tex),
            ],
            cwd=tex.parent,
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode:
            tail = "\n".join((result.stdout + result.stderr).splitlines()[-30:])
            raise RuntimeError(f"TeX compilation failed:\n{tail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tex", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--compile", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tex = args.tex.expanduser().resolve()
    manifest_path = args.manifest.expanduser().resolve()
    errors: list[str] = []
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        content = tex.read_text(encoding="utf-8")
    except (OSError, json.JSONDecodeError) as error:
        print(f"validate_normalized_tex: {error}", file=sys.stderr)
        return 1

    if manifest.get("schema") != SCHEMA:
        errors.append(f"manifest schema must be {SCHEMA}")
    page_count = manifest.get("page_count")
    if not isinstance(page_count, int) or page_count < 1:
        errors.append("manifest page_count must be a positive integer")
        page_count = 0

    expected_digest = str(manifest.get("source_sha256", ""))
    header_match = re.search(r"^% qlpaper-source-sha256: ([0-9a-f]{64})$", content, re.M)
    if not content.startswith("% qlpaper-normalized-v1\n"):
        errors.append("missing qlpaper-normalized-v1 header")
    if header_match is None or header_match.group(1) != expected_digest:
        errors.append("TeX source digest header does not match manifest")
    if "QLPAPER_UNRESOLVED" in content:
        errors.append("unresolved PDF-page transcription markers remain")
    if "QLPAPER_VISUAL_REQUIRED" in content:
        errors.append("visual-description markers remain")
    if "QLPAPER_PAGE_LOCATION_REVIEW" in content:
        errors.append("low-confidence PDF-page location markers remain")

    for command, label in FORBIDDEN_MEDIA.items():
        if command in content:
            errors.append(f"forbidden {label} command remains: {command}")

    found_pages = [
        int(value)
        for value in re.findall(r"^% qlpaper-source: page=(\d+)$", content, re.M)
    ]
    expected_pages = list(range(1, page_count + 1))
    if found_pages != expected_pages:
        errors.append(
            "page markers must appear exactly once in PDF order: "
            f"expected {expected_pages}, found {found_pages}"
        )

    source_pdf = manifest_path.parent / str(manifest.get("source_pdf", "source.pdf"))
    if not source_pdf.is_file():
        errors.append(f"source PDF is missing: {source_pdf}")
    elif expected_digest and sha256(source_pdf) != expected_digest:
        errors.append("source PDF digest no longer matches manifest")

    page_records = manifest.get("pages", [])
    if not isinstance(page_records, list):
        errors.append("manifest pages must be a list")
        page_records = []
    for page in expected_pages:
        record = next(
            (
                item
                for item in page_records
                if isinstance(item, dict) and item.get("page") == page
            ),
            None,
        )
        if not isinstance(record, dict):
            errors.append(f"manifest has no record for PDF page {page}")
            continue
        for key in ("text_path", "render_path"):
            path = manifest_path.parent / str(record.get(key, ""))
            if not path.is_file():
                errors.append(f"page {page} {key} is missing: {path}")

    if not errors and args.compile:
        try:
            compile_tex(tex)
        except RuntimeError as error:
            errors.append(str(error))

    if errors:
        for error in errors:
            print(f"validate_normalized_tex: {error}", file=sys.stderr)
        return 1

    result = {
        "schema": "qlpaper-normalized-tex-validation-v1",
        "status": "ok",
        "pages": page_count,
        "tex_sha256": sha256(tex),
        "compiled": bool(args.compile),
    }
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
