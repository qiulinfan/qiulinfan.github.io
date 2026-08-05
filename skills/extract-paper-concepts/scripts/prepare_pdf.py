#!/usr/bin/env python3
"""Prepare a local paper PDF for page-grounded TeX normalization."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
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


def text_record(
    *,
    page_number: int,
    extracted: str,
    text_path: Path,
    destination: Path,
    width: float | None,
    height: float | None,
    embedded_images: int | None,
) -> dict[str, Any]:
    text_path.write_text(extracted.rstrip() + "\n", encoding="utf-8")
    compact = "".join(extracted.split())
    replacement_count = extracted.count("\ufffd")
    return {
        "page": page_number,
        "width": width,
        "height": height,
        "text_path": text_path.relative_to(destination.parent).as_posix(),
        "extracted_characters": len(compact),
        "replacement_characters": replacement_count,
        "embedded_images": embedded_images,
        "needs_ocr_or_visual_transcription": (
            len(compact) < 80 or replacement_count > max(2, len(compact) // 100)
        ),
    }


def extract_pages_with_pdfplumber(
    source: Path, destination: Path, pdfplumber: Any
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    destination.mkdir(parents=True, exist_ok=True)
    pages: list[dict[str, Any]] = []
    with pdfplumber.open(source) as pdf:
        metadata = {str(key): str(value) for key, value in (pdf.metadata or {}).items()}
        for page_number, page in enumerate(pdf.pages, start=1):
            extracted = page.extract_text(layout=True) or ""
            pages.append(
                text_record(
                    page_number=page_number,
                    extracted=extracted,
                    text_path=destination / f"page-{page_number:04d}.txt",
                    destination=destination,
                    width=float(page.width),
                    height=float(page.height),
                    embedded_images=len(page.images),
                )
            )
    return metadata, pages


def pdfinfo_metadata(source: Path, pdfinfo: str) -> tuple[dict[str, str], int, float | None, float | None]:
    result = subprocess.run(
        [pdfinfo, str(source)], check=False, capture_output=True, text=True
    )
    if result.returncode:
        raise PrepareError(result.stderr.strip() or "pdfinfo failed")
    metadata: dict[str, str] = {}
    for line in result.stdout.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        metadata[key.strip()] = value.strip()
    try:
        page_count = int(metadata["Pages"])
    except (KeyError, ValueError) as error:
        raise PrepareError("pdfinfo did not report a valid page count") from error
    width: float | None = None
    height: float | None = None
    match = re.match(r"([0-9.]+)\s+x\s+([0-9.]+)\s+pts", metadata.get("Page size", ""))
    if match:
        width, height = float(match.group(1)), float(match.group(2))
    return metadata, page_count, width, height


def extract_pages_with_ghostscript(
    source: Path, destination: Path, ghostscript: str, pdfinfo: str
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    metadata, page_count, width, height = pdfinfo_metadata(source, pdfinfo)
    destination.mkdir(parents=True, exist_ok=True)
    pages: list[dict[str, Any]] = []
    for page_number in range(1, page_count + 1):
        text_path = destination / f"page-{page_number:04d}.txt"
        result = subprocess.run(
            [
                ghostscript,
                "-q",
                "-dSAFER",
                "-dBATCH",
                "-dNOPAUSE",
                "-sDEVICE=txtwrite",
                f"-dFirstPage={page_number}",
                f"-dLastPage={page_number}",
                f"-sOutputFile={text_path}",
                str(source),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode:
            raise PrepareError(
                result.stderr.strip()
                or f"Ghostscript text extraction failed on page {page_number}"
            )
        extracted = text_path.read_text(encoding="utf-8", errors="replace")
        pages.append(
            text_record(
                page_number=page_number,
                extracted=extracted,
                text_path=text_path,
                destination=destination,
                width=width,
                height=height,
                embedded_images=None,
            )
        )
    return metadata, pages


def extract_pages(
    source: Path, destination: Path
) -> tuple[dict[str, Any], list[dict[str, Any]], str]:
    try:
        import pdfplumber  # type: ignore[import-not-found]
    except ImportError:
        ghostscript = shutil.which("gs")
        pdfinfo = shutil.which("pdfinfo")
        if ghostscript is None or pdfinfo is None:
            raise PrepareError(
                "text extraction requires pdfplumber, or both Ghostscript gs and pdfinfo"
            )
        metadata, pages = extract_pages_with_ghostscript(
            source, destination, ghostscript, pdfinfo
        )
        return metadata, pages, "ghostscript-txtwrite"
    metadata, pages = extract_pages_with_pdfplumber(source, destination, pdfplumber)
    return metadata, pages, "pdfplumber"


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
        metadata, pages, text_tool = extract_pages(source, output / "text")
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
            "tools": {"text": text_tool, "render": "pdftoppm", "dpi": args.dpi},
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
