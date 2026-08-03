# Upstream baseline

- Repository: <https://github.com/qiulinfan/localLatexenv>
- Inspected commit: `f62053086eec079f6c7db99eac23d9c66e28b63f`
- Vendored file: the repository's customized `elegantbook.cls`

Preserve LuaLaTeX, ElegantBook, `main.tex` plus `chapters/`, LaTeX Workshop's
`latexmk` recipe, build-directory isolation, automatic PDF refresh, and
SyncTeX. Exclude `docs/`, `site/`, `mkdocs.yml`, documentation-page generators,
`mkdocs build`, `gh-deploy`, and chapter-PDF publishing. Refresh the vendored
class only after reviewing the upstream diff and compiling the smoke fixture.

The repository's Typst adapter is synchronized with this starter surface. When
the LaTeX template gains a new environment, input convention, or semantic
macro, update `notes/math/toolchain/scripts/convert_latex_project.py`, the
Pandoc filter/migrator, and the Typst runtime in the same change. Add a fixture
that compiles the generated self-contained `main.typ`; unsupported template
surface must fail explicitly instead of disappearing during conversion.
