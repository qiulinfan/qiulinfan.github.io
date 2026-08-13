---
name: create-latex-math-notes
description: Create self-contained standalone LuaLaTeX mathematics-notes projects and guide local TeX Live, MacTeX, and VS Code environment setup or repair. Use when the user asks to scaffold `.tex` math notes, configure a local LaTeX environment, or compile a local PDF. Generate a project-local style, latexmk build, and editor configuration without qlblog toolchain or vendored runtime dependencies, and never add MkDocs, gh-deploy, PDF iframes, web publishing, or committed build artifacts.
---

# Create Standalone LaTeX Math Notes

Use this Skill only for an explicit standalone `.tex` project or local PDF
workflow. Keep qlblog notes and web publishing Typst-first; use
`$create-math-notes` for that active path. Do not put a generated PDF project
under `qlblog/notes/`, where PDFs are forbidden even when ignored.

Match user-facing explanations, prompts, confirmation requests, and handoffs
to the user's language unless the user requests another language. Keep
commands, identifiers, structured keys/action codes, and raw errors unchanged.

## Prepare the environment only when needed

If installation, configuration, repair, updating, or machine verification is
in scope, read
[references/local-latex-environment.md](references/local-latex-environment.md)
completely before changing the machine. Run its read-only preflight first.
Report the detected owner and exact proposed changes, and obtain the required
confirmation before a multi-gigabyte full-scheme install or any configuration
mutation. Do not reinstall a healthy toolchain merely to create a project.

## Collect the project identity

Obtain an existing destination parent directory and a lowercase hyphenated
slug. Optional values are title, subtitle, author, date, and first-chapter
title. Never overwrite an existing destination. Keep standalone projects
outside qlblog unless the user names another repository that permits local,
ignored PDF builds.

## Create the project

Resolve this Skill's directory from the loaded `SKILL.md`, then run its bundled
script by absolute path:

```sh
python3 <skill-directory>/scripts/create_latex_math_notes.py \
  complex-analysis \
  --destination-root /absolute/path/to/projects \
  --title "Complex Analysis" \
  --subtitle "Course notes" \
  --open
```

Use `py -3` instead of `python3` on native Windows when appropriate. The script
stages the complete project beside its final destination and renames it into
place only after every file renders successfully. It creates:

```text
<destination-root>/<slug>/
├── <slug>.code-workspace
├── .vscode/
│   ├── extensions.json
│   ├── settings.json
│   └── tasks.json
├── main.tex
├── chapters/01-introduction.tex
├── assets/
├── qlmathnotes.sty
├── reference.bib
├── Makefile
└── README.md
```

The output is independent of the Skill after creation: the style, build recipe,
editor configuration, and instructions are all copied into the project. It
requires only the declared local executables and TeX Live packages; it does not
read qlblog, a shared notes toolchain, a template
repository, or a knowledge registry.

## Validate the result

From the generated project, run the cross-platform build command:

```sh
latexmk -lualatex -synctex=1 -interaction=nonstopmode -halt-on-error \
  -file-line-error -outdir=build/latex main.tex
test -s build/latex/main.pdf
```

On native Windows, use `Test-Path build/latex/main.pdf` for the output check.
The same `latexmk` command is recorded in `.vscode/settings.json` and the
default VS Code build task; the Makefile is an optional POSIX convenience
wrapper. Require the environment runbook's read-only verification and strict
LuaLaTeX build to succeed before reporting completion. Keep PDF, SyncTeX, logs,
and auxiliary files below ignored `build/latex/` and do not commit them.

Stop at the local project. Never add MkDocs, `gh-deploy`, `docs/`, an iframe,
an HTML/PDF Pages route, or any deployment command. A request to publish notes
belongs to the separate Typst-first web workflow and does not authorize
reviving the retired PDF website pipeline.

When changing the package template or its authoring compatibility surface,
read [references/legacy-provenance.md](references/legacy-provenance.md)
completely and retain the embedded LPPL notice. That historical/legal record
is not an active upstream or runtime dependency.
