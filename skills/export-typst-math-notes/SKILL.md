---
name: export-typst-math-notes
description: Maintain, semantically curate, and publish repository notes whose authoritative files may be Typst, Markdown, LaTeX, or any mixture of the three. Use at repository, subject, course, directory, or file scope when Codex needs to author or export QLNotes; preserve explicit knowledge nodes and backlinks; extract contextual node entries and typed graph edges; classify interdisciplinary knowledge under overlapping field facets without coarse discipline roots; compare distilled papers against the existing external-brain graph; convert ElegantBook LaTeX into a previewable Typst project before web export; publish Markdown directly; validate the sharded global knowledge graph; or update the notes website.
---

# Export Multi-Source Knowledge Notes

Treat every configured source file as authority in its own format. Generated
Markdown, Typst intermediates, and HTML are projections, never additional
authorities. PDF files are forbidden anywhere below `notes/`; the repository
graph is one semantic index shared by all formats.

## Load the contracts

From the authoritative repository root (`git rev-parse --show-toplevel`), read
these before acting:

- `knowledge/SPEC.md` and `knowledge/sources.json`;
- `notes/math/toolchain/README.md` when Typst or LaTeX is in scope;
- [references/curation-contract.md](references/curation-contract.md) whenever
  nodes, entries, refs, or semantic edges are in scope;
- [references/export-contract.md](references/export-contract.md);
- [references/validation.md](references/validation.md).

For a paper distillation, literature note, or the author's own research, also
read [references/research-ingestion.md](references/research-ingestion.md).

For a legacy LaTeX migration, also read
[references/migration.md](references/migration.md). Keep shared conversion and
presentation code in `notes/math/toolchain/`, graph adapters in `knowledge/`,
and website code in `site/`.

## Select and register authority

Use the smallest complete scope. One `knowledge/sources.json` source may list
mixed patterns such as:

```json
{
  "root": "notes/demo",
  "files": ["chapters/*.typ", "chapters/*.md", "chapters/*.tex"],
  "fields": ["analysis", "optimization"]
}
```

Register specific field facets in the registry and assign one or more to each
source or topic. Keep `subject`/`course` only for selecting files. Never create
coarse `Mathematics` or `Computer Science` nodes, never connect fields into a
forced tree, and never infer a single field from a directory name. A topic or
knowledge node may belong to several fields; add fields such as geometry,
algebra, deep learning theory, architecture, programming languages, or
optimization only when actual content enters that field.

Set `knowledge_origin` to `personal-note` for the author's ordinary notes and
to `research` for paper-derived or original-research entries. The website
renders the former as circles and the latter as squares.

Infer the adapter from each file suffix. Never ingest a Typst-generated
Markdown snapshot as a second authority. Keep every file within one configured
source root so scoped sync can preserve unrelated occurrences. `--file` accepts
either one authority file or a directory; a directory expands only descendants
matched by that source's configured patterns and may therefore contain all
three suffixes.

## Preserve explicit knowledge identity

Use exactly one authority marker for each global concept and any number of
format-native refs:

```typst
#definition(title: [#kn[Banach space]])[...]
By #ref[normed space], ...
```

```markdown
> **Definition: --[[Banach space]]--**
>
> It is a complete [[normed space]].
```

```tex
\kn{Banach space}
It is a complete \knref{normed space}.
```

For Markdown, `--[[Name]]--` is always the canonical `kn`; `[[Name]]` is always
a `ref`. `[[Name|display]]` keeps `Name` as identity. Do not infer roles from
headings, blockquotes, first occurrence, or file order. On the website, a
Markdown `kn` is an anchored non-link and a ref is a canonical hyperlink.

Preserve user-authored authority markers unless they conflict with a canonical
node or bundle several reusable concepts. Put separate markers around multiple
concepts in one title. Keep synonyms as aliases of one node. Query first:

```sh
python3 knowledge/scripts/knowledge.py --repo-root . search "candidate"
python3 knowledge/scripts/knowledge.py --repo-root . show "Candidate"
```

Scripts may scan explicit markers, synchronize reviewed occurrences, and apply
reviewed deltas. They must not promote headings, split concepts, select refs,
write entries, or infer semantic edges.

## Curate one changed file at a time

Before export:

1. read the complete changed authority and its graph neighborhoods;
2. preserve explicit markers and semantically decide any additional nodes,
   concept splits, aliases, and direct cross-file refs;
3. run scoped `scan` and resolve duplicates or dangling names;
4. extract a concise source-grounded entry for every local authority node;
5. infer only direct, typed, source-supported edges;
6. apply one reviewed `qlkg-agent-delta-v2`;
7. synchronize the same file and run `curate-check`.

For research Markdown, search the existing graph for every candidate first.
Known concepts become refs and are not regenerated; unknown concepts receive
one authority plus a contextual structured entry. Entry bodies are written to
per-authority shards, while `nodes.jsonl` stores only their paths.

```sh
python3 knowledge/scripts/knowledge.py --repo-root . scan --file path/to/file.md
python3 knowledge/scripts/knowledge.py --repo-root . apply knowledge/build/reviewed-delta.json
python3 knowledge/scripts/knowledge.py --repo-root . sync --file path/to/file.md
python3 knowledge/scripts/knowledge.py --repo-root . curate-check --file path/to/file.md
```

Add one meaningful ref when a file directly uses an immediate prerequisite
whose canonical authority is another file. Omit same-file and merely transitive
foundations. A ref records source usage and a backlink; it is not a semantic
edge. Read the curation contract before choosing among `prerequisite-for`,
`implies`, `generalizes`, `contrasts-with`, and `derived-from`.

If a selected file loses its authority marker, accept the orphan interval.
Synchronization retains its metadata and semantic edges until the same identity
is rehomed. Remove semantic knowledge only through an explicit reviewed delta.

## Export by source format

### Typst

Run the owning course command. It synchronizes the course, compiles each entry
once, and writes flat per-chapter LaTeX and Markdown snapshots into an ignored,
reproducible local directory:

```sh
make export
make web-check
```

Markdown is deliberately lossy: semantic environments are ordinary
blockquotes, authoritative nodes are `--[[...]]--`, refs are `[[...]]`, inline
math is `$...$`, and every display formula uses line-delimited `$$` blocks.
Never reconstruct Typst from snapshots or convert from PDF.

### Markdown

Publish configured `.md` files directly through the Astro `/notes/` routes.
The build reads committed graph occurrences, renders `kn` markers as stable
anchors without links, renders refs as links to canonical provenance, renders
`$...$`/line-delimited `$$` with KaTeX, rewrites registered note links, and
copies only referenced static assets:

```sh
cd site
python3 ../knowledge/scripts/knowledge.py --repo-root .. publish --format markdown
node tests/note-sources.test.mjs
corepack pnpm build
```

`pnpm dev`, `pnpm start`, and `pnpm build` already run this format-scoped
publication command. It synchronizes configured Markdown authorities and then
fails if an explicit node still lacks its agent-authored entry or a confirmed
direct external dependency lacks its ref. The command does not invent entries
or edges.

Do not ingest generated Typst Markdown exports as direct Markdown authorities.
The canonical path is `source.web/<relative-stem>`; a terminal `README` or
`index` stem is folded into its parent route. Astro emits the matching local
path as `/notes/<subject>/<course>/<relative-stem>/` under the configured site
base.

### LaTeX

Convert the synchronized ElegantBook `main.tex` into a self-contained Typst
project before any web compilation. The converter discovers the template's
direct `\input` chapters, extracts title metadata, copies the shared QLNotes
runtime and course assets, and emits `main.typ` plus a Makefile that can be
previewed without the LaTeX environment:

```sh
python3 notes/math/toolchain/scripts/convert_latex_project.py main.tex \
  --build notes/<subject>/<course>/build/typst
make -C notes/<subject>/<course>/build/typst preview
```

Scan the authoritative `.tex` files directly for `\kn{}` and `\knref{}`. The
export command synchronizes every selected, configured LaTeX authority first;
it also runs the same per-file curation gate before compilation. This registry
step is required for `data-ql-kn`, anchors, canonical ref links, and contextual
entries. It then converts into an ignored Typst build directory and compiles
with QLNotes:

```sh
python3 notes/math/toolchain/scripts/export_latex_web.py main.tex \
  --repo-root . \
  --build notes/<subject>/<course>/build/typst \
  --output notes/<subject>/<course>/build/index.html \
  --title "Course Notes"
```

There is no direct LaTeX-to-web renderer: the web command compiles the generated
Typst project. The converter preserves both knowledge macros as Typst
`#kn`/`#ref`. Commit the
LaTeX authority, not the generated Typst or HTML. `--output` is only a local
artifact path; node provenance still uses the source's configured `web` route.
Wire that same route into the Pages artifact when the course is ready to
publish. The exporter fails if any source marker silently degrades to plain
text.

## Validate and publish

Run only the affected scope, then the shared checks:

```sh
python3 -m unittest knowledge.tests.test_knowledge \
  notes.math.toolchain.tests.test_multisource \
  notes.scripts.test_source_policy
make knowledge-check
make blog-check
make blog-build
```

For a global foundation review, run `knowledge.py audit` and use its coverage
and topology only to choose authorities to read. Never repair a metric without
source evidence.

Never commit `exports/`; regenerate snapshots only when they are needed for
inspection or interchange. The normal course `make` target synchronizes the
graph and checks HTML without producing snapshots.

GitHub Actions builds Astro, compiles configured Typst/LaTeX note HTML, and
uploads only the Pages artifact. Keep HTML, generated Typst, copied note assets,
SQLite, compiler logs, and agent deltas ignored. Run `make notes-source-check`;
do not create, copy, or retain any PDF below `notes/`, even as an ignored preview.

Treat each source's `knowledge/sources.json` `web` value as the only canonical
public route. Never hardcode a repository name, Pages subpath, or deployment
base in the skill or graph adapters. When the public site moves, update the
registry and repository deployment configuration together, run a full graph
sync to regenerate provenance, refs, and the Typst registry, then verify legacy
redirects separately.

Report the selected authority files and formats, exported routes, node/entry/
reference/edge deltas, diagnostics, and whether the HTML is local or deployed.
