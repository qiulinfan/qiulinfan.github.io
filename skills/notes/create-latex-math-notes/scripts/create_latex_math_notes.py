#!/usr/bin/env python3
"""Create a standalone LuaLaTeX mathematics-notes project."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path


SLUG_RE = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
TEMPLATE_ROOT = Path(__file__).resolve().parents[1] / "assets/course"
TEMPLATE_FILES = {
    "main.tex.tmpl": "main.tex",
    "chapter.tex.tmpl": "chapters/01-introduction.tex",
    "qlmathnotes.sty.tmpl": "qlmathnotes.sty",
    "Makefile.tmpl": "Makefile",
    "workspace.code-workspace.tmpl": "{slug}.code-workspace",
    "settings.json.tmpl": ".vscode/settings.json",
    "extensions.json.tmpl": ".vscode/extensions.json",
    "tasks.json.tmpl": ".vscode/tasks.json",
    "README.md.tmpl": "README.md",
    "reference.bib.tmpl": "reference.bib",
    "gitignore.tmpl": ".gitignore",
    "gitattributes.tmpl": ".gitattributes",
}


class CreateError(RuntimeError):
    """Raised when a project cannot be created safely."""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("slug", help="lowercase hyphenated directory name")
    parser.add_argument("--title", help="human-facing document title")
    parser.add_argument("--subtitle")
    parser.add_argument("--author", default="Qiulin Fan")
    parser.add_argument("--date", default=str(date.today().year))
    parser.add_argument("--first-chapter", default="Introduction")
    parser.add_argument(
        "--destination-root",
        type=Path,
        default=Path.cwd(),
        help="existing parent directory for the new project (default: cwd)",
    )
    parser.add_argument("--open", action="store_true", dest="open_vscode")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def latex_text(value: str) -> str:
    replacements = {
        "\\": r"\textbackslash{}",
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
        "~": r"\textasciitilde{}",
        "^": r"\textasciicircum{}",
    }
    return "".join(replacements.get(character, character) for character in value)


def render(template: str, values: dict[str, str]) -> str:
    for key, value in values.items():
        template = template.replace("{{" + key + "}}", value)
    unresolved = sorted(set(re.findall(r"\{\{[A-Z_]+\}\}", template)))
    if unresolved:
        raise CreateError(f"unresolved template values: {unresolved}")
    return template


def validate_templates() -> None:
    missing = [
        str(TEMPLATE_ROOT / template_name)
        for template_name in TEMPLATE_FILES
        if not (TEMPLATE_ROOT / template_name).is_file()
    ]
    if missing:
        raise CreateError(f"missing skill assets: {', '.join(missing)}")


def create_project(args: argparse.Namespace) -> tuple[Path, Path]:
    if not SLUG_RE.fullmatch(args.slug):
        raise CreateError("slug must be lowercase hyphen-case")

    destination_root = args.destination_root.expanduser().resolve()
    if not destination_root.is_dir():
        raise CreateError(f"destination root is not a directory: {destination_root}")

    destination = destination_root / args.slug
    if destination.exists():
        raise CreateError(f"destination already exists: {destination}")

    validate_templates()
    title = args.title or args.slug.replace("-", " ").title()
    title_suffix = (
        r"\\[0.8em]{\large " + latex_text(args.subtitle) + "}"
        if args.subtitle
        else ""
    )
    values = {
        "SLUG": args.slug,
        "TITLE": latex_text(title),
        "TITLE_TEXT": title,
        "TITLE_JSON": json.dumps(title, ensure_ascii=False),
        "TITLE_SUFFIX": title_suffix,
        "AUTHOR": latex_text(args.author),
        "DATE": latex_text(args.date),
        "FIRST_CHAPTER": latex_text(args.first_chapter),
    }
    rendered_files = {
        output_pattern.format(slug=args.slug): render(
            (TEMPLATE_ROOT / template_name).read_text(encoding="utf-8"),
            values,
        )
        for template_name, output_pattern in TEMPLATE_FILES.items()
    }
    workspace = destination / f"{args.slug}.code-workspace"
    if args.dry_run:
        return destination, workspace

    staging = Path(
        tempfile.mkdtemp(prefix=f".{args.slug}-", dir=destination_root)
    )
    try:
        (staging / "assets").mkdir()
        for relative_path, content in rendered_files.items():
            output_path = staging / relative_path
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(content, encoding="utf-8")

        # Keep the final path invisible until every project-local file is ready.
        if destination.exists():
            raise CreateError(f"destination appeared during creation: {destination}")
        staging.rename(destination)
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise

    return destination, workspace


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        destination, workspace = create_project(args)
        if args.open_vscode and not args.dry_run:
            code = shutil.which("code")
            if code is None:
                raise CreateError("project created, but the 'code' command is unavailable")
            subprocess.run(
                [code, "-r", str(workspace), str(destination / "main.tex")],
                check=True,
            )
    except (CreateError, OSError, subprocess.CalledProcessError) as error:
        print(f"create-latex-math-notes failed: {error}", file=sys.stderr)
        return 1

    if args.dry_run:
        print(f"would create: {destination}")
        print(f"would open: {workspace}" if args.open_vscode else "open: disabled")
        return 0

    print(f"created: {destination}")
    print(f"workspace: {workspace}")
    print(
        "build: latexmk -lualatex -synctex=1 -interaction=nonstopmode "
        f"-halt-on-error -file-line-error -outdir=build/latex {destination / 'main.tex'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
