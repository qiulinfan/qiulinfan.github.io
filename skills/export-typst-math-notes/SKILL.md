---
name: export-typst-math-notes
description: Maintain and export Typst-first mathematics notes at repository, subject, course, or individual-file scope. Use when Codex authors or migrates QLNotes Typst; curates global #kn knowledge nodes and #ref backlinks; preserves orphaned node metadata during concept moves; extracts semantic graph edges; exports chaptered editable LaTeX and Markdown; checks semantic HTML; or publishes math notes to GitHub Pages.
---

# Export Typst Math Notes

Treat Typst as the only authority. LaTeX and Markdown are readable,
committable, overwriteable chapter snapshots. The repository-wide graph is an
agent-maintained semantic index, not a mirror of document structure.

## Load the contracts

In `qlblog`, read these before acting:

- `notes/math/toolchain/README.md` and the affected course `Makefile`;
- `knowledge/SPEC.md`;
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

Use exactly one global `#kn` for a concept's authoritative definition:

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

Before synchronization:

1. read the changed source and existing graph neighborhood;
2. add or correct only high-confidence `#kn` and `#ref` markers in Typst;
3. preview with scoped `scan` and resolve duplicate names;
4. infer direct semantic relations from the statement and its proof/context;
5. apply a `qlkg-agent-delta-v2` for high-confidence node/edge upserts;
6. synchronize the source scope.

Do not infer edges from proximity, section order, or keyword co-occurrence. Do
not materialize transitive closure. `#ref` is a backlink occurrence, not a
semantic edge; inspect its context before asserting a relation.

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
knowledge-node/reference/edge deltas, diagnostics, and published route. State
whether HTML is only local and ignored or already deployed.
