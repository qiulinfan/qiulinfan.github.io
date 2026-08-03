# QLNotes fast validation

## Acceptance path

For a migrated course, run only:

```sh
make export
make web-check
make -C "$repo_root" knowledge-check
```

Run the corresponding extra/homework web target when the course has another
published entry point. Course `make export` automatically rebuilds the
repository graph after both Markdown entry points are current. If export, basic
web checks, and the graph freshness check succeed, accept the result and stop.

Do not perform any of these by default:

- compile, render, or visually inspect PDFs;
- generate page PNGs, contact sheets, or screenshots;
- independently compile exported LaTeX;
- reparse Markdown with another tool;
- compare page counts or inspect every image;
- rerun other courses as regression fixtures.

Use deeper diagnostics only when the user explicitly requests them or one of
the acceptance commands fails.

## Basic web check

Compile HTML into an ignored build directory and run:

```sh
python3 scripts/check_web.py build/index.html
```

The checker rejects invalid UTF-8, replacement characters, common mojibake,
missing titles, a missing QLNotes shell or table of contents, duplicate or
invalid semantic IDs, and inaccessible diagram SVGs.

## Repository boundary

Commit:

- authoritative `.typ` files;
- editable `.tex` and `.md` snapshots;
- bibliography and authored/diagram assets that those sources require;
- the GitHub Pages workflow;
- deterministic `notes/math/knowledge/graph/*.json*` snapshots.

Never commit generated whole-book or chapter PDFs, rendered PDF pages, contact
sheets, local HTML builds, the SQLite search index, or compiler intermediates.
Vector PDF files used only as LaTeX figure assets are allowed.
GitHub Actions must build HTML from the committed Typst source and deploy the
static artifact directly.

## Failure routing

| Failure | Inspect |
|---|---|
| Export command fails | `scripts/export.py`, Lua filter, missing source asset |
| Replacement text or mojibake | source encoding and generated HTML |
| Missing/duplicate semantic ID | `qlnotes.typ` metadata and content IDs |
| Broken diagram | `#diagram`, CeTZ source, inline SVG extraction |
| Graph contract error | Typst semantic attributes, Markdown Pandoc AST, `notes/math/knowledge/graph/diagnostics.json` |
| Stale graph snapshot | rerun course export or `knowledge.py build` after all configured Markdown exists |
| GitHub Pages build fails | workflow log and course web target |
