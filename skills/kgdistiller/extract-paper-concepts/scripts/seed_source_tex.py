#!/usr/bin/env python3
"""Create an image-free normalized-TeX seed from an expanded official source."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


UNRESOLVED_INCLUDE = re.compile(r"\\(?:input|include|subfile)\s*\{[^{}]+\}")
MEDIA_COMMAND = re.compile(
    r"\\(?P<command>includegraphics|includepdf|includesvg|epsfig)"
    r"\s*(?:\[[^\]]*\]\s*)?\{(?P<path>[^{}]+)\}",
    re.S,
)
GRAPHICSPATH = re.compile(r"\\graphicspath\s*\{(?:\s*\{[^{}]*\}\s*)+\}", re.S)
PAGE_MARKER = re.compile(r"^% qlpaper-source: page=\d+\n?", re.M)
HEADER = re.compile(
    r"\A% qlpaper-normalized-v1\n% qlpaper-source-sha256: [0-9a-f]{64}\n?"
)
TOKEN = re.compile(r"[A-Za-z0-9]+")
COMMAND = re.compile(r"\\[A-Za-z@]+\*?")
COMMENT = re.compile(r"(?<!\\)%.*$")


class SeedError(RuntimeError):
    """Raised when a source cannot be converted into a safe seed."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def clean_source(content: str) -> tuple[str, list[dict[str, str]]]:
    content = HEADER.sub("", content)
    content = PAGE_MARKER.sub("", content)
    unresolved = UNRESOLVED_INCLUDE.findall(content)
    if unresolved:
        examples = ", ".join(unresolved[:5])
        raise SeedError(
            "source still contains input/include/subfile commands; expand it with "
            f"latexpand first. Examples: {examples}"
        )
    content = re.sub(
        r"\\documentclass(?:\[[^\]]*\])?\{[^{}]+\}",
        r"\\documentclass[11pt]{article}",
        content,
        count=1,
    )
    had_nips_style = bool(
        re.search(
            r"^\\usepackage(?:\[[^\]]*\])?\{nips_2017\}\s*$", content, flags=re.M
        )
    )
    content = re.sub(
        r"^\\usepackage(?:\[[^\]]*\])?\{nips_2017\}\s*$", "", content, flags=re.M
    )
    content = re.sub(
        r"^\\usepackage(?:\[[^\]]*\])?\{(?:graphicx|subfiles)\}\s*$",
        "",
        content,
        flags=re.M,
    )
    content = GRAPHICSPATH.sub("", content)
    begin = content.find(r"\begin{document}")
    if begin < 0 or r"\end{document}" not in content:
        raise SeedError("expanded source must contain one complete document")
    preamble = content[:begin]
    additions: list[str] = []
    if "{geometry}" not in preamble:
        additions.append(r"\usepackage[margin=1in]{geometry}")
    if "{natbib}" not in preamble:
        additions.append(r"\usepackage[numbers,sort&compress]{natbib}")
    if had_nips_style:
        additions.extend(
            [
                r"\providecommand{\AND}{\\}",
                r"\providecommand{\And}{\\}",
            ]
        )
    if additions:
        content = content[:begin] + "\n".join(additions) + "\n" + content[begin:]

    visuals: list[dict[str, str]] = []

    def replace_media(match: re.Match[str]) -> str:
        index = len(visuals) + 1
        record = {
            "id": f"visual-{index:04d}",
            "command": match.group("command"),
            "path": " ".join(match.group("path").split()),
        }
        visuals.append(record)
        return (
            f"% QLPAPER_VISUAL_REQUIRED: id={record['id']}; "
            f"source={record['path']}\n"
            r"\par\noindent\textbf{Visual description pending.}"
        )

    content = MEDIA_COMMAND.sub(replace_media, content)
    return content, visuals


def tex_tokens(content: str) -> tuple[list[str], list[int]]:
    tokens: list[str] = []
    lines: list[int] = []
    for line_number, raw in enumerate(content.splitlines(), start=1):
        line = COMMENT.sub("", raw)
        line = COMMAND.sub(" ", line)
        for match in TOKEN.finditer(line):
            tokens.append(match.group(0).casefold())
            lines.append(line_number)
    return tokens, lines


def text_tokens(path: Path) -> list[str]:
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        raise SeedError(f"cannot read page text {path}: {error}") from error
    return [match.group(0).casefold() for match in TOKEN.finditer(content)]


def ngram_positions(tokens: list[str], size: int) -> dict[tuple[str, ...], list[int]]:
    positions: dict[tuple[str, ...], list[int]] = defaultdict(list)
    for index in range(0, len(tokens) - size + 1):
        positions[tuple(tokens[index : index + size])].append(index)
    return positions


def locate_pages(
    content: str, manifest: dict[str, Any], manifest_dir: Path
) -> tuple[str, list[dict[str, Any]]]:
    tokens, token_lines = tex_tokens(content)
    indexes = {size: ngram_positions(tokens, size) for size in (14, 12, 10, 8, 6)}
    visual_figure_lines: list[int] = []
    current_figure: int | None = None
    for line_number, line in enumerate(content.splitlines(), start=1):
        if re.search(r"\\begin\{figure\*?\}", line):
            current_figure = line_number
        if "QLPAPER_VISUAL_REQUIRED" in line and current_figure is not None:
            if not visual_figure_lines or visual_figure_lines[-1] != current_figure:
                visual_figure_lines.append(current_figure)
        if re.search(r"\\end\{figure\*?\}", line):
            current_figure = None
    records = manifest.get("pages")
    if not isinstance(records, list):
        raise SeedError("manifest pages must be a list")
    page_count = manifest.get("page_count")
    if not isinstance(page_count, int) or page_count < 1:
        raise SeedError("manifest page_count must be a positive integer")

    locations: list[dict[str, Any]] = []
    previous_token = -1
    previous_line = 0
    begin_document_line = content[: content.find(r"\begin{document}")].count("\n") + 2
    for page in range(1, page_count + 1):
        record = next(
            (
                item
                for item in records
                if isinstance(item, dict) and item.get("page") == page
            ),
            None,
        )
        if record is None:
            raise SeedError(f"manifest has no page record for page {page}")
        page_path = manifest_dir / str(record.get("text_path", ""))
        page_words = text_tokens(page_path)
        match: tuple[int, int, int] | None = None
        for size in (14, 12, 10, 8, 6):
            if len(page_words) < size:
                continue
            candidates: list[tuple[int, int]] = []
            for window in range(0, min(len(page_words) - size + 1, 240)):
                phrase = tuple(page_words[window : window + size])
                for position in indexes[size].get(phrase, []):
                    if position > previous_token:
                        candidates.append((window, position))
                if candidates and window >= 40:
                    break
            if candidates:
                window, position = min(candidates, key=lambda item: (item[0], item[1]))
                match = (size, window, position)
                break
        alignment = "text-ngram"
        if match is None:
            fallback = next(
                (line for line in visual_figure_lines if line > previous_line), None
            )
            if fallback is None:
                raise SeedError(f"could not align PDF page {page} to the expanded TeX")
            line = fallback
            position = next(
                (
                    index
                    for index, token_line in enumerate(token_lines)
                    if token_line >= line and index > previous_token
                ),
                previous_token + 1,
            )
            size, window = 0, -1
            alignment = "visual-object-order"
        else:
            size, window, position = match
            line = token_lines[position]
        if page == 1:
            line = max(line, begin_document_line)
        locations.append(
            {
                "page": page,
                "line": line,
                "ngram_tokens": size,
                "page_token_offset": window,
                "alignment": alignment,
                "needs_review": alignment != "text-ngram" or size < 8 or window > 80,
            }
        )
        previous_token = position
        previous_line = line

    insertions: dict[int, list[str]] = defaultdict(list)
    for location in locations:
        if location["needs_review"]:
            insertions[location["line"]].append(
                f"% QLPAPER_PAGE_LOCATION_REVIEW: page={location['page']}"
            )
        insertions[location["line"]].append(
            f"% qlpaper-source: page={location['page']}"
        )
    lines = content.splitlines()
    output: list[str] = []
    for line_number, line in enumerate(lines, start=1):
        output.extend(insertions.get(line_number, []))
        output.append(line)
    output.extend(insertions.get(len(lines) + 1, []))
    return "\n".join(output).rstrip() + "\n", locations


def main() -> int:
    args = parse_args()
    source = args.source.expanduser().resolve()
    manifest_path = args.manifest.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if output.exists() and not args.force:
        raise SystemExit(f"seed_source_tex: output exists; pass --force: {output}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        source_content = source.read_text(encoding="utf-8")
        digest = str(manifest["source_sha256"])
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise SeedError("manifest source_sha256 is invalid")
        cleaned, visuals = clean_source(source_content)
        marked, locations = locate_pages(cleaned, manifest, manifest_path.parent)
    except (OSError, KeyError, json.JSONDecodeError, SeedError) as error:
        print(f"seed_source_tex: {error}", file=sys.stderr)
        return 1
    header = f"% qlpaper-normalized-v1\n% qlpaper-source-sha256: {digest}\n"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(header + marked, encoding="utf-8")
    result = {
        "schema": "qlpaper-source-tex-seed-v1",
        "output": str(output),
        "pages_aligned": len(locations),
        "page_locations_needing_review": [
            item["page"] for item in locations if item["needs_review"]
        ],
        "visuals_requiring_description": visuals,
    }
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
