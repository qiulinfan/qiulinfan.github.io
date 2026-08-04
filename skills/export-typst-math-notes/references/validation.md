# QLNotes fast validation

## Acceptance path

For an affected Typst course, run:

```sh
make -C "$repo_root" notes-source-check
make
make web-check
make <secondary>-web-check   # when present
make -C "$repo_root" knowledge-check
```

The default `make` synchronizes the course graph and checks HTML without
generating snapshots. Run `make export` only when local LaTeX/Markdown
projections are explicitly required. If these commands succeed, accept the
result and stop.

For a configured Markdown source, also run the note renderer test and site
checks from the repository root:

```sh
cd site && node tests/note-sources.test.mjs
make -C .. blog-check
make -C .. blog-build
```

The site's dev and build commands first run `knowledge.py publish --format
markdown`. That pass synchronizes configured Markdown files and rejects missing
agent-authored entries or required direct cross-file refs; it does not perform
semantic extraction itself.

For a LaTeX authority, test the maintained conversion path before the owning
Typst web check:

```sh
python3 -m unittest notes.math.toolchain.tests.test_multisource
python3 notes/math/toolchain/scripts/convert_latex_project.py path/to/main.tex \
  --build knowledge/build/file-typst
make -C knowledge/build/file-typst preview
python3 notes/math/toolchain/scripts/export_latex_web.py path/to/main.tex \
  --repo-root . --build knowledge/build/file-typst \
  --output knowledge/build/file.html
```

Do not compile or render PDFs below `notes/`; generate contact sheets; compile
exported LaTeX independently; inspect every image; or rerun all courses by
default. Use deeper diagnostics only after a failure or explicit user request.

## Markdown snapshot check

The exporter itself rejects semantic fenced divs, leaked `.ql-kn/.ql-ref`
attributes, and display formulas whose opening and closing `$$` remain on one
line. A successful `make export` is sufficient; do not run a Markdown renderer
or inspect every formula afterward.

## Basic web check

The checker rejects:

- invalid UTF-8, replacement characters, and common mojibake;
- missing title, QLNotes shell, or table of contents;
- missing shared light/dark QLNotes theme variables;
- duplicate/invalid `data-ql-kn` IDs and broken `data-ql-ref` targets;
- inaccessible diagram SVG.

When the shared palette, QLNotes CSS, or standalone artifact installer changes,
also run:

```sh
cd site
node tests/theme-contract.test.mjs
node scripts/install-note-artifacts.mjs
```

The first command compares the mapped QLNotes semantic colors with the public
site palette. The installer must fail if it cannot move the generated QLNotes
theme into `<head>`, add the matching theme runtime and controls, and preserve
back/forward style recovery. The notes-index test must also confirm that
standalone navigation URLs carry the current presentation digest while
canonical source URLs stay unchanged.

Experimental Typst HTML warnings are acceptable when compile and check succeed.

## Graph check

The graph check requires deterministic `knowledge/graph/*.json*`, globally
unique active authority names, valid semantic edge endpoints, acyclic hierarchy/direct
prerequisites, math-aware `label_html` for Typst nodes, and no stale source
hashes. Manifest-listed entry shards must exist, match their digests, remain
below 48 MiB, and hydrate every `entry_path`. Orphans and dangling refs are visible warnings rather than silent
deletions.

The taxonomy check rejects discipline/root nodes, field-to-field `contains`
edges, and active knowledge without an effective field. Multiple field parents
are valid and expected for interdisciplinary topics.

For a changed-file workflow, preview first:

```sh
python3 knowledge/kgd.py scan --file path/to/file.md
```

For a global foundation review, also run:

```sh
python3 knowledge/kgd.py audit
```

The audit reports deterministic curation coverage and topology without failing
on legacy pending files or isolated nodes. Treat those values as routing data
for agent reading, never as permission to synthesize nodes or edges by script.

After applying the reviewed agent delta and synchronizing the file, require:

```sh
python3 knowledge/kgd.py curate-check \
  --file path/to/<source-file>
```

This deterministic check covers only explicit, already curated knowledge: every
node defined by the selected file needs a nonempty entry, and every confirmed
cross-file direct dependency needs a file-level ref marker. It never promotes
titles, splits concepts, or infers relations.

For a format-wide Markdown publication gate, use:

```sh
python3 knowledge/kgd.py publish --format markdown
```

## Repository boundary

Commit authoritative `.typ`/`.md`/`.tex`, required bibliography and referenced
authored assets, the Pages workflow, and deterministic graph snapshots. Never
commit generated `exports/`, rendered pages, local HTML, SQLite, or compiler
intermediates. Never place a PDF anywhere below `notes/`, even as an ignored
preview or diagram asset.

## Failure routing

| Failure | Inspect |
|---|---|
| Export fails | `export.py`, Lua filter, or missing source asset |
| Mojibake | source encoding and generated HTML |
| Duplicate knowledge name | every active authority-marker occurrence |
| Dangling reference | ref name and graph registry |
| Broken diagram | `#diagram`, CeTZ source, inline SVG extraction |
| Graph contract error | `knowledge/graph/diagnostics.json` and agent delta |
| Stale graph | synchronize the smallest complete source scope |
| Pages failure | workflow log and the matching course web target |
