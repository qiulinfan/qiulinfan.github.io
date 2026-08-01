---
name: export-typst-math-notes
description: Maintain and use a Typst-first mathematics-notes workflow that migrates legacy LaTeX, produces semantic web HTML, editable LaTeX, and knowledge-graph Markdown, and synchronizes the repository-owned personal knowledge graph, with optional local PDF builds. Use when Codex needs to inventory or migrate a LaTeX math course into semantic Typst; export or publish Typst notes; refresh or query the math knowledge graph; preserve theorem-like environments, stable IDs, concepts, dependencies, aliases, citations, internal references, or TikZ/CeTZ diagrams; or extend the QLNotes environment set.
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

In `qlblog`, also read `notes/math/knowledge/SPEC.md` before changing graph
semantics or integration. Use `notes/math/knowledge/scripts/knowledge.py` as the
only graph compiler/query interface and `notes/math/knowledge/sources.json` as
the bounded source registry. Do not create a second graph extractor.

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
- Put deterministic cross-document graph compilation and local search in
  `notes/math/knowledge/`; keep it downstream of exported Markdown.
- Put transient HTML, PDFs, logs, and TeX intermediates under an ignored build
  directory.
- Never commit generated whole-book PDFs, chapter PDFs, rendered PDF pages,
  contact sheets, or other pagination previews. Commit only the Typst authority,
  editable LaTeX/Markdown snapshots, and source assets required by those files.

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

## Explore graph semantics before export

For new or changed mathematical content, inspect the existing graph before
choosing concept identities:

```sh
python3 notes/math/knowledge/scripts/knowledge.py search "candidate concept"
python3 notes/math/knowledge/scripts/knowledge.py show "concept:candidate-concept"
```

Compare the changed Typst statements with existing concepts and aliases. Reuse
an existing concept key when it is genuinely the same concept. Otherwise add a
new stable concept key. Put all durable corrections in Typst, including IDs,
`concepts`, `depends`, and `aliases`; never patch generated Markdown or JSONL.

Create prerequisite edges only from explicit `depends` values justified by the
content. Do not infer them from proximity or co-occurrence. Do not introduce
placeholder keys such as `example-001` in new or edited nodes. Graph diagnostics
may expose legacy placeholders or sparse dependency metadata; report those, but
do not turn an ordinary export into an unrelated whole-course cleanup.

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

## Synchronize the personal knowledge graph

After Markdown export, rebuild the repository graph from every configured
snapshot:

```sh
python3 notes/math/knowledge/scripts/knowledge.py build --repo-root "$repo_root"
python3 notes/math/knowledge/scripts/knowledge.py check --repo-root "$repo_root"
```

Course Makefiles in `qlblog` run the build automatically at the end of
`make export`. The explicit check proves that the committed `nodes.jsonl`,
`edges.jsonl`, `manifest.json`, and `diagnostics.json` match the current Typst
exports. The ignored SQLite file is only a rebuildable local search index.

Treat any graph error as an export failure. Fix invalid semantic Markdown by
editing Typst or the canonical exporter and regenerating. Warnings are quality
signals: inspect warnings caused by the current change, while allowing known
legacy warnings to remain. Record the printed node/edge delta for the final
report.

## Build and check the web output

Compile the authoritative entry directly with Typst's HTML target into an
ignored build directory. Treat the generated HTML as a first-class output, not
as an exporter intermediate:

```sh
typst compile --features html --format html "$source" "$ignored_build/index.html"
python3 scripts/check_web.py "$ignored_build/index.html"
```

Require valid UTF-8 without replacement characters or common mojibake, a
document title, QLNotes responsive shell, table of contents, unique stable
semantic IDs, and one accessible inline SVG for every diagram. Fix a compiler
warning only when it indicates failed export or obvious textual corruption.

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

The semantic metadata and editable exports are the contract; a PDF is only an
optional local convenience output.

## Validate

Use the fast acceptance workflow in
[references/validation.md](references/validation.md):

```sh
make export
make web-check
make -C "$repo_root" knowledge-check
```

Run the corresponding extra/homework web target when applicable. If these
commands succeed, stop. Do not compile or inspect PDFs, render pages,
compare screenshots, independently compile exported LaTeX, or run broad
regression suites unless the user explicitly requests deeper QA or an export
command fails.

If dependencies are missing, run the toolchain's diagnostic first. Install
packages only when the user has authorized machine changes. Do not install a
persistent service, watcher, daemon, scheduled task, or messaging integration as
part of setup.

Report the authoritative source, the two editable entry files, the published web
route, graph delta, diagnostic count, and committed graph directory. State
explicitly when HTML remains only a local ignored artifact.
