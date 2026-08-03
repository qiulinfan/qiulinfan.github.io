---
name: create-latex-math-notes
description: Create a new LuaLaTeX-first mathematics notes project under qlblog/notes/math using qiulinfan/localLatexenv as the synchronized template baseline. Use when the user asks to start, scaffold, initialize, or新建 LaTeX math notes with ElegantBook, chapter files, VS Code LaTeX Workshop auto-build, Ultra Math Preview, SyncTeX, local PDF rendering, and a self-contained Typst preview projection before later knowledge-graph and web export.
---

# Create LaTeX Math Notes

Create only mathematics notes. LaTeX remains the authored source and converts
through the synchronized ElegantBook adapter into a self-contained, previewable
Typst project. Do not add a Pages route until the source is registered and
semantically curated by `export-typst-math-notes`.

## Collect names

Obtain a lowercase hyphenated slug and human-facing title. Optional values are
subtitle, author, date, and first-chapter title. Never overwrite an existing
course directory.

## Create and open

From the qlblog repository root, run:

```sh
python3 skills/create-latex-math-notes/scripts/create_latex_math_notes.py \
  complex-analysis \
  --title "Complex Analysis" \
  --subtitle "Course notes" \
  --open
```

The script creates:

```text
notes/math/<slug>/
├── <slug>.code-workspace
├── .vscode/
│   ├── extensions.json
│   ├── settings.json
│   └── tasks.json
├── main.tex
├── chapters/01-introduction.tex
├── assets/
├── elegantbook.cls
├── reference.bib
└── Makefile
```

The workspace recommends LaTeX Workshop and Ultra Math Preview. Saving either
`main.tex` or a chapter recompiles the root with LuaLaTeX into ignored `build/`;
the chapter carries `% !TeX root = ../main.tex` for root discovery and SyncTeX.
The starter defines `\kn{canonical concept}` and `\knref{canonical concept}` so
graph markers remain valid, readable commands in the LuaLaTeX preview and map
to `#kn`/`#ref` in the synchronized Typst projection.

## Validate

Run only:

```sh
make -C notes/math/<slug> doctor
make -C notes/math/<slug> pdf
make -C notes/math/<slug> typst-preview
```

Successful compilation is sufficient. Do not render pages or inspect the PDF.
The Typst target creates ignored `build/typst/main.typ`, a local toolchain, and
a preview PDF. Never add MkDocs, `docs/`, direct LaTeX-to-HTML generation,
deployment commands, or root-level generated PDFs. For continuous terminal
compilation, use `make -C notes/math/<slug> watch` or `typst-watch`.

Read [references/upstream.md](references/upstream.md) only when refreshing the
vendored template from localLatexenv.
