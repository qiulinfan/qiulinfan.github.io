#!/usr/bin/env python3
"""Prepare a local paper PDF for page-grounded TeX normalization."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Any


SCHEMA = "qlpaper-pdf-preflight-v1"


class PrepareError(RuntimeError):
    """Raised when a PDF cannot be prepared safely."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_empty_output(path: Path) -> None:
    if path.exists() and any(path.iterdir()):
        raise PrepareError(f"output directory is not empty: {path}")
    path.mkdir(parents=True, exist_ok=True)


def render_pages(source: Path, destination: Path, dpi: int) -> list[Path]:
    renderer = shutil.which("pdftoppm")
    if renderer is None:
        raise PrepareError("pdftoppm is required to render every PDF page")
    destination.mkdir(parents=True, exist_ok=True)
    prefix = destination / "page"
    result = subprocess.run(
        [renderer, "-png", "-r", str(dpi), str(source), str(prefix)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise PrepareError(result.stderr.strip() or "pdftoppm failed")
    rendered: list[Path] = []
    for raw in destination.glob("page-*.png"):
        try:
            page_number = int(raw.stem.rsplit("-", 1)[1])
        except (IndexError, ValueError) as error:
            raise PrepareError(f"unexpected rendered page name: {raw.name}") from error
        target = destination / f"page-{page_number:04d}.png"
        raw.rename(target)
        rendered.append(target)
    return sorted(rendered)


def extract_pages(source: Path, destination: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    try:
        import pdfplumber  # type: ignore[import-not-found]
    except ImportError as error:
        raise PrepareError("pdfplumber is required for per-page extraction") from error

    destination.mkdir(parents=True, exist_ok=True)
    pages: list[dict[str, Any]] = []
    with pdfplumber.open(source) as pdf:
        metadata = {str(key): str(value) for key, value in (pdf.metadata or {}).items()}
        for page_number, page in enumerate(pdf.pages, start=1):
            extracted = page.extract_text(layout=True) or ""
            text_path = destination / f"page-{page_number:04d}.txt"
            text_path.write_text(extracted.rstrip() + "\n", encoding="utf-8")
            compact = "".join(extracted.split())
            replacement_count = extracted.count("\ufffd")
            pages.append(
                {
                    "page": page_number,
                    "width": float(page.width),
                    "height": float(page.height),
                    "text_path": text_path.relative_to(destination.parent).as_posix(),
                    "extracted_characters": len(compact),
                    "replacement_characters": replacement_count,
                    "embedded_images": len(page.images),
                    "needs_ocr_or_visual_transcription": (
                        len(compact) < 80 or replacement_count > max(2, len(compact) // 100)
                    ),
                }
            )
    return metadata, pages


def write_tex_skeleton(path: Path, digest: str, pages: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "% qlpaper-normalized-v1",
        f"% qlpaper-source-sha256: {digest}",
        "% Complete the transcription and remove every QLPAPER_UNRESOLVED marker.",
        r"\documentclass{article}",
        r"\usepackage[T1]{fontenc}",
        r"\usepackage{amsmath,amssymb,booktabs,longtable,tabularx}",
        r"\usepackage{tikz,pgfplots}",
        r"\pgfplotsset{compat=1.18}",
        r"\begin{document}",
    ]
    for record in pages:
        page = int(record["page"])
        lines.extend(
            [
                "",
                f"% qlpaper-source: page={page}",
                f"% QLPAPER_UNRESOLVED: transcribe and verify PDF page {page}",
            ]
        )
    lines.extend(["", r"\end{document}", ""])
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", type=Path, help="local source PDF")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--landing-url")
    parser.add_argument("--pdf-url")
    parser.add_argument("--identifier", help="DOI, arXiv ID, or another canonical ID")
    parser.add_argument("--version")
    parser.add_argument("--dpi", type=int, default=160)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_input = args.pdf.expanduser().resolve()
    output = args.output_dir.expanduser().resolve()
    try:
        if not source_input.is_file():
            raise PrepareError(f"PDF does not exist: {source_input}")
        with source_input.open("rb") as stream:
            signature = stream.read(5)
        if signature != b"%PDF-":
            raise PrepareError(f"input is not a PDF file: {source_input}")
        if not 72 <= args.dpi <= 400:
            raise PrepareError("--dpi must be between 72 and 400")
        require_empty_output(output)

        source = output / "source.pdf"
        shutil.copyfile(source_input, source)
        digest = sha256(source)
        metadata, pages = extract_pages(source, output / "text")
        if not pages:
            raise PrepareError("PDF contains no pages")
        renders = render_pages(source, output / "pages", args.dpi)
        if len(renders) != len(pages):
            raise PrepareError(
                f"rendered {len(renders)} pages but extracted {len(pages)} pages"
            )
        for record, render in zip(pages, renders):
            record["render_path"] = render.relative_to(output).as_posix()

        tex_path = output / "normalized" / "paper.tex"
        write_tex_skeleton(tex_path, digest, pages)
        manifest = {
            "schema": SCHEMA,
            "source_pdf": "source.pdf",
            "source_sha256": digest,
            "source_bytes": source.stat().st_size,
            "page_count": len(pages),
            "metadata": metadata,
            "acquisition": {
                "landing_url": args.landing_url,
                "pdf_url": args.pdf_url,
                "identifier": args.identifier,
                "version": args.version,
                "access_date": date.today().isoformat(),
            },
            "tools": {"text": "pdfplumber", "render": "pdftoppm", "dpi": args.dpi},
            "pages": pages,
            "normalized_tex": tex_path.relative_to(output).as_posix(),
        }
        (output / "source.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    except (OSError, PrepareError, ValueError) as error:
        print(f"prepare_pdf: {error}", file=sys.stderr)
        return 1

    print(
        json.dumps(
            {
                "schema": SCHEMA,
                "output": str(output),
                "pages": len(pages),
                "source_sha256": digest,
                "needs_review": sum(
                    bool(page["needs_ocr_or_visual_transcription"]) for page in pages
                ),
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
