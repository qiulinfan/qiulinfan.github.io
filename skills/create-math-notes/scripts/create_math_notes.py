#!/usr/bin/env python3
"""Create a QLNotes Typst-first mathematics course without copying toolchain code."""

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
    "main.typ.tmpl": "main.typ",
    "chapter.typ.tmpl": "chapters/01-introduction.typ",
    "Makefile.tmpl": "Makefile",
    "workspace.code-workspace.tmpl": "{slug}.code-workspace",
    "README.md.tmpl": "README.md",
    "reference.bib.tmpl": "reference.bib",
    "gitattributes.tmpl": ".gitattributes",
}


class CreateError(RuntimeError):
    """Raised when a course cannot be created safely."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("slug", help="lowercase hyphenated directory/course ID")
    parser.add_argument("--title", help="human-facing note title")
    parser.add_argument("--course", help="course code or display label")
    parser.add_argument("--author", default="Qiulin Fan")
    parser.add_argument("--date", default=str(date.today().year))
    parser.add_argument("--description")
    parser.add_argument("--keyword", action="append", dest="keywords")
    parser.add_argument("--first-chapter", default="Introduction")
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--open", action="store_true", dest="open_vscode")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def typst_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def render(template: str, values: dict[str, str]) -> str:
    for key, value in values.items():
        template = template.replace("{{" + key + "}}", value)
    unresolved = sorted(set(re.findall(r"\{\{[A-Z_]+\}\}", template)))
    if unresolved:
        raise CreateError(f"unresolved template values: {unresolved}")
    return template


def validate_repo(repo: Path) -> None:
    required = (
        repo / "notes/math/toolchain/qlnotes.typ",
        repo / "notes/math/toolchain/math-aliases.typ",
        repo / "notes/math/toolchain/scripts/export_course.py",
        repo / "skills/export-typst-math-notes/scripts/check_web.py",
        repo / "knowledge/scripts/knowledge.py",
        repo / "knowledge/sources.json",
    )
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise CreateError("not a complete knowledge-site checkout; missing: " + ", ".join(missing))


def canonical_site_root(registry: Path) -> str:
    data = json.loads(registry.read_text(encoding="utf-8"))
    for source in data.get("sources", []):
        web = str(source.get("web", "")).rstrip("/")
        marker = "/notes/"
        if marker in web:
            return web.split(marker, 1)[0]
    raise CreateError("cannot derive the canonical site root from knowledge/sources.json")


def new_source(slug: str, site_root: str) -> dict[str, object]:
    return {
        "id": f"math:{slug}",
        "subject": "math",
        "course": slug,
        "root": f"notes/math/{slug}",
        "files": ["main.typ", "chapters/*.typ"],
        "web": f"{site_root}/notes/math/{slug}",
        "topics": [],
    }


def load_registry(path: Path, source: dict[str, object]) -> tuple[dict[str, object], str]:
    text = path.read_text(encoding="utf-8")
    data = json.loads(text)
    if data.get("schema") != "qlkg-sources-v2" or not isinstance(data.get("sources"), list):
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

    descriptor, temporary = tempfile.mkstemp(prefix="sources.", suffix=".json", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(updated)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def create_course(args: argparse.Namespace) -> tuple[Path, Path]:
    if not SLUG_RE.fullmatch(args.slug) or args.slug == "toolchain":
        raise CreateError("slug must be lowercase hyphen-case and cannot be 'toolchain'")

    repo = (args.repo_root or Path(__file__).resolve().parents[3]).resolve()
    validate_repo(repo)
    destination = repo / "notes/math" / args.slug
    if destination.exists():
        raise CreateError(f"destination already exists: {destination}")

    title = args.title or args.slug.replace("-", " ").title()
    course = args.course or title
    description = args.description or f"Typst-first notes for {title}."
    keywords = args.keywords or [title]
    keyword_tuple = "(" + ", ".join(typst_string(item) for item in keywords) + ",)"
    values = {
        "SLUG": args.slug,
        "TITLE": typst_string(title),
        "TITLE_TEXT": title,
        "COURSE": typst_string(course),
        "AUTHOR": typst_string(args.author),
        "DATE": typst_string(args.date),
        "DESCRIPTION": typst_string(description),
        "KEYWORDS": keyword_tuple,
        "FIRST_CHAPTER": args.first_chapter,
    }

    registry = repo / "knowledge/sources.json"
    source = new_source(args.slug, canonical_site_root(registry))
    _, original_registry = load_registry(registry, source)
    workspace = destination / f"{args.slug}.code-workspace"
    if args.dry_run:
        print(f"would create: {destination}")
        print(f"would register: {source['id']}")
        print(f"would publish: {source['web']}")
        return destination, workspace

    templates = Path(__file__).resolve().parents[1] / "assets/course"
    staging = Path(tempfile.mkdtemp(prefix=f".{args.slug}-", dir=destination.parent))
    try:
        (staging / "chapters").mkdir()
        (staging / "assets").mkdir()
        for template_name, output_pattern in TEMPLATE_FILES.items():
            template_path = templates / template_name
            if not template_path.is_file():
                raise CreateError(f"missing skill asset: {template_path}")
            output_name = output_pattern.format(slug=args.slug)
            output_path = staging / output_name
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(render(template_path.read_text(encoding="utf-8"), values), encoding="utf-8")
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
        destination, workspace = create_course(args)
        if args.open_vscode and not args.dry_run:
            code = shutil.which("code")
            if code is None:
                raise CreateError("course created, but the 'code' command is unavailable")
            subprocess.run([code, "-r", str(workspace), str(destination / "main.typ")], check=True)
    except (CreateError, OSError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print(f"create-math-notes failed: {error}", file=sys.stderr)
        return 1

    print(f"created: {destination}")
    if not args.dry_run:
        print(f"workspace: {workspace}")
        print(f"validate: make -C {destination} export && make -C {destination} web-check")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
