---
name: export-typst-math-notes
description: Maintain, semantically curate, and publish repository notes whose authoritative files may be Typst, Markdown, LaTeX, or any mixture of the three. Use at repository, subject, course, directory, or file scope when Codex needs to author or export QLNotes; preserve explicit knowledge nodes and backlinks; extract node entries and typed graph edges; convert LaTeX through Typst; publish Markdown directly; validate the global knowledge graph; or update the notes website.
---

# Export Multi-Source Knowledge Notes

Treat every configured source file as authority in its own format. Generated
Markdown, Typst intermediates, HTML, and PDFs are projections, never additional
authorities. The repository graph is one semantic index shared by all formats.

## Load the contracts

In `qlblog`, read these before acting:

- `knowledge/SPEC.md` and `knowledge/sources.json`;
- `notes/math/toolchain/README.md` when Typst or LaTeX is in scope;
- [references/curation-contract.md](references/curation-contract.md) whenever
  nodes, entries, refs, or semantic edges are in scope;
- [references/export-contract.md](references/export-contract.md);
- [references/validation.md](references/validation.md).

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
  "files": ["chapters/*.typ", "chapters/*.md", "chapters/*.tex"]
}
```

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
once, and writes flat per-chapter LaTeX and Markdown snapshots:

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
node scripts/sync-note-assets.mjs
node tests/note-sources.test.mjs
```

Do not ingest generated Typst Markdown exports as direct Markdown authorities.
The canonical path is `source.web/<relative-stem>`; a terminal `README` or
`index` stem is folded into its parent route. Astro emits the matching local
path as `/notes/<subject>/<course>/<relative-stem>/` under the configured site
base.

### LaTeX

Scan the authoritative `.tex` file directly for `\kn{}` and `\knref{}`. The
export command synchronizes every selected, configured LaTeX authority first;
this registry step is required for `data-ql-kn`, anchors, and canonical ref
links. It then converts into an ignored Typst build directory and compiles with
QLNotes:

```sh
python3 notes/math/toolchain/scripts/export_latex_web.py chapter.tex \
  --repo-root . \
  --build notes/<subject>/<course>/build/typst \
  --output notes/<subject>/<course>/build/index.html \
  --title "Course Notes"
```

The converter preserves both knowledge macros as Typst `#kn`/`#ref`. Commit the
LaTeX authority, not the generated Typst or HTML. `--output` is only a local
artifact path; node provenance still uses the source's configured `web` route.
Wire that same route into the Pages artifact when the course is ready to
publish. The exporter fails if any source marker silently degrades to plain
text.

## Validate and publish

Run only the affected scope, then the shared checks:

```sh
python3 -m unittest knowledge.tests.test_knowledge \
  notes.math.toolchain.tests.test_multisource
make knowledge-check
make blog-check
make blog-build
```

For a global foundation review, run `knowledge.py audit` and use its coverage
and topology only to choose authorities to read. Never repair a metric without
source evidence.

GitHub Actions builds Astro, compiles configured Typst/LaTeX note HTML, and
uploads only the Pages artifact. Keep HTML, PDFs, generated Typst, copied note
assets, SQLite, compiler logs, and agent deltas ignored.

Report the selected authority files and formats, exported routes, node/entry/
reference/edge deltas, diagnostics, and whether the HTML is local or deployed.
