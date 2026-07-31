#!/usr/bin/env python3
"""Migrate legacy QLNotes LaTeX chapters into semantic Typst source files."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


TOOLCHAIN = Path(__file__).resolve().parents[1]
FILTER = TOOLCHAIN / "filters" / "latex-to-qlnotes.lua"
TIKZ_RE = re.compile(
    r"(?ms)^[ \t]*\\begin\{tikzpicture\}(?:\[[^\n]*\])?.*?"
    r"^[ \t]*\\end\{tikzpicture\}[ \t]*$"
)
CODE_RE = re.compile(
    r"(?ms)^[ \t]*\\begin\{(?P<kind>python|terminal)\}"
    r"(?:\[[^\n]*\])?[ \t]*\n(?P<body>.*?)"
    r"^[ \t]*\\end\{(?P=kind)\}[ \t]*$"
)


class MigrationError(RuntimeError):
    pass


def slug(value: str) -> str:
    candidate = re.sub(r"[^A-Za-z0-9]+", "-", value.lower()).strip("-")
    return candidate or "chapter"


def expand_math_aliases(source: str) -> str:
    source = re.sub(r"\\bf\{([A-Za-z])\}", r"\\mathbf{\1}", source)
    source = re.sub(r"\\b([A-Z])(?![A-Za-z])", r"\\mathbb{\1}", source)
    source = re.sub(r"\\c([A-Z])(?![A-Za-z])", r"\\mathcal{\1}", source)
    source = re.sub(r"\\bf([A-Z])(?![A-Za-z])", r"\\mathbf{\1}", source)
    return source


def extract_code(source: str) -> str:
    def replace(match: re.Match[str]) -> str:
        return (
            "\\begin{verbatim}\n"
            f"QLNOTESCODE:{match.group('kind')}\n"
            f"{match.group('body').rstrip()}\n"
            "\\end{verbatim}"
        )

    return CODE_RE.sub(replace, source)


def extract_diagrams(
    source: str,
    chapter: str,
    diagram_dir: Path,
) -> tuple[str, list[dict[str, Any]]]:
    records: list[dict[str, Any]] = []
    diagram_dir.mkdir(parents=True, exist_ok=True)

    def replace(match: re.Match[str]) -> str:
        index = len(records) + 1
        identifier = f"prob-{chapter}-diagram-{index:02d}"
        tikz_path = diagram_dir / f"{identifier}.tikz"
        tikz_path.write_text(match.group(0).strip() + "\n", encoding="utf-8")
        records.append(
            {
                "id": identifier,
                "chapter": chapter,
                "index": index,
                "tikz": str(tikz_path),
            }
        )
        return f"\\par QLNOTESDIAGRAM:{identifier} \\par"

    return TIKZ_RE.sub(replace, source), records


def run_pandoc(source: str, chapter: str, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment["QLNOTES_CHAPTER"] = chapter
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".tex",
        encoding="utf-8",
        delete=False,
    ) as stream:
        stream.write(source)
        temporary = Path(stream.name)

    try:
        result = subprocess.run(
            [
                "pandoc",
                str(temporary),
                "--from",
                "latex",
                "--to",
                "typst",
                "--wrap",
                "preserve",
                "--lua-filter",
                str(FILTER),
                "--output",
                str(output),
            ],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=environment,
        )
    finally:
        temporary.unlink(missing_ok=True)

    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise MigrationError(f"Pandoc failed for {output.name}:\n{detail}")
    if result.stderr.strip():
        print(result.stderr.strip(), file=sys.stderr)


def _matching_delimiter(
    source: str,
    start: int,
    opening: str,
    closing: str,
) -> int:
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(source)):
        character = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            continue
        if escaped:
            escaped = False
            continue
        if character == '"':
            in_string = True
            continue
        if character == "\\":
            escaped = True
            continue
        if character == opening:
            depth += 1
        elif character == closing:
            depth -= 1
            if depth == 0:
                return index
    raise MigrationError(
        f"unbalanced Typst delimiter {opening!r} starting at byte {start}"
    )


def hoist_example_supporting_blocks(source: str) -> tuple[str, int]:
    """Move proof/solution blocks out of example figures so they can paginate."""

    pattern = re.compile(r"(?m)^[ \t]*#example(?=[(\[])")
    support = re.compile(r"(?m)^[ \t]*#(?:proof|solution)\[")
    cursor = 0
    changes = 0
    while match := pattern.search(source, cursor):
        call_end = match.end()
        if source[call_end] == "(":
            arguments_end = _matching_delimiter(source, call_end, "(", ")")
            body_start = arguments_end + 1
            while body_start < len(source) and source[body_start].isspace():
                body_start += 1
        else:
            body_start = call_end
        if body_start >= len(source) or source[body_start] != "[":
            cursor = call_end
            continue
        body_end = _matching_delimiter(source, body_start, "[", "]")
        nested = support.search(source, body_start + 1, body_end)
        if nested is None:
            cursor = body_end + 1
            continue
        support_start = nested.start()
        source = (
            source[:support_start]
            + "]\n"
            + source[support_start:body_end]
            + source[body_end + 1 :]
        )
        changes += 1
        cursor = support_start + 2
    return source, changes


def migrate(
    sources: list[Path],
    output_dir: Path,
    diagram_dir: Path,
    manifest: Path | None,
) -> None:
    all_diagrams: list[dict[str, Any]] = []
    for source_path in sources:
        source_path = source_path.resolve()
        if not source_path.is_file():
            raise MigrationError(f"source does not exist: {source_path}")
        chapter = slug(source_path.stem)
        text = source_path.read_text(encoding="utf-8")
        text, diagrams = extract_diagrams(text, chapter, diagram_dir)
        text = extract_code(text)
        text = expand_math_aliases(text)
        output = output_dir / f"{source_path.stem}.typ"
        run_pandoc(text, chapter, output)
        migrated, hoisted = hoist_example_supporting_blocks(
            output.read_text(encoding="utf-8")
        )
        if hoisted:
            output.write_text(migrated, encoding="utf-8")
        all_diagrams.extend(diagrams)
        print(
            f"Migrated {source_path.name} -> {output} "
            f"({len(diagrams)} diagram(s), "
            f"{hoisted} supporting block(s) hoisted)"
        )

    if manifest is not None:
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(
            json.dumps(all_diagrams, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", nargs="+", type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--diagram-dir", required=True, type=Path)
    parser.add_argument("--manifest", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        migrate(
            args.sources,
            args.output_dir.resolve(),
            args.diagram_dir.resolve(),
            args.manifest.resolve() if args.manifest else None,
        )
    except (MigrationError, OSError) as error:
        print(f"migration failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
