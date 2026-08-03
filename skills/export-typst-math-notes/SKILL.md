---
name: export-typst-math-notes
description: Maintain and export Typst-first mathematics notes at repository, subject, course, or individual-file scope. Use when Codex authors or migrates QLNotes Typst; semantically curates global #kn nodes, source-grounded node entries, cross-file #ref backlinks, and typed graph edges; preserves orphaned metadata during concept moves; exports chaptered editable LaTeX and Markdown; checks semantic HTML; or publishes math notes to GitHub Pages.
---

# Export Typst Math Notes

Treat Typst as the only authority. LaTeX and Markdown are readable,
committable, overwriteable chapter snapshots. The repository-wide graph is an
agent-maintained semantic index, not a mirror of document structure.

## Load the contracts

In `qlblog`, read these before acting:

- `notes/math/toolchain/README.md` and the affected course `Makefile`;
- `knowledge/SPEC.md`;
- [references/curation-contract.md](references/curation-contract.md) whenever
  knowledge nodes, entries, references, or semantic edges are in scope;
- [references/export-contract.md](references/export-contract.md);
- [references/validation.md](references/validation.md).

For a legacy LaTeX course, also read
[references/migration.md](references/migration.md). Keep all presentation,
aliases, conversion code, and dependency setup in `notes/math/toolchain/`.

## Preserve repository boundaries

Course roots contain authority directly, never another `typst/` subproject:

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

Commit Typst, per-chapter `.tex`/`.md`, bibliography, required authored assets,
and deterministic `knowledge/graph/` snapshots. Keep HTML, PDFs, compiler logs,
SQLite, monolithic exports, rendered pages, and other intermediates ignored.
GitHub Actions publishes HTML to Pages; never commit a generated course `site/`.

## Curate explicit knowledge identity

Use exactly one global `#kn` for each concept's authoritative definition:

```typst
#theorem(
  title: [#kn[Dominated convergence theorem]],
)[
  ...
]
```

Use any number of `#ref` occurrences:

```typst
#ref[Dominated convergence theorem]
```

`#kn` renders black and bold. `#ref` links to the active canonical definition
and produces a backlink. The authored name is the public identity; the graph
maintains a hidden stable machine ID. Reuse a name only for the identical
concept, and query first:

```sh
python3 knowledge/scripts/knowledge.py --repo-root . search "candidate concept"
python3 knowledge/scripts/knowledge.py --repo-root . show "Candidate concept"
```

For automatic curation, consider only named definitions, axioms, theorems,
propositions, lemmas, and corollaries. Never create implicit nodes from sections,
examples, exercises, remarks, proofs, figures, equations, or diagrams. An author
may explicitly mark an unusually important item with `#kn`.

Prefer stable conceptual names over statement numbers, source locations, or
generic labels. Formal components without `#kn` remain readable statements and
do not enter the graph.

Treat every `#kn` occurrence as one identity. When a title defines several
independently reusable concepts, place a separate `#kn` around each concept;
do not store a comma- or conjunction-separated bundle as one node. Keep true
synonyms and spelling variants as aliases of one node. Never use a migration
script or title heuristic to make this semantic decision.

Keep math inside the authored name as Typst math, for example
`#kn[$L^p$ convergence]`. Synchronization preserves a plain label for search and
batch-compiles the original name to MathML for graph lists, detail views,
tooltips, relations, and DOM labels over the graph canvas. Do not approximate
Typst math with a client-side string converter.

## Ingest the changed scope agentically

Choose the smallest complete scope:

```sh
# whole repository or subject
python3 knowledge/scripts/knowledge.py --repo-root . sync
python3 knowledge/scripts/knowledge.py --repo-root . sync --subject math

# one course
python3 knowledge/scripts/knowledge.py --repo-root . sync --course measure-theory

# one or several changed files
python3 knowledge/scripts/knowledge.py --repo-root . scan --file path/to/chapter.typ
python3 knowledge/scripts/knowledge.py --repo-root . sync --file path/to/chapter.typ
```

Process changed sources one file at a time. Before synchronization:

1. read the complete changed file and existing graph neighborhoods;
2. preserve user-authored `#kn` identities and semantically decide any new
   `#kn`/`#ref` markers without automatic title promotion;
3. split multi-concept definitions into separate nodes and preview with scoped
   `scan` to resolve identity collisions;
4. extract a concise source-grounded entry for every `#kn` defined in the file;
5. infer direct typed relations from definitions, statements, proofs, and
   explicit comparison language;
6. add one `#ref` for each direct prerequisite whose canonical authority is a
   different file, while omitting same-file and merely transitive foundations;
7. apply one reviewed `qlkg-agent-delta-v2` containing node entries and edge
   changes, then synchronize the file;
8. run `curate-check` for that file before exporting the course.

```sh
python3 knowledge/scripts/knowledge.py --repo-root . curate-check \
  --file path/to/changed.typ
```

Do not infer edges from proximity, section order, or keyword co-occurrence. Do
not materialize transitive closure. `#ref` is a backlink occurrence, not a
semantic edge; inspect its context before asserting a relation.

For a repository-level foundation review, run the deterministic structural
audit before selecting semantic fixes:

```sh
python3 knowledge/scripts/knowledge.py --repo-root . audit
```

Use its coverage, component, hub, and relation counts to locate files worth
reading. An isolated node or pending file is not itself evidence for an edge or
entry; never repair an audit number without reading the relevant authority.

Scripts may parse, synchronize, and validate explicit markers and reviewed
deltas. They must not decide that a title is a node, split a concept, choose a
direct prerequisite, write a node entry, or select a semantic relation. Those
are agent judgments governed by the curation contract. Do not run
`migrate_knowledge_markers.py` as part of daily ingestion.

If a selected file loses a `#kn`, accept the resulting orphan. Its canonical
source becomes inactive, but node metadata and all semantic edges remain. When
the same name appears in its new article and that file is synchronized, the node
reattaches. Remove semantic knowledge only through an explicit reviewed delta.

## Export chapter snapshots

Run the course command; it synchronizes that course before exporting:

```sh
make export
```

For a new Makefile, call the shared exporter once with all entries. It compiles
each entry once, discovers included modules, and writes flat per-chapter LaTeX
and Markdown. Markdown diagrams use Typora-compatible `.assets/*.svg`; LaTeX
uses vector `assets/*.pdf`. CeTZ remains the editable diagram authority. Never
reconstruct TikZ and never emit page PNGs.

Treat Markdown as a deliberately lossy graph-ingestion snapshot. Emit semantic
environments as ordinary blockquotes, render both `#kn` and `#ref` names as
Obsidian `[[wikilinks]]`, keep inline math in `$...$`, and put every display
formula between `$$` delimiters on their own lines. Do not preserve fenced-div
classes or hidden knowledge IDs in Markdown.

If export succeeds, accept it. Do not compile or inspect PDFs, render pages,
inspect every image, or independently compile generated LaTeX unless a command
fails or the user explicitly asks.

## Build and publish web output

Compile Typst HTML under the ignored course `build/` directory, then run:

```sh
make web-check
```

Only require basic integrity: valid UTF-8 without replacement characters or
common mojibake, a title, the QLNotes shell/table of contents, unique `#kn`
anchors, valid `#ref` targets, and accessible inline SVG. Experimental Typst
warnings are acceptable when compilation and the checker succeed.

GitHub Actions builds the same HTML from committed Typst and deploys only the
Pages artifact. Update `.github/workflows/pages.yml` when adding a course route.
The `/knowledge/` UI reads `properties.label_html` for math-aware node labels
and falls back to escaped plain `label` for non-Typst hierarchy nodes.

## Extend mappings atomically

For a new semantic environment, update `qlnotes.typ`, `web.css`,
`filters/qlnotes.lua`, and the LaTeX class together. Preserve `#kn`, `#ref`,
citation, internal-reference, and figure semantics across HTML, Markdown, and
LaTeX.

## Accept

Run only the affected scope:

```sh
make export
make web-check
make <secondary>-web-check   # when present
make -C "$repo_root" knowledge-check
```

Then stop. Report the scope, Typst entries, chapter counts, export directories,
knowledge-node/entry/reference/edge deltas, diagnostics, and published route.
State whether HTML is only local and ignored or already deployed.
