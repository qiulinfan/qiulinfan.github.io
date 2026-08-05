---
name: create-latex-math-notes
description: Create a lightweight LaTeX-authored mathematics notes project under qlblog/notes/math using the synchronized ElegantBook syntax and the repository's LaTeX-to-Typst adapter. Use when the user asks to start, scaffold, initialize, or新建 `.tex` math notes that preview only as Typst HTML, retain `\kn`/`\knref` knowledge markers, and never add PDF, latexmk, SyncTeX, MkDocs, or committed build artifacts.
---

# Create LaTeX Math Notes

Create only mathematics notes. LaTeX remains the authored source and converts
through the synchronized ElegantBook adapter into a self-contained Typst HTML
preview. Do not compile LaTeX directly or add a Pages route until the source is
registered and semantically curated by `extract-and-export-notes`.

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

The workspace recommends only Ultra Math Preview for formula-at-cursor
rendering. `make` converts the source through Typst and writes ignored
`build/typst/index.html`. The starter
defines `\kn{canonical concept}` and `\knref{canonical concept}` so graph markers
map to `#kn`/`#ref` in the synchronized Typst projection.

## Validate

Run only:

```sh
make -C notes/math/<slug> doctor
make -C notes/math/<slug> web
make -C . notes-source-check
```

Successful HTML compilation is sufficient. The adapter creates ignored
`build/typst/main.typ`, a local toolchain, and `index.html`. Never add a TeX
engine command, PDF target, MkDocs, `docs/`, deployment command, or committed
generated Typst/HTML. For continuous terminal compilation, use
`make -C notes/math/<slug> watch`.

Read [references/upstream.md](references/upstream.md) only when refreshing the
vendored template from localLatexenv.
