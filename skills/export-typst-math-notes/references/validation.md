# QLNotes fast validation

## Acceptance path

For an affected course, run only:

```sh
make export
make web-check
make <secondary>-web-check   # when present
make -C "$repo_root" knowledge-check
```

`make export` synchronizes the course graph before generating per-chapter
snapshots. If these commands succeed, accept the result and stop.

Do not compile, render, or visually inspect PDFs; generate page PNGs or contact
sheets; compile exported LaTeX independently; inspect every image; or rerun all
courses by default. Use deeper diagnostics only after a failure or explicit user
request.

## Basic web check

The checker rejects:

- invalid UTF-8, replacement characters, and common mojibake;
- missing title, QLNotes shell, or table of contents;
- duplicate/invalid `data-ql-kn` IDs and broken `data-ql-ref` targets;
- inaccessible diagram SVG.

Experimental Typst HTML warnings are acceptable when compile and check succeed.

## Graph check

The graph check requires deterministic `knowledge/graph/*.json*`, globally
unique active `#kn` names, valid semantic edge endpoints, acyclic hierarchy/direct
prerequisites, math-aware `label_html` for Typst nodes, and no stale source
hashes. Orphans and dangling refs are visible warnings rather than silent
deletions.

For a changed-file workflow, preview first:

```sh
python3 knowledge/scripts/knowledge.py --repo-root . scan --file path/to/file.typ
```

## Repository boundary

Commit authoritative `.typ`, per-chapter `.tex`/`.md`, required bibliography and
authored/vector assets, the Pages workflow, and deterministic graph snapshots.
Never commit whole-book/chapter PDFs, rendered pages, local HTML, SQLite, or
compiler intermediates.

## Failure routing

| Failure | Inspect |
|---|---|
| Export fails | `export.py`, Lua filter, or missing source asset |
| Mojibake | source encoding and generated HTML |
| Duplicate knowledge name | every active `#kn` occurrence |
| Dangling reference | `#ref` name and graph registry |
| Broken diagram | `#diagram`, CeTZ source, inline SVG extraction |
| Graph contract error | `knowledge/graph/diagnostics.json` and agent delta |
| Stale graph | synchronize the smallest complete source scope |
| Pages failure | workflow log and the matching course web target |
