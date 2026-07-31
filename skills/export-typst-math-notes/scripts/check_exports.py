#!/usr/bin/env python3
"""Check a QLNotes LaTeX/Markdown export pair for semantic consistency."""

from __future__ import annotations

import argparse
import collections
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


SUPPORTED = {
    "definition",
    "theorem",
    "lemma",
    "corollary",
    "proposition",
    "example",
    "proof",
    "solution",
    "remark",
    "note",
}
LATEX_TO_KIND = {
    "definition": "definition",
    "theorem": "theorem",
    "lemma": "lemma",
    "corollary": "corollary",
    "proposition": "proposition",
    "example": "example",
    "proof": "proof",
    "qlsolution": "solution",
    "qlremark": "remark",
    "qlnote": "note",
}
MARKDOWN_READER = (
    "markdown+yaml_metadata_block+tex_math_dollars+fenced_divs+"
    "pipe_tables+link_attributes"
)


class CheckError(RuntimeError):
    """Raised when an export violates the QLNotes contract."""


def read_text(path: Path) -> str:
    if not path.is_file():
        raise CheckError(f"missing required file: {path}")
    return path.read_text(encoding="utf-8")


def front_matter(markdown: str) -> tuple[str, dict[str, str]]:
    if not markdown.startswith("---\n"):
        raise CheckError("Markdown must start with YAML front matter")
    try:
        header, _ = markdown[4:].split("\n---\n", 1)
    except ValueError as error:
        raise CheckError("Markdown YAML front matter is not terminated") from error

    values: dict[str, str] = {}
    for line in header.splitlines():
        match = re.match(r"^([A-Za-z0-9_-]+):(?:\s+(.*))?$", line)
        if match:
            values[match.group(1)] = (match.group(2) or "").strip()
    return header, values


def markdown_environments(text: str) -> tuple[collections.Counter[str], dict[str, str]]:
    counts: collections.Counter[str] = collections.Counter()
    semantic: dict[str, str] = {}
    # Attribute values can contain TeX braces (for example
    # aliases="L^2_0(\\Omega, \\mathbb{P})"), so match the complete
    # single-line attribute block instead of stopping at the first `}`.
    fence = re.compile(
        r"^[ \t]*:{3,}\s+(\{[^\n]+\}|[A-Za-z][\w-]*)\s*$",
        re.MULTILINE,
    )
    for match in fence.finditer(text):
        spec = match.group(1)
        if spec.startswith("{"):
            classes = re.findall(r"\.([A-Za-z][\w-]*)", spec)
            kind = next((item for item in classes if item in SUPPORTED), None)
            identifier_match = re.search(r"#([A-Za-z0-9][\w:.-]*)", spec)
        else:
            kind = spec
            identifier_match = None
        if kind not in SUPPORTED:
            continue
        counts[kind] += 1
        if identifier_match:
            identifier = identifier_match.group(1)
            if identifier in semantic:
                raise CheckError(f"duplicate Markdown semantic ID: {identifier}")
            semantic[identifier] = kind
    return counts, semantic


def latex_environments(text: str) -> collections.Counter[str]:
    counts: collections.Counter[str] = collections.Counter()
    for environment in re.findall(r"\\begin\{([^}]+)\}", text):
        kind = LATEX_TO_KIND.get(environment)
        if kind:
            counts[kind] += 1
    return counts


def latex_semantics(text: str) -> dict[str, str]:
    semantic: dict[str, str] = {}
    pattern = re.compile(
        r"^% qlnotes: kind=([a-z-]+); id=([^;\s]+)(?:;.*)?$",
        re.MULTILINE,
    )
    for kind, identifier in pattern.findall(text):
        if identifier in semantic:
            raise CheckError(f"duplicate LaTeX semantic ID: {identifier}")
        semantic[identifier] = kind
    return semantic


def citation_keys(markdown: str, latex: str) -> tuple[set[str], set[str]]:
    citation_groups = re.findall(r"\[([^\]\n]*@[^\]\n]*)\]", markdown)
    markdown_keys = {
        key
        for group in citation_groups
        for key in re.findall(r"@([A-Za-z0-9][A-Za-z0-9:./_-]*)", group)
    }
    latex_groups = re.findall(
        r"\\(?:auto|text|paren)?cite\*?(?:\[[^\]]*\])*\{([^}]+)\}",
        latex,
    )
    latex_keys = {
        key.strip()
        for group in latex_groups
        for key in group.split(",")
        if key.strip()
    }
    return markdown_keys, latex_keys


def asset_paths(markdown: str, latex: str) -> tuple[set[Path], set[Path]]:
    markdown_assets = {
        Path(value)
        for value in re.findall(
            r"\]\(([^)\s]+\.(?:svg|png|jpe?g|webp|gif))\)",
            markdown,
            flags=re.IGNORECASE,
        )
    }
    latex_assets = {
        Path(value)
        for value in re.findall(
            r"\\includegraphics(?:\[[^\]]*\])?"
            r"\{(assets/[^}]+\.(?:pdf|png|jpe?g|webp|gif))\}",
            latex,
            flags=re.IGNORECASE,
        )
    }
    return markdown_assets, latex_assets


def run(command: list[str], cwd: Path) -> None:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if result.returncode:
        tail = "\n".join(result.stdout.splitlines()[-30:])
        raise CheckError(f"command failed: {' '.join(command)}\n{tail}")


def require_commands(commands: tuple[str, ...]) -> None:
    missing = [command for command in commands if shutil.which(command) is None]
    if missing:
        raise CheckError(
            "missing command(s) required by --full: " + ", ".join(missing)
        )


def check(args: argparse.Namespace) -> None:
    export_dir = args.export_dir.resolve()
    markdown_dir = export_dir / "markdown"
    latex_dir = export_dir / "latex"
    markdown_path = markdown_dir / "main.md"
    latex_path = latex_dir / "main.tex"

    markdown = read_text(markdown_path)
    latex = read_text(latex_path)
    read_text(latex_dir / "qlnotes-export.cls")
    read_text(latex_dir / "elegantbook.cls")

    header, metadata = front_matter(markdown)
    if metadata.get("authority") != "typst":
        raise CheckError("Markdown authority must be `typst`")
    if metadata.get("qlnotes-schema") != "qlnotes-v1":
        raise CheckError("Markdown qlnotes-schema must be `qlnotes-v1`")
    if args.source and metadata.get("source") != args.source.name:
        raise CheckError(
            f"Markdown source is {metadata.get('source')!r}, "
            f"expected {args.source.name!r}"
        )

    markdown_counts, markdown_semantic = markdown_environments(markdown)
    latex_counts = latex_environments(latex)
    latex_semantic = latex_semantics(latex)
    if markdown_semantic != latex_semantic:
        raise CheckError(
            "semantic ID/kind mappings differ:\n"
            f"Markdown: {markdown_semantic}\nLaTeX: {latex_semantic}"
        )
    if markdown_counts != latex_counts:
        raise CheckError(
            "environment counts differ:\n"
            f"Markdown: {dict(markdown_counts)}\n"
            f"LaTeX: {dict(latex_counts)}"
        )

    raw_count = metadata.get("semantic-node-count")
    try:
        declared_count = int((raw_count or "").strip("\"'"))
    except ValueError as error:
        raise CheckError("semantic-node-count must be an integer") from error
    if declared_count != len(markdown_semantic):
        raise CheckError(
            f"semantic-node-count is {declared_count}, "
            f"but {len(markdown_semantic)} stable IDs were exported"
        )

    markdown_citations, latex_citations = citation_keys(markdown, latex)
    if markdown_citations != latex_citations:
        raise CheckError(
            "citation keys differ:\n"
            f"Markdown: {sorted(markdown_citations)}\n"
            f"LaTeX: {sorted(latex_citations)}"
        )

    if re.search(r"^bibliography:\s*$", header, re.MULTILINE):
        read_text(markdown_dir / "reference.bib")
        read_text(latex_dir / "reference.bib")

    markdown_assets, latex_assets = asset_paths(markdown, latex)
    expected_asset_dir = f"{markdown_path.stem}.assets"
    misplaced = [
        path
        for path in markdown_assets
        if len(path.parts) != 2 or path.parts[0] != expected_asset_dir
    ]
    if misplaced:
        raise CheckError(
            "Markdown images must use the Typora sidecar directory "
            f"{expected_asset_dir}/: {sorted(map(str, misplaced))}"
        )
    for relative in markdown_assets:
        asset = markdown_dir / relative
        if relative.suffix.lower() == ".svg":
            read_text(asset)
        elif not asset.is_file():
            raise CheckError(f"missing required file: {asset}")
    for relative in latex_assets:
        if not (latex_dir / relative).is_file():
            raise CheckError(f"missing required file: {latex_dir / relative}")
    markdown_stems = {path.stem for path in markdown_assets}
    latex_stems = {path.stem for path in latex_assets}
    if markdown_stems != latex_stems:
        raise CheckError(
            "diagram asset stems differ:\n"
            f"Markdown: {sorted(markdown_stems)}\n"
            f"LaTeX: {sorted(latex_stems)}"
        )
    supported_markdown_assets = {".svg", ".png", ".jpg", ".jpeg", ".webp", ".gif"}
    actual_markdown_assets = {
        path.relative_to(markdown_dir)
        for path in (markdown_dir / expected_asset_dir).iterdir()
        if path.is_file() and path.suffix.lower() in supported_markdown_assets
    }
    if actual_markdown_assets != markdown_assets:
        raise CheckError(
            "referenced and stored Markdown images differ:\n"
            f"Referenced: {sorted(map(str, markdown_assets))}\n"
            f"Stored: {sorted(map(str, actual_markdown_assets))}"
        )

    if "data:image/" in markdown or "data:image/" in latex:
        raise CheckError("embedded data URI leaked into an editable export")

    if args.full:
        require_commands(("pandoc", "latexmk", "lualatex", "biber"))
        run(
            [
                "pandoc",
                "main.md",
                "--from",
                MARKDOWN_READER,
                "--to",
                "json",
            ],
            markdown_dir,
        )
        with tempfile.TemporaryDirectory(prefix="qlnotes-latex-") as temp_dir:
            run(
                [
                    "latexmk",
                    "-gg",
                    "-lualatex",
                    "-interaction=nonstopmode",
                    "-halt-on-error",
                    "-file-line-error",
                    f"-outdir={temp_dir}",
                    "main.tex",
                ],
                latex_dir,
            )

    print(f"OK: {export_dir}")
    print(
        f"semantic nodes: {declared_count}; "
        f"environments: {sum(markdown_counts.values())}; "
        f"citations: {len(markdown_citations)}; "
        f"image assets: {len(markdown_assets)}"
    )
    print(f"Markdown: {markdown_path}")
    print(f"LaTeX: {latex_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "export_dir",
        type=Path,
        help="directory containing markdown/ and latex/ snapshots",
    )
    parser.add_argument(
        "--source",
        type=Path,
        help="authoritative Typst source; validates the YAML source basename",
    )
    parser.add_argument(
        "--full",
        action="store_true",
        help="also parse Markdown and compile LaTeX in a temporary directory",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        check(args)
    except (CheckError, OSError, UnicodeError) as error:
        print(f"export check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
