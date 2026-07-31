#!/usr/bin/env python3
"""Export one authoritative QLNotes Typst file to editable LaTeX and Markdown."""

from __future__ import annotations

import argparse
import html
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


TOOLCHAIN = Path(__file__).resolve().parents[1]
FILTER = TOOLCHAIN / "filters" / "qlnotes.lua"
LATEX_TEMPLATE = TOOLCHAIN / "latex" / "template.tex"
LATEX_CLASS = TOOLCHAIN / "latex" / "qlnotes-export.cls"
ELEGANT_CLASS = TOOLCHAIN / "latex" / "elegantbook.cls"

FIGURE_RE = re.compile(
    r"""<figure(?P<attrs>(?:[^>"']+|"[^"]*"|'[^']*')*)>"""
    r"(?P<body>.*?)</figure>",
    flags=re.DOTALL | re.IGNORECASE,
)
SVG_RE = re.compile(r"<svg\b.*?</svg>", flags=re.DOTALL | re.IGNORECASE)
ATTR_RE = re.compile(
    r"""(?P<name>[-:\w]+)\s*=\s*(?P<quote>["'])(?P<value>.*?)(?P=quote)""",
    flags=re.DOTALL,
)


class ExportError(RuntimeError):
    pass


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise ExportError(f"command failed: {' '.join(command)}\n{detail}")
    if result.stderr.strip():
        print(result.stderr.strip(), file=sys.stderr)
    return result


def require_commands(commands: tuple[str, ...]) -> None:
    missing = [command for command in commands if shutil.which(command) is None]
    if missing:
        joined = ", ".join(missing)
        raise ExportError(
            f"missing required command(s): {joined}. "
            "Run `make setup` from the Typst template directory."
        )


def clean_generated_assets(directory: Path, suffixes: set[str]) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for path in directory.iterdir():
        if path.is_file() and path.suffix.lower() in suffixes:
            path.unlink()


def typst_metadata(source: Path, root: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    expression = "query(selector(metadata)).map(it => it.value)"
    result = run(
        [
            "typst",
            "eval",
            expression,
            "--features",
            "html",
            "--target",
            "html",
            "--input",
            "ql-export=true",
            "--root",
            str(root),
            "--in",
            str(source),
            "--format",
            "json",
        ]
    )
    records = json.loads(result.stdout)
    documents = [
        record for record in records if record.get("schema") == "qlnotes-document-v1"
    ]
    nodes = [record for record in records if record.get("schema") == "qlnotes-v1"]
    if len(documents) != 1:
        raise ExportError(
            f"expected exactly one qlnotes-document-v1 record, found {len(documents)}"
        )
    missing_ids = [record for record in nodes if not record.get("id")]
    if missing_ids:
        raise ExportError("every semantic qlnotes-v1 record must have a stable id")
    return documents[0], nodes


def parse_attrs(raw: str) -> dict[str, str]:
    return {
        match.group("name").lower(): html.unescape(match.group("value"))
        for match in ATTR_RE.finditer(raw)
    }


def safe_asset_name(value: str, index: int) -> str:
    candidate = re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-._")
    if not candidate:
        candidate = f"figure-{index:03d}"
    return candidate


def extract_diagrams(
    source_html: str,
    markdown_assets: Path,
    latex_assets: Path,
) -> tuple[str, list[str]]:
    clean_generated_assets(markdown_assets, {".svg"})
    clean_generated_assets(latex_assets, {".pdf"})
    names: list[str] = []
    used: set[str] = set()
    figure_index = 0

    def replace(match: re.Match[str]) -> str:
        nonlocal figure_index
        attrs_raw = match.group("attrs") or ""
        body = match.group("body")
        svg_match = SVG_RE.search(body)
        if svg_match is None:
            return match.group(0)

        figure_index += 1
        attrs = parse_attrs(attrs_raw)
        base = safe_asset_name(
            attrs.get("data-ql-id") or attrs.get("id") or "",
            figure_index,
        )
        name = base
        duplicate = 2
        while name in used:
            name = f"{base}-{duplicate}"
            duplicate += 1
        used.add(name)
        names.append(name)

        svg_text = svg_match.group(0)
        svg_path = markdown_assets / f"{name}.svg"
        pdf_path = latex_assets / f"{name}.pdf"
        svg_path.write_text(svg_text + "\n", encoding="utf-8")
        run(
            [
                "rsvg-convert",
                "--format",
                "pdf",
                "--output",
                str(pdf_path),
                str(svg_path),
            ]
        )

        alt = attrs.get("aria-label", "")
        image_tag = (
            f'<img src="{markdown_assets.name}/{name}.svg" '
            f'alt="{html.escape(alt, quote=True)}">'
        )
        replacement_body = (
            body[: svg_match.start()] + image_tag + body[svg_match.end() :]
        )

        identifier = attrs.get("data-ql-id") or attrs.get("id")
        figure_attrs = f' id="{html.escape(identifier, quote=True)}"' if identifier else ""
        return f"<figure{figure_attrs}>{replacement_body}</figure>"

    return FIGURE_RE.sub(replace, source_html), names


def resolve_bibliography(source: Path, value: str | None) -> Path | None:
    if not value:
        return None
    path = Path(value)
    if not path.is_absolute():
        path = source.parent / path
    path = path.resolve()
    if not path.is_file():
        raise ExportError(f"bibliography does not exist: {path}")
    return path


def pandoc_metadata(
    document: dict[str, Any],
    nodes: list[dict[str, Any]],
    source: Path,
    has_bibliography: bool,
) -> dict[str, Any]:
    metadata = {
        "title": document.get("title") or source.stem,
        "subtitle": document.get("subtitle") or "",
        "course": document.get("course") or "",
        "author": [document["author"]] if document.get("author") else [],
        "date": document.get("date") or "",
        "description": document.get("description") or "",
        "keywords": document.get("keywords") or [],
        "qlnotes-keywords": document.get("keywords") or [],
        "qlnotes-language": document.get("language") or "zh-CN",
        "source": source.name,
        "authority": "typst",
        "qlnotes-schema": "qlnotes-v1",
        "semantic-node-count": len(nodes),
    }
    if has_bibliography:
        metadata["bibliography"] = ["reference.bib"]
    return metadata


def export(
    source: Path,
    root: Path,
    output: Path,
    build: Path,
) -> None:
    require_commands(("typst", "pandoc", "rsvg-convert"))

    source = source.resolve()
    root = root.resolve()
    output = output.resolve()
    build = build.resolve()
    if not source.is_file():
        raise ExportError(f"Typst source does not exist: {source}")
    if root not in source.parents and root != source.parent:
        raise ExportError(f"source must be inside Typst root: {root}")

    markdown_dir = output / "markdown"
    latex_dir = output / "latex"
    markdown_assets = markdown_dir / "main.assets"
    latex_assets = latex_dir / "assets"
    build.mkdir(parents=True, exist_ok=True)
    markdown_dir.mkdir(parents=True, exist_ok=True)
    latex_dir.mkdir(parents=True, exist_ok=True)

    document, nodes = typst_metadata(source, root)
    raw_html = build / f"{source.stem}.html"
    run(
        [
            "typst",
            "compile",
            "--root",
            str(root),
            "--features",
            "html",
            "--format",
            "html",
            "--input",
            "ql-export=true",
            str(source),
            str(raw_html),
        ]
    )

    converted_html, diagrams = extract_diagrams(
        raw_html.read_text(encoding="utf-8"),
        markdown_assets,
        latex_assets,
    )
    prepared_html = build / f"{source.stem}.prepared.html"
    prepared_html.write_text(converted_html, encoding="utf-8")

    bibliography = resolve_bibliography(source, document.get("bibliography"))
    if bibliography is not None:
        shutil.copy2(bibliography, markdown_dir / "reference.bib")
        shutil.copy2(bibliography, latex_dir / "reference.bib")

    metadata = pandoc_metadata(document, nodes, source, bibliography is not None)
    metadata_file = build / f"{source.stem}.metadata.json"
    metadata_file.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    shutil.copy2(LATEX_CLASS, latex_dir / LATEX_CLASS.name)
    shutil.copy2(ELEGANT_CLASS, latex_dir / ELEGANT_CLASS.name)

    common = [
        "pandoc",
        str(prepared_html),
        "--from",
        "html",
        "--lua-filter",
        str(FILTER),
        "--metadata-file",
        str(metadata_file),
        "--wrap",
        "preserve",
    ]
    run(
        common
        + [
            "--to",
            "markdown+yaml_metadata_block+tex_math_dollars+fenced_divs+pipe_tables+link_attributes",
            "--standalone",
            "--output",
            "main.md",
        ],
        cwd=markdown_dir,
    )
    run(
        common
        + [
            "--to",
            "latex",
            "--standalone",
            "--biblatex",
            "--top-level-division",
            "chapter",
            "--template",
            str(LATEX_TEMPLATE),
            "--output",
            "main.tex",
        ],
        cwd=latex_dir,
    )

    markdown = (markdown_dir / "main.md").read_text(encoding="utf-8")
    latex = (latex_dir / "main.tex").read_text(encoding="utf-8")
    if "data:image/" in markdown or "data:image/" in latex:
        raise ExportError("embedded data URI leaked into an editable export")
    if diagrams and any(
        not (markdown_assets / f"{name}.svg").is_file()
        or not (latex_assets / f"{name}.pdf").is_file()
        for name in diagrams
    ):
        raise ExportError("one or more diagram assets were not exported")

    print(f"Typst authority: {source}")
    print(f"Editable LaTeX: {latex_dir / 'main.tex'}")
    print(f"Editable Markdown: {markdown_dir / 'main.md'}")
    print(f"Semantic nodes: {len(nodes)}; diagrams: {len(diagrams)}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="authoritative Typst source")
    parser.add_argument(
        "--root",
        type=Path,
        default=TOOLCHAIN,
        help="Typst project root",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=TOOLCHAIN / "exports",
        help="directory containing latex/ and markdown/",
    )
    parser.add_argument(
        "--build",
        type=Path,
        default=TOOLCHAIN / "dist" / "export-build",
        help="ignored directory for intermediate HTML and metadata",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        export(args.source, args.root, args.output, args.build)
    except (ExportError, OSError, json.JSONDecodeError) as error:
        print(f"export failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
