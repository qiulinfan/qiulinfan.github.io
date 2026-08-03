# Upstream baseline

- Repository: <https://github.com/qiulinfan/localLatexenv>
- Inspected commit: `f62053086eec079f6c7db99eac23d9c66e28b63f`
- Vendored file: the repository's customized `elegantbook.cls`

Preserve LuaLaTeX, ElegantBook, `main.tex` plus `chapters/`, LaTeX Workshop's
`latexmk` recipe, build-directory isolation, automatic PDF refresh, and
SyncTeX. Exclude `docs/`, `site/`, `mkdocs.yml`, documentation-page generators,
`mkdocs build`, `gh-deploy`, and chapter-PDF publishing. Refresh the vendored
class only after reviewing the upstream diff and compiling the smoke fixture.

