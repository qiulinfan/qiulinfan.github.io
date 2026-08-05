# PDF-to-TeX normalization contract

Use this contract whenever the paper input is a URL, DOI, title, landing page,
or PDF. The normalized TeX is the only paper text passed into candidate-graph
extraction, but the acquired PDF remains immutable evidence for page-level
verification.

## Required workspace

Use an existing ignored build or learning directory. If the paper repository
has none, use a temporary directory and report its location; do not edit the
repository's ignore rules without permission.

```text
<workspace>/
├── source.pdf
├── source.json
├── pages/page-0001.png
├── text/page-0001.txt
└── normalized/paper.tex
```

Run `scripts/prepare_pdf.py` after acquiring the PDF. It copies and hashes the
source, extracts per-page text, renders every page, records low-text pages, and
creates a TeX skeleton with one unresolved marker per PDF page. Finish the TeX,
remove every unresolved marker, then run `scripts/validate_normalized_tex.py`.

The scripts require Python with `pdfplumber`, Poppler `pdftoppm`, and, for the
final compile gate, `latexmk`. Prefer the Codex bundled document runtime when
available. If a dependency is absent, install only when the current environment
and user authorization permit it; otherwise stop and report the missing tool.

## Acquire the canonical PDF

1. Resolve the paper identity from its title, authors, DOI, arXiv identifier,
   or supplied URL.
2. Search the web when the input is not already a local PDF. Prefer, in order:
   the publisher or proceedings page, arXiv, an author or institutional
   repository, then another lawful full-text host.
3. Open the landing page and PDF. Confirm title, authors, version/date, page
   count, and whether appendices or supplements are separate.
4. Download the actual PDF response, not an HTML viewer shell. Never bypass a
   login, paywall, access control, robots restriction, or expiring credential.
5. Record the landing URL, final PDF URL, access date, version/identifier, byte
   size, and SHA-256. Keep redirects or mirrors as provenance, not identity.

If no lawful complete PDF is available, stop and report the missing source. Do
not distill an abstract or search snippets as if they were the paper.

If an official source archive is available and matches the selected PDF
version, use its TeX as a transcription aid. The PDF remains the coverage and
visual baseline, and every imported source fragment must be checked against it.

## Inspect every PDF page

Use both extraction and rendering:

- extract per-page text with `pdfplumber`, `pypdf`, or an equivalent parser;
- render every page with Poppler or an equivalent renderer;
- inspect every page image, including cover, references, appendices, and pages
  whose extracted text looks plausible;
- mark scanned, empty, garbled, symbol-heavy, multi-column, or layout-sensitive
  pages for OCR or visual transcription;
- verify equations, subscripts, superscripts, Greek letters, signs, citations,
  table cells, and caption-to-object association against the rendering.

OCR is evidence acquisition, not truth. Visually verify OCR output. If a core
statement, equation, table, or figure cannot be read with confidence, retain an
explicit warning and stop before concept distillation.

## Produce one self-contained TeX transcription

Write `normalized/paper.tex` as a semantic transcription, not a visual clone.
It must compile without the source PDF or image assets and may contain only:

- text, headings, lists, footnotes, citations, and bibliographic text;
- native LaTeX mathematics;
- native tables using `tabular`, `tabularx`, `longtable`, and `booktabs`;
- high-confidence reproducible diagrams or plots written directly with TikZ or
  PGFPlots;
- textual descriptions of visual objects that cannot be reproduced faithfully.

Do not use `\includegraphics`, `\includepdf`, `\includesvg`, EPS wrappers,
base64 media, screenshots, or links that are required to understand a claim.
Do not retain running headers, decorative backgrounds, publisher chrome, or
layout-only line breaks.

Preserve section order, theorem/definition scope, equation numbering when it is
referenced, table/figure labels, citations, captions, limitations, and appendix
material required by the argument. Do not silently repair a suspected paper
error; transcribe it and record the concern.

## Convert tables and visual objects

For every table:

- reproduce headers, row/column structure, units, uncertainty notation,
  footnotes, emphasis that changes meaning, and the original table number;
- use a native LaTeX table, not TikZ, unless the object is genuinely a diagram;
- describe rather than guess cells that remain unreadable.

For every figure, plot, diagram, or algorithm panel, choose exactly one mode:

1. `tikz`: use TikZ/PGFPlots only when geometry, labels, series, axes, and values
   can be reconstructed with high confidence;
2. `description`: omit the image and write a grounded textual reconstruction.

A description must identify the original object number and PDF page, purpose,
components or axes, legend/encoding, directional relations or trends, important
quantities, conclusion supported by the object, and any unreadable detail. A
caption paraphrase alone is insufficient. Never invent raw data behind a plot.

## Preserve source mapping

Keep the header produced by `prepare_pdf.py`:

```tex
% qlpaper-normalized-v1
% qlpaper-source-sha256: <digest>
```

Retain one page boundary marker for every original page:

```tex
% qlpaper-source: page=7
```

Place each marker immediately before the content beginning on that PDF page.
If a page has no semantic content, keep the marker with a short TeX comment
explaining why. For converted or described objects, add:

```tex
% qlpaper-object: figure=3; page=7; mode=description
% qlpaper-object: table=2; page=9; mode=latex-table
```

Candidate provenance must include both the normalized TeX line/span and the
original PDF page plus equation, theorem, table, or figure label when present.

## Validate before distillation

Require all of the following:

1. `source.json` matches the PDF hash and page count.
2. Every original page has a render, extracted-text record, and TeX page marker.
3. Every section, appendix, central equation/result, table, figure, conclusion,
   and limitation is accounted for.
4. No unresolved skeleton marker or forbidden external-media command remains.
5. Tables and TikZ objects compile; described figures carry useful semantics and
   precise source locations.
6. The normalized TeX compiles in a temporary output directory.
7. A visual comparison against the source PDF finds no omitted core claim or
   material change of meaning.

Report counts of PDF pages, OCR/visual-transcription pages, native tables, TikZ
objects, described visual objects, unresolved warnings, and the PDF/TeX hashes.
Do not start candidate extraction until this gate passes.
