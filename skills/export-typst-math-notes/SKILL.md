---
name: export-typst-math-notes
description: Maintain a Typst-first mathematics-notes workflow with course-root Typst authority, per-chapter editable LaTeX and knowledge-graph Markdown exports, semantic web HTML, CeTZ-to-SVG figure delivery, and repository graph synchronization. Use when Codex migrates a LaTeX math course, edits or publishes QLNotes Typst, exports chapter snapshots, updates math-note Pages routes, or refreshes and queries the personal math knowledge graph.
---

# Export Typst Math Notes

Treat Typst as the only authority. Generated LaTeX and Markdown are readable,
committable, overwriteable chapter snapshots.

## Load the repository contract

In `qlblog`, use `notes/math/toolchain/` as the only template and exporter.
Read its `README.md`, the course `Makefile`, and every toolchain file being
changed. Do not copy template or conversion code into a course.

Read [references/export-contract.md](references/export-contract.md) before
changing semantics, diagrams, citations, aliases, or format mappings. Read
[references/validation.md](references/validation.md) before acceptance. For a
legacy course, also read [references/migration.md](references/migration.md).

Before graph integration changes, read `notes/math/knowledge/SPEC.md`. Keep
`knowledge.py` as the only compiler/query interface and `sources.json` as the
bounded registry.

## Preserve the layout

Use this shape for a migrated course:

```text
course/
├── main.typ
├── <secondary>.typ
├── chapters/*.typ
├── homeworks/*.typ
├── assets/
├── reference.bib
├── Makefile
└── exports/
    ├── latex/<entry>--<chapter>.tex
    └── markdown/<entry>--<chapter>.md
```

Put Typst entries directly in the course root; never create another `typst/`
subproject. Keep presentation, aliases, conversion, and dependency setup in
`notes/math/toolchain/`. Keep HTML, PDFs, logs, prepared HTML, and other
intermediates under ignored `build/`. Course-local `site/` is generated and
ignored; GitHub Actions alone publishes HTML to Pages.

Do not commit whole-book or chapter PDFs, rendered pages, contact sheets, or
monolithic `main.tex`/`main.md` exports. Commit Typst authority, per-chapter
`.tex`/`.md`, bibliography, and required authored/vector assets.

## Author semantic Typst

Use QLNotes components with stable IDs and explicit graph attributes:

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

Use `#cite-key("key")` and `#diagram(...)`. Import shared aliases from
`math-aliases.typ`; keep a space before content-alias parentheses such as
`bP (A)`. Only formal display math and intentional figures are centered.

Every included file is a Typst module and must import `qlnotes.typ` and
`math-aliases.typ` itself. Keep `#proof[...]` and `#solution[...]` immediately
after, not inside, their statement.

For new or edited graph metadata, query before choosing identity:

```sh
python3 notes/math/knowledge/scripts/knowledge.py search "candidate concept"
python3 notes/math/knowledge/scripts/knowledge.py show "concept:candidate-concept"
```

Reuse a concept only when it is genuinely identical. Derive prerequisites only
from explicit `depends`; never infer edges from proximity. Fix durable metadata
in Typst, never in exported Markdown or graph JSON.

## Export chapter snapshots

Prefer the course command:

```sh
make export
```

For a new Makefile, invoke the shared exporter once with every entry:

```sh
python3 ../toolchain/scripts/export_course.py \
  --document main=main.typ \
  --document extras=extras.typ \
  --root ../.. \
  --output exports \
  --build build/typst/export
```

The exporter compiles each entry once, discovers its included sources, splits
at real level-one chapters, and writes flat `exports/latex/` and
`exports/markdown/` directories. `exports/markdown/index.md` is only a link
index. Markdown uses `.assets/*.svg`; LaTeX uses `assets/*.pdf` figure assets.
PNG is an explicit compatibility fallback only.

If the export command succeeds, accept the export and stop inspecting PDFs,
images, or downstream rendering. Investigate further only after a command
failure or an explicit user request.

## Synchronize graph and web

After all configured Markdown exists:

```sh
python3 notes/math/knowledge/scripts/knowledge.py build --repo-root "$repo_root"
python3 notes/math/knowledge/scripts/knowledge.py check --repo-root "$repo_root"
```

The source registry may use repository-relative globs for chapter snapshots.
The compiler preserves one logical document ID per Typst entry and records the
actual Markdown chapter path as node provenance.

Compile HTML directly from the Typst entry into ignored `build/` and run only
the basic checker:

```sh
make web-check
```

Require valid UTF-8 without replacement characters/common mojibake, a title,
the QLNotes shell and table of contents, unique semantic IDs, and accessible
inline SVG. Experimental Typst warnings are acceptable when the command and
checker succeed.

When publishing, update `.github/workflows/pages.yml` to build from the course
root and copy ignored HTML into the Pages artifact. Never commit built HTML.

## Extend mappings atomically

For a new semantic environment, update `qlnotes.typ`, `web.css`,
`filters/qlnotes.lua`, and the LaTeX class together. Preserve the same ID,
concept, dependency, alias, citation, reference, and figure semantics in both
chapter formats.

## Accept

Run only:

```sh
make export
make web-check
make -C "$repo_root" knowledge-check
```

Run the secondary-entry web checker when present. If all commands succeed,
stop. Do not compile or inspect PDFs, independently compile LaTeX, render pages,
inspect every image, or run broad regression suites by default.

Report the Typst entries, chapter counts, two export directories, graph delta,
diagnostic count, and published route. Mention whether HTML is only a local
ignored artifact or already deployed.
