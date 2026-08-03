---
name: create-latex-math-notes
description: Create a new LuaLaTeX-first mathematics notes project under qlblog/notes/math using qiulinfan/localLatexenv as the template baseline. Use when the user asks to start, scaffold, initialize, or新建 LaTeX math notes with ElegantBook, chapter files, VS Code LaTeX Workshop auto-build, Ultra Math Preview, SyncTeX, and local live PDF rendering, without MkDocs, HTML, GitHub Pages, or web-export logic.
---

# Create LaTeX Math Notes

Create only mathematics notes. Use this for a LaTeX authority that will later
be migrated to Typst. Do not register it in `knowledge/sources.json` and do not
add a Pages route before that migration.

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

## Validate

Run only:

```sh
make -C notes/math/<slug> doctor
make -C notes/math/<slug> pdf
```

Successful compilation is sufficient. Do not render pages or inspect the PDF.
Never add MkDocs, `docs/`, `site/`, HTML generation, deployment commands, or
root-level generated PDFs. For continuous terminal compilation, use
`make -C notes/math/<slug> watch`.

Read [references/upstream.md](references/upstream.md) only when refreshing the
vendored template from localLatexenv.

