from __future__ import annotations

import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


TOOLCHAIN = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOLCHAIN.parents[2]
MODULE_PATH = TOOLCHAIN / "scripts/migrate_latex.py"
sys.path.insert(0, str(MODULE_PATH.parent))
SPEC = importlib.util.spec_from_file_location("qlnotes_migrate_latex", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
migrate_latex = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = migrate_latex
SPEC.loader.exec_module(migrate_latex)
WEB_MODULE_PATH = TOOLCHAIN / "scripts/export_latex_web.py"
WEB_SPEC = importlib.util.spec_from_file_location("qlnotes_export_latex_web", WEB_MODULE_PATH)
assert WEB_SPEC is not None and WEB_SPEC.loader is not None
export_latex_web = importlib.util.module_from_spec(WEB_SPEC)
sys.modules[WEB_SPEC.name] = export_latex_web
WEB_SPEC.loader.exec_module(export_latex_web)


class MultiSourceExportTest(unittest.TestCase):
    def test_starter_and_export_elegantbook_surfaces_are_synchronized(self) -> None:
        export_class = (TOOLCHAIN / "latex/elegantbook.cls").read_text(encoding="utf-8")
        starter_class = (
            REPO_ROOT / "skills/create-latex-math-notes/assets/course/elegantbook.cls"
        ).read_text(encoding="utf-8")

        self.assertEqual("".join(export_class.split()), "".join(starter_class.split()))

    def test_latex_markers_are_rewritten_without_losing_nested_markup(self) -> None:
        source = r"\kn{$L^p$ \textbf{space}} and \knref{$L^p$ \textbf{space}}"
        rewritten, count = migrate_latex.rewrite_knowledge_macros(source)

        self.assertEqual(2, count)
        self.assertIn(r"\href{qlkn:}{$L^p$ \textbf{space}}", rewritten)
        self.assertIn(r"\href{qlknref:}{$L^p$ \textbf{space}}", rewritten)

    @unittest.skipUnless(shutil.which("pandoc"), "Pandoc is required for the integration fixture")
    def test_latex_markers_survive_tex_to_typst(self) -> None:
        fixture = Path(__file__).parent / "fixtures/knowledge.tex"
        with tempfile.TemporaryDirectory(prefix="qlnotes-latex-test-") as temporary:
            root = Path(temporary)
            output = root / "typst"
            migrate_latex.migrate(
                [fixture],
                output,
                root / "diagrams",
                None,
            )
            rendered = (output / "knowledge.typ").read_text(encoding="utf-8")

        self.assertIn("#kn[measure space]", rendered)
        self.assertIn("#ref[measure space]", rendered)

    @unittest.skipUnless(
        shutil.which("pandoc") and shutil.which("typst"),
        "Pandoc and Typst are required for the web integration fixture",
    )
    def test_latex_source_compiles_to_qlnotes_html_through_typst(self) -> None:
        fixture = Path(__file__).parent / "fixtures/knowledge.tex"
        build_parent = REPO_ROOT / "knowledge/build"
        build_parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="qlnotes-latex-web-", dir=build_parent) as temporary:
            root = Path(temporary)
            output = root / "index.html"
            export_latex_web.export_latex_web(
                [fixture],
                REPO_ROOT,
                root / "typst",
                output,
                title="LaTeX Knowledge Fixture",
                course="Demo",
                author="Test",
                sync_graph=False,
            )
            rendered = output.read_text(encoding="utf-8")

        self.assertIn("ql-site", rendered)
        self.assertIn("LaTeX Knowledge Fixture", rendered)
        self.assertIn('data-ql-kn="measure-space"', rendered)
        self.assertIn('id="kn-measure-space"', rendered)
        self.assertIn('data-ql-ref="measure-space"', rendered)
        self.assertIn(
			'href="https://qiulinfan.github.io/notes/math/measure-theory/#kn-measure-space"',
            rendered,
        )

    @unittest.skipUnless(
        shutil.which("lualatex"),
        "LuaLaTeX is required for the source preview fixture",
    )
    def test_elegantbook_source_preview_supports_knowledge_macros(self) -> None:
        fixture_root = Path(__file__).parent / "fixtures/latex-project"
        build_parent = REPO_ROOT / "knowledge/build"
        build_parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="qlnotes-latex-source-", dir=build_parent) as temporary:
            result = subprocess.run(
                [
                    "lualatex",
                    "-interaction=nonstopmode",
                    "-halt-on-error",
                    f"-output-directory={temporary}",
                    "main.tex",
                ],
                cwd=fixture_root,
                env={
                    **os.environ,
                    "TEXINPUTS": f"{TOOLCHAIN / 'latex'}:",
                },
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(0, result.returncode, result.stdout[-4000:] + result.stderr)
            self.assertTrue((Path(temporary) / "main.pdf").is_file())

    @unittest.skipUnless(
        shutil.which("pandoc") and shutil.which("typst"),
        "Pandoc and Typst are required for the project integration fixture",
    )
    def test_elegantbook_entrypoint_becomes_self_contained_previewable_typst(self) -> None:
        fixture = Path(__file__).parent / "fixtures/latex-project/main.tex"
        build_parent = REPO_ROOT / "knowledge/build"
        build_parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="qlnotes-latex-project-", dir=build_parent) as temporary:
            root = Path(temporary)
            project = export_latex_web.inspect_project([fixture])
            main = export_latex_web.convert_latex_project(project, root / "typst")
            preview = root / "typst/preview.pdf"
            result = subprocess.run(
                ["typst", "compile", "--root", str(root / "typst"), str(main), str(preview)],
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertTrue(preview.is_file())
            self.assertTrue((root / "typst/Makefile").is_file())
            self.assertTrue((root / "typst/toolchain/qlnotes.typ").is_file())
            rendered_main = main.read_text(encoding="utf-8")

        self.assertIn('title: "Measure Preview"', rendered_main)
        self.assertIn('#include "chapters/01-measure.typ"', rendered_main)

    @unittest.skipUnless(
        shutil.which("pandoc") and shutil.which("typst"),
        "Pandoc and Typst are required for the web integration fixture",
    )
    def test_latex_web_export_rejects_unregistered_markers(self) -> None:
        build_parent = REPO_ROOT / "knowledge/build"
        build_parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="qlnotes-latex-unregistered-", dir=build_parent) as temporary:
            root = Path(temporary)
            source = root / "unknown.tex"
            source.write_text("\\kn{fixture concept that is not registered}\n", encoding="utf-8")
            with self.assertRaisesRegex(export_latex_web.LatexWebError, "did not resolve"):
                export_latex_web.export_latex_web(
                    [source],
                    REPO_ROOT,
                    root / "typst",
                    root / "index.html",
                    title="Unregistered",
                    course=None,
                    author=None,
                    sync_graph=False,
                )


if __name__ == "__main__":
    unittest.main()
