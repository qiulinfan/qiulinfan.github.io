# QLNotes validation workflow

## Contents

1. Preflight
2. Migration parity checks
3. Template and semantic checks
4. Export checks
5. Web checks
6. Independent snapshot checks
7. Visual PDF checks
8. Acceptance criteria
9. Failure routing

## 1. Preflight

From the canonical toolchain directory, run:

```sh
make doctor
```

The expected commands are:

```text
python3 typst pandoc rsvg-convert lualatex latexmk biber rg
```

If a command is missing, inspect `scripts/setup.sh` before running it. Install
dependencies only with user authorization.

## 2. Migration parity checks

For a migrated course, compare legacy LaTeX and Typst per-file environment
counts. Also compare active TikZ blocks with `#diagram` calls and exported asset
stems. Compile lecture and homework entry points separately when both exist.

Reject a migration containing replacement characters in IDs, duplicate IDs,
generic diagram alt text, or raw-LaTeX fallbacks in Typst.

## 3. Template and semantic checks

Run the complete template and diagram probes:

```sh
make all
make spikes
```

`make all` must compile the paged PDF and experimental HTML, then query Typst
metadata. The metadata check must find exactly one `qlnotes-document-v1`
record, at least one `qlnotes-v1` record, and a stable ID for every semantic
node.

`make spikes` must cover math aliases, CeTZ in both targets, a migrated
probability diagram, and the full round-trip fixture.

## 4. Export checks

For the maintained fixtures, run:

```sh
make export-check
```

For an arbitrary note, invoke the exporter directly:

```sh
python3 scripts/export.py "$source" \
  --root "$project_root" \
  --output "$export_dir" \
  --build "$ignored_build_dir"
```

Never put the build directory inside the committed export snapshot.

## 5. Web checks

Compile the course HTML into its ignored build directory, then run:

```sh
python3 scripts/check_web.py build/index.html \
  --expected-nodes "$semantic_and_diagram_id_count" \
  --expected-diagrams "$diagram_count"
```

The checker requires a title, the QLNotes responsive shell, a document table of
contents, unique ASCII semantic IDs, accessible diagram labels, inline SVG, and
no `data:image/` URI. Review compiler warnings separately. Search the resulting
HTML around every construct reported as ignored and reject any loss of notation;
for example, an ignored `overline` that turns a sample mean into an ordinary
variable is not a non-fatal warning.

Report the final HTML path and whether it is a local artifact or a published
site route. Do not imply that an ignored local build is already deployed.

## 6. Independent snapshot checks

Run the skill checker from the skill directory:

```sh
python3 scripts/check_exports.py "$export_dir" \
  --source "$source" \
  --full
```

Without `--full`, the checker performs standard-library-only structural checks.
With `--full`, it also:

- reparses Markdown with Pandoc;
- compiles LaTeX with `latexmk -lualatex` in a temporary output directory.

This keeps main PDFs and TeX intermediates out of the export snapshot.

## 7. Visual PDF checks

Compile the Typst PDF into an ignored build directory. Render every page to PNG
under `tmp/pdfs/` with `pdftoppm`, build contact sheets, and inspect them. Then
inspect representative pages at full size:

- title and contents;
- each chapter boundary;
- long theorem/example/solution continuations;
- wide tables and code blocks;
- every class of diagram.

Compare against the legacy PDF for chapter order and representative content.
Exact page counts need not match. Reject any content crossing the footer,
clipped callout, missing continuation, blank page caused by lost content, or
unreadable figure.

## 8. Acceptance criteria

Accept the export only when:

- Markdown declares `authority: typst` and `qlnotes-schema: qlnotes-v1`;
- the YAML semantic count matches stable semantic IDs;
- semantic ID/kind pairs match between Markdown and LaTeX;
- supported environment counts match between Markdown and LaTeX;
- citation keys match;
- every Markdown SVG and LaTeX PDF reference resolves;
- diagram asset stems match across formats;
- bibliography files exist when declared;
- neither text export contains a `data:image/` URI;
- Pandoc can parse Markdown;
- LuaLaTeX/Biber can compile LaTeX;
- source environment counts match the legacy baseline when migrating;
- PDF visual inspection finds no overflow, clipping, or lost continuation;
- web HTML passes `check_web.py`, and ignored-backend warnings do not erase
  mathematical notation or semantic content;
- the handoff reports the local HTML artifact separately from site publication.

Warnings from Typst's experimental HTML backend or CJK font fallback may be
reported as non-fatal only when all acceptance checks pass.

## 9. Failure routing

Route failures to the owning layer:

| Symptom | Inspect first |
|---|---|
| Missing semantic ID or count mismatch | `qlnotes.typ` metadata emission |
| Wrong Markdown/LaTeX environment | `filters/qlnotes.lua` |
| LaTeX environment undefined | `latex/qlnotes-export.cls` |
| Diagram embedded as data URI | `scripts/export.py` extraction |
| Missing SVG/PDF asset | `#diagram`, HTML figure attributes, `rsvg-convert` |
| Citation key lost | `#cite-key`, Lua citation normalization |
| Math alias unreadable | `math-aliases.typ`, Lua math normalization |
| Web-only layout defect | `web.css` and HTML rendering branch |
| Web math accent or operator missing | replace the unsupported Typst math construct and inspect generated MathML |
| Long statement clipped | nested proof/solution structure and paged statement rendering |
| Corrupt semantic ID | LaTeX migration slugging and UTF-8 truncation |
| Broken diagram with `>` in alt text | quoted HTML attribute parsing in `scripts/export.py` |
