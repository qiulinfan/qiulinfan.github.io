#!/usr/bin/env python3
"""Tests for the standalone LaTeX mathematics-notes scaffolder."""

from __future__ import annotations

import base64
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import create_latex_math_notes as scaffold


SCRIPT = Path(scaffold.__file__).resolve()
EXPECTED_FILES = {
    ".gitattributes",
    ".gitignore",
    ".vscode/extensions.json",
    ".vscode/settings.json",
    ".vscode/tasks.json",
    "Makefile",
    "README.md",
    "chapters/01-introduction.tex",
    "main.tex",
    "qlmathnotes.sty",
    "reference.bib",
    "standalone-notes.code-workspace",
}
JSON_FILES = {
    ".vscode/extensions.json",
    ".vscode/settings.json",
    ".vscode/tasks.json",
    "standalone-notes.code-workspace",
}
FORBIDDEN_OUTPUT_TERMS = (
    "qlblog",
    "notes/math/toolchain",
    "knowledge/sources.json",
    "shared",
    "vendor",
    "mkdocs",
    "typst",
    "gh-deploy",
    "iframe",
)


def options(root: Path, **overrides: object) -> SimpleNamespace:
    values: dict[str, object] = {
        "slug": "standalone-notes",
        "title": "Standalone Notes",
        "subtitle": None,
        "author": "Test Author",
        "date": "2026",
        "first_chapter": "Introduction",
        "destination_root": root,
        "open_vscode": False,
        "dry_run": False,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def run_cli(root: Path, *arguments: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(SCRIPT), *arguments],
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
    )


class CreateLatexMathNotesTests(unittest.TestCase):
    def test_dry_run_has_no_filesystem_side_effects(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            completed = run_cli(
                root,
                "dry-run-notes",
                "--destination-root",
                str(root),
                "--dry-run",
            )

            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertIn(
                f"would create: {root.resolve() / 'dry-run-notes'}",
                completed.stdout,
            )
            self.assertFalse((root / "dry-run-notes").exists())
            self.assertEqual(list(root.iterdir()), [])

    def test_default_destination_is_current_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            completed = run_cli(root, "default-root", cwd=root)

            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertTrue((root / "default-root/main.tex").is_file())

    def test_create_is_atomic_when_rendering_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            original_render = scaffold.render
            calls = 0

            def failing_render(template: str, values: dict[str, str]) -> str:
                nonlocal calls
                calls += 1
                if calls == 3:
                    raise scaffold.CreateError("injected render failure")
                return original_render(template, values)

            with mock.patch.object(scaffold, "render", side_effect=failing_render):
                with self.assertRaisesRegex(scaffold.CreateError, "injected"):
                    scaffold.create_project(options(root))

            self.assertFalse((root / "standalone-notes").exists())
            self.assertEqual(list(root.glob(".standalone-notes-*")), [])

    def test_existing_destination_is_never_overwritten(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = run_cli(
                root,
                "standalone-notes",
                "--destination-root",
                str(root),
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            marker = root / "standalone-notes/main.tex"
            marker.write_text("owned by the first creation\n", encoding="utf-8")

            second = run_cli(
                root,
                "standalone-notes",
                "--destination-root",
                str(root),
            )
            self.assertNotEqual(second.returncode, 0)
            self.assertIn("destination already exists", second.stderr)
            self.assertEqual(
                marker.read_text(encoding="utf-8"),
                "owned by the first creation\n",
            )

    def test_generated_project_has_only_expected_files_and_valid_json(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination, _ = scaffold.create_project(options(root))
            actual_files = {
                path.relative_to(destination).as_posix()
                for path in destination.rglob("*")
                if path.is_file()
            }

            self.assertEqual(actual_files, EXPECTED_FILES)
            self.assertTrue((destination / "assets").is_dir())
            for relative in JSON_FILES:
                parsed = json.loads((destination / relative).read_text(encoding="utf-8"))
                self.assertIsInstance(parsed, dict)

            settings = json.loads(
                (destination / ".vscode/settings.json").read_text(encoding="utf-8")
            )
            self.assertEqual(settings["latex-workshop.latex.outDir"], "build/latex")
            self.assertEqual(settings["latex-workshop.latex.auxDir"], "%OUTDIR%")
            self.assertEqual(settings["latex-workshop.latex.autoBuild.run"], "onSave")
            self.assertTrue(settings["latex-workshop.message.error.show"])
            self.assertTrue(settings["latex-workshop.message.warning.show"])
            tool = settings["latex-workshop.latex.tools"][0]
            self.assertEqual(tool["command"], "latexmk")
            self.assertIn("-lualatex", tool["args"])
            self.assertIn("-outdir=%OUTDIR%", tool["args"])
            self.assertIn("-auxdir=%AUXDIR%", tool["args"])
            self.assertIn("%DOC%", tool["args"])
            self.assertNotIn("latex-workshop.view.pdf.refresh.viewer", settings)
            self.assertNotIn("editor.wordBasedSuggestionsMode", settings["[latex]"])

            extensions = json.loads(
                (destination / ".vscode/extensions.json").read_text(encoding="utf-8")
            )
            self.assertEqual(
                extensions["recommendations"],
                ["james-yu.latex-workshop", "yfzhao.ultra-math-preview"],
            )
            style = (destination / "qlmathnotes.sty").read_text(encoding="utf-8")
            self.assertIn("Copyright 2026 Qiulin Fan", style)
            self.assertIn("LaTeX Project Public License", style)
            self.assertIn("ElegantLaTeX/ElegantBook", style)
            self.assertNotIn(r"\newcommand{\insertpic}", style)
            self.assertNotIn(r"\newcommand{\pic}", style)

    def test_generated_project_has_no_external_pipeline_references(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination, _ = scaffold.create_project(options(Path(temporary)))
            corpus = "\n".join(
                path.read_text(encoding="utf-8", errors="strict")
                for path in destination.rglob("*")
                if path.is_file()
            ).casefold()

            for term in FORBIDDEN_OUTPUT_TERMS:
                self.assertNotIn(term.casefold(), corpus)

    def test_core_editor_tasks_are_cross_platform(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination, _ = scaffold.create_project(options(Path(temporary)))
            tasks = json.loads(
                (destination / ".vscode/tasks.json").read_text(encoding="utf-8")
            )["tasks"]

            self.assertEqual(
                [task["command"] for task in tasks],
                ["latexmk", "latexmk"],
            )
            self.assertNotIn(
                "make",
                json.dumps(tasks, ensure_ascii=False).casefold(),
            )
            self.assertNotIn(
                "python",
                json.dumps(tasks, ensure_ascii=False).casefold(),
            )

    @unittest.skipUnless(
        all(shutil.which(command) for command in ("lualatex", "latexmk", "kpsewhich")),
        "a local LuaLaTeX toolchain is unavailable",
    )
    def test_generated_project_build_and_clean(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination, _ = scaffold.create_project(options(Path(temporary)))
            (destination / "assets/pixel.png").write_bytes(
                base64.b64decode(
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
                    "+A8AAQUBAScY42YAAAAASUVORK5CYII="
                )
            )
            chapter = destination / "chapters/01-introduction.tex"
            chapter.write_text(
                chapter.read_text(encoding="utf-8")
                + r"""

\begin{lemma}A lemma.\end{lemma}
\begin{proposition}A proposition.\end{proposition}
\begin{corollary}A corollary.\end{corollary}
\begin{example}An example.\end{example}
\begin{solution}A solution.\end{solution}
\begin{remark}A remark.\end{remark}
\begin{note}A note.\end{note}
\begin{problem}A problem.\end{problem}
\begin{exercise}An exercise.\end{exercise}

\begin{python}
def square(x):
    return x * x
\end{python}
\begin{cpp}
int main() { return 0; }
\end{cpp}
\begin{terminal}
$ latexmk -lualatex -outdir=build/latex main.tex
\end{terminal}
\begin{txt}
plain text
\end{txt}

\begin{figure}[htbp]
  \centering
  \includegraphics[width=1cm]{pixel.png}
  \caption{A test pixel}
  \label{fig:pixel}
\end{figure}
""",
                encoding="utf-8",
            )

            build = subprocess.run(
                [
                    "latexmk",
                    "-lualatex",
                    "-synctex=1",
                    "-interaction=nonstopmode",
                    "-halt-on-error",
                    "-file-line-error",
                    "-outdir=build/latex",
                    "main.tex",
                ],
                cwd=destination,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(
                build.returncode,
                0,
                f"stdout:\n{build.stdout}\nstderr:\n{build.stderr}",
            )
            self.assertNotIn(
                "destination with the same identifier",
                build.stdout + build.stderr,
            )
            self.assertTrue((destination / "build/latex/main.pdf").is_file())

            clean = subprocess.run(
                ["latexmk", "-C", "-outdir=build/latex", "main.tex"],
                cwd=destination,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(clean.returncode, 0, clean.stderr)
            remaining_generated = [
                path
                for path in (destination / "build/latex").glob("*")
                if path.is_file()
            ]
            self.assertEqual(remaining_generated, [])

    @unittest.skipUnless(
        all(shutil.which(command) for command in ("lualatex", "latexmk", "kpsewhich")),
        "a local LuaLaTeX toolchain is unavailable",
    )
    def test_latex_build_errors_propagate(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination, _ = scaffold.create_project(options(Path(temporary)))
            chapter = destination / "chapters/01-introduction.tex"
            chapter.write_text(
                chapter.read_text(encoding="utf-8") + "\n\\undefinedcommand\n",
                encoding="utf-8",
            )
            build = subprocess.run(
                [
                    "latexmk",
                    "-lualatex",
                    "-synctex=1",
                    "-interaction=nonstopmode",
                    "-halt-on-error",
                    "-file-line-error",
                    "-outdir=build/latex",
                    "main.tex",
                ],
                cwd=destination,
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(build.returncode, 0)
            self.assertIn("undefinedcommand", build.stdout + build.stderr)


if __name__ == "__main__":
    unittest.main()
