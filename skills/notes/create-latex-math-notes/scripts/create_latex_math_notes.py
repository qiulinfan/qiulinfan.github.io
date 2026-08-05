#!/usr/bin/env python3
"""Create a LaTeX-authored math-notes project with Typst HTML preview."""

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
TEMPLATE_FILES = {
    "main.tex.tmpl": "main.tex",
    "chapter.tex.tmpl": "chapters/01-introduction.tex",
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("slug", help="lowercase hyphenated directory name")
    parser.add_argument("--title", help="human-facing document title")
    parser.add_argument("--subtitle")
    parser.add_argument("--author", default="Qiulin Fan")
    parser.add_argument("--date", default=str(date.today().year))
    parser.add_argument("--first-chapter", default="Introduction")
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--open", action="store_true", dest="open_vscode")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


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


def default_repo_root() -> Path:
    for candidate in Path(__file__).resolve().parents:
        if (candidate / "AGENTS.md").is_file() and (candidate / "notes/math").is_dir():
            return candidate
    raise CreateError("cannot locate the qlblog repository root")


def create_project(args: argparse.Namespace) -> tuple[Path, Path]:
    if not SLUG_RE.fullmatch(args.slug) or args.slug == "toolchain":
        raise CreateError("slug must be lowercase hyphen-case and cannot be 'toolchain'")

    repo = (args.repo_root or default_repo_root()).resolve()
    math_root = repo / "notes/math"
    if not math_root.is_dir():
        raise CreateError(f"missing qlblog mathematics root: {math_root}")

    destination = math_root / args.slug
    if destination.exists():
        raise CreateError(f"destination already exists: {destination}")

    title = args.title or args.slug.replace("-", " ").title()
    subtitle_line = (
        f"\\subtitle{{{latex_text(args.subtitle)}}}"
        if args.subtitle
        else "% \\subtitle{Optional subtitle}"
    )
    values = {
        "SLUG": args.slug,
        "TITLE": latex_text(title),
        "TITLE_TEXT": title,
        "TITLE_JSON": json.dumps(title, ensure_ascii=False),
        "SUBTITLE_LINE": subtitle_line,
        "AUTHOR": latex_text(args.author),
        "DATE": latex_text(args.date),
        "FIRST_CHAPTER": latex_text(args.first_chapter),
    }
    workspace = destination / f"{args.slug}.code-workspace"
    if args.dry_run:
        print(f"would create: {destination}")
        return destination, workspace

    templates = Path(__file__).resolve().parents[1] / "assets/course"
    class_file = templates / "elegantbook.cls"
    if not class_file.is_file():
        raise CreateError(f"missing vendored class: {class_file}")

    staging = Path(tempfile.mkdtemp(prefix=f".{args.slug}-", dir=math_root))
    try:
        (staging / "chapters").mkdir()
        (staging / "assets").mkdir()
        (staging / ".vscode").mkdir()
        for template_name, output_pattern in TEMPLATE_FILES.items():
            template_path = templates / template_name
            if not template_path.is_file():
                raise CreateError(f"missing skill asset: {template_path}")
            output_path = staging / output_pattern.format(slug=args.slug)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(
                render(template_path.read_text(encoding="utf-8"), values),
                encoding="utf-8",
            )
        shutil.copy2(class_file, staging / "elegantbook.cls")
        staging.rename(destination)
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise

    return destination, workspace


def main() -> int:
    args = parse_args()
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

    print(f"created: {destination}")
    if not args.dry_run:
        print(f"workspace: {workspace}")
        print(
            f"validate: make -C {destination} doctor && "
            f"make -C {destination} web"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
