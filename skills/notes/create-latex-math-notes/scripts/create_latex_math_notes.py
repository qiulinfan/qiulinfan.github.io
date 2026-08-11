#!/usr/bin/env python3
"""Create a LaTeX-authored math-notes project with Typst HTML preview."""

from __future__ import annotations

import argparse
import json
import os
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


def canonical_site_root(registry: Path) -> str:
    data = json.loads(registry.read_text(encoding="utf-8"))
    for source in data.get("sources", []):
        web = str(source.get("web", "")).rstrip("/")
        if "/notes/" in web:
            return web.split("/notes/", 1)[0]
    raise CreateError("cannot derive the canonical site root from knowledge/sources.json")


def new_source(slug: str, title: str, site_root: str) -> dict[str, object]:
    return {
        "id": f"math:{slug}",
        "title": title,
        "description": f"LaTeX-authored notes for {title}.",
        "subject": "math",
        "course": slug,
        "knowledge_origin": "personal-note",
        "fields": [],
        "root": f"notes/math/{slug}",
        "files": ["main.tex", "chapters/*.tex"],
        "publish": False,
        "listed": False,
        "web": f"{site_root}/notes/math/{slug}",
        "topics": [],
    }


def load_registry(
    path: Path, source: dict[str, object]
) -> tuple[dict[str, object], str]:
    text = path.read_text(encoding="utf-8")
    data = json.loads(text)
    if data.get("schema") != "qlkg-sources-v2" or not isinstance(
        data.get("sources"), list
    ):
        raise CreateError(f"unsupported knowledge registry: {path}")
    for existing in data["sources"]:
        if any(existing.get(key) == source[key] for key in ("id", "course", "root")):
            raise CreateError(f"knowledge source already exists: {existing.get('id')}")
    return data, text


def append_registry(path: Path, original: str, source: dict[str, object]) -> None:
    marker = "\n  ]\n}"
    if not original.endswith(marker + "\n") and not original.endswith(marker):
        raise CreateError("knowledge/sources.json has an unexpected layout")
    end_newline = "\n" if original.endswith("\n") else ""
    body = original[: -len(marker) - len(end_newline)]
    separator = ",\n" if json.loads(original)["sources"] else "\n"
    serialized = json.dumps(source, ensure_ascii=False, indent=2)
    indented = "\n".join("    " + line for line in serialized.splitlines())
    updated = body + separator + indented + marker + end_newline
    json.loads(updated)

    descriptor, temporary = tempfile.mkstemp(
        prefix="sources.", suffix=".json", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(updated)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


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
    registry = repo / "knowledge/sources.json"
    if not registry.is_file():
        raise CreateError(f"missing knowledge source registry: {registry}")
    source = new_source(args.slug, title, canonical_site_root(registry))
    _, original_registry = load_registry(registry, source)
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
        print(f"would register: {source['id']} (unpublished)")
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
        append_registry(registry, original_registry, source)
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        if destination.exists() and registry.read_text(encoding="utf-8") == original_registry:
            shutil.rmtree(destination)
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
