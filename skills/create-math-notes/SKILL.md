---
name: create-math-notes
description: Create a new Typst-first mathematics subject or course under qlblog/notes/math. Use when the user asks to start, scaffold, initialize, or新建 math notes that should open directly in VS Code/Tinymist and inherit the shared QLNotes template, chaptered LaTeX/Markdown export, semantic HTML checks, and knowledge-graph synchronization used by the probability notes.
---

# Create Math Notes

Create only mathematics notes. Treat `notes/math/toolchain/` as the shared
template and build authority; never copy it into a course.

## Collect names

Obtain these two values from the request, asking only if they cannot be inferred:

- a lowercase hyphenated filesystem slug, such as `functional-analysis`;
- a human-facing title, such as `Functional Analysis` or `泛函分析`.

Optional metadata includes course code, author, date, description, keywords,
and first-chapter title. Never overwrite an existing directory.

## Create the course

From the qlblog repository root, run:

```sh
python3 skills/create-math-notes/scripts/create_math_notes.py \
  functional-analysis \
  --title "Functional Analysis" \
  --course "MATH 501" \
  --open
```

Omit `--course` when there is no course code. Omit `--open` only when the user
does not want VS Code opened. The script creates:

```text
notes/math/<slug>/
├── <slug>.code-workspace
├── main.typ
├── chapters/01-introduction.typ
├── assets/
├── Makefile
├── reference.bib
└── README.md
```

It also registers the source in `knowledge/sources.json`. The workspace opens
`notes/math` as its root and pins `<slug>/main.typ` as the Tinymist entry. Do not
add `tinymist.rootPath`: named-workspace variables are not expanded reliably by
Tinymist and can prevent the language server from starting.

## Validate

Run only the new course's fast path:

```sh
make -C notes/math/<slug> export
make -C notes/math/<slug> web-check
```

Successful commands are sufficient. Do not inspect PDFs or generate page
images. Confirm that chaptered snapshots appear under `exports/latex/` and
`exports/markdown/`, while HTML and compiler output remain under ignored
`build/`.

If validation changes deterministic knowledge graph snapshots, keep those
changes: source registration and scoped synchronization are part of course
creation. Do not add a GitHub Pages route unless the user also asks to publish
the new notes.

