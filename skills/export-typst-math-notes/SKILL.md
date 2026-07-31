---
name: export-typst-math-notes
description: Maintain and use a Typst-first mathematics-notes workflow that migrates legacy LaTeX and exports complete, editable LaTeX and knowledge-graph Markdown. Use when Codex needs to inventory or migrate a LaTeX math course into semantic Typst; export Typst to LaTeX or Markdown; preserve theorem-like environments, stable IDs, concepts, dependencies, aliases, citations, internal references, or TikZ/CeTZ diagrams; extend the QLNotes environment set; or validate that all three formats remain readable and consistent.
---

# Export Typst Math Notes

Treat Typst as the only authority. Treat generated LaTeX and Markdown as readable,
committable snapshots that may be edited for downstream use but will be overwritten
on regeneration.

## Locate the canonical toolchain

Search the workspace before creating files:

```sh
rg --files | rg '(^|/)(qlnotes\.typ|math-aliases\.typ|scripts/export\.py|filters/qlnotes\.lua)$'
```

Prefer the existing toolchain containing all of these files:

```text
qlnotes.typ
math-aliases.typ
web.css
scripts/export.py
filters/qlnotes.lua
latex/template.tex
latex/qlnotes-export.cls
```

In `qlblog`, use `notes/math/toolchain/typst-template/` as the canonical
implementation. Read its `README.md`, `Makefile`, and the files being modified
before changing behavior. Do not create a second exporter or copy template code
into a course note.

Read [references/export-contract.md](references/export-contract.md) before
migrating content, changing semantic environments, diagrams, citations, aliases,
or export mappings. Read
[references/validation.md](references/validation.md) before exporting or
accepting changes to the toolchain.
For a legacy LaTeX course, also read
[references/migration.md](references/migration.md) before generating Typst.

## Preserve the architecture

Keep responsibilities separated:

- Put prose, mathematics, semantic IDs, graph attributes, and diagram source in
  `.typ` content.
- Put page and web presentation in `qlnotes.typ`, `math-aliases.typ`, and
  `web.css`.
- Put format conversion in `scripts/export.py`, `filters/qlnotes.lua`, and the
  LaTeX template/class.
- Put transient HTML, PDFs, logs, and TeX intermediates under an ignored build
  directory.
- Commit chapter PDFs only when the repository policy permits them. Do not
  commit a main PDF or intermediate build products.

Do not place raw HTML, CSS, LaTeX layout commands, Pandoc options, or dependency
setup in course content. Do not silently drop unsupported content.

## Author semantic Typst

Use the public components from `qlnotes.typ`. Give every graph-relevant node a
stable, human-readable ID and explicit knowledge-graph attributes:

```typst
#definition(
  title: [Conditional expectation / 条件期望],
  id: "def-conditional-expectation",
  concepts: ("conditional-expectation",),
  depends: ("sigma-algebra", "integral"),
  aliases: ("条件期望",),
)[
  ...
]
```

Use `#cite-key("key")` for exported citations and `#diagram(...)` for figures.
Use aliases from `math-aliases.typ`; keep a space before parentheses for content
aliases such as `bP (A)` so Typst does not parse them as function calls.

Keep non-display content left-aligned. Center only formal display mathematics
and intentionally centered figure content.

Typst imports are module-scoped. Every independently included chapter must
import `qlnotes.typ` and `math-aliases.typ`; do not assume imports in `main.typ`
are visible inside `#include`d files.

Keep `#proof[...]` and `#solution[...]` as siblings immediately after their
statement instead of nesting them inside `#example[...]`. The legacy migration
script hoists them automatically so long solutions can paginate without
clipping.

## Export both snapshots

Run the canonical exporter rather than converting the paged PDF:

```sh
python3 "$toolchain/scripts/export.py" "$source" \
  --root "$project_root" \
  --output "$export_dir" \
  --build "$ignored_build_dir"
```

Choose `project_root` so it contains the source and all relative Typst imports.
Choose a versioned `export_dir` for editable snapshots and an ignored
`ignored_build_dir` for prepared HTML and metadata.

The exporter must emit:

```text
<export-dir>/
├── latex/
│   ├── main.tex
│   ├── qlnotes-export.cls
│   ├── elegantbook.cls
│   ├── reference.bib       # when cited
│   └── assets/*.pdf        # when diagrams exist
└── markdown/
    ├── main.md
    ├── reference.bib       # when cited
    └── main.assets/*.svg   # when diagrams exist
```

Keep the LaTeX directory independently compilable. Keep Markdown as plain UTF-8
with YAML metadata, fenced semantic divs, native math, citation keys, and
relative vector-asset paths. Use the Typora-compatible `<note>.assets/` sidecar
convention. Keep SVG as the default Markdown and web format; generate PNG only
as an explicit compatibility fallback.

## Extend an environment atomically

When adding or renaming an environment, update every affected layer in one
change:

1. Add its authoring component, semantic metadata, paged rendering, and HTML
   rendering in `qlnotes.typ`.
2. Add its web classes in `web.css`.
3. Map its HTML class to fenced Markdown and a native LaTeX environment in
   `filters/qlnotes.lua`.
4. Define the LaTeX environment in `latex/qlnotes-export.cls` when the base class
   does not provide it.
5. Add the environment to the round-trip fixture and validate both outputs.

Never infer correctness from PDF appearance alone; the semantic metadata and
editable exports are part of the contract.

## Validate

Run the repository targets described in
[references/validation.md](references/validation.md). Then run the skill's
format-independent checker:

```sh
python3 /path/to/export-typst-math-notes/scripts/check_exports.py \
  "$export_dir" --source "$source" --full
```

If dependencies are missing, run the toolchain's diagnostic first. Install
packages only when the user has authorized machine changes. Do not install a
persistent service, watcher, daemon, scheduled task, or messaging integration as
part of setup.

Report the authoritative source, the two editable entry files, validation
commands, semantic-node count, diagram count, and any intentionally unsupported
constructs.
