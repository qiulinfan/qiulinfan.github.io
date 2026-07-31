# QLNotes Typst toolchain

This directory is the shared Typst-first mathematics notes toolchain.
`notes/math/prob/typst/` is its first full production migration; `demo.typ`
remains the small review and regression fixture.

The same `demo.typ` source renders to:

- a paged PDF for local review;
- semantic, responsive HTML using Typst's experimental HTML target;
- queryable metadata embedded in the Markdown knowledge-graph snapshot.

## Build

The one-time setup installs/checks Typst, Pandoc, librsvg and TeX Live through
Homebrew:

```bash
make setup
make doctor
```

Daily commands:

```bash
make
make pdf
make web
make check
make watch
make export
make export-roundtrip
make export-check
```

`make watch` starts Typst's live-reloading HTML preview server. HTML export is
still experimental upstream and therefore requires the `html` feature flag.
`make check` also fails if the document has no semantic records or if any
record is missing the `qlnotes-v1` schema and a stable ID.

`make export` produces complete, editable snapshots from `demo.typ`.
`make export-roundtrip` exercises the same pipeline with aliases, theorem-like
environments, citations, and a CeTZ diagram. `make export-check` compiles both
LaTeX snapshots with LuaLaTeX and reparses both Markdown snapshots.

## Migrating a legacy LaTeX course

Create the first Typst draft with the bundled AST migration filter:

```sh
python3 scripts/migrate_latex.py /path/to/chapters/*.tex \
  --output-dir /path/to/draft/chapters \
  --diagram-dir /path/to/ignored-build/tikz \
  --manifest /path/to/ignored-build/diagrams.json
```

The migrator expands the legacy blackboard/caligraphic aliases, preserves
theorem-like semantics and labels, extracts active TikZ blocks, and hoists
nested proof/solution blocks out of examples so long supporting text can
paginate. It emits a draft, not a finished course: port each extracted TikZ
figure to CeTZ, add meaningful captions and alt text, and compare per-kind
environment counts with the LaTeX baseline.

Each included chapter must import `qlnotes.typ` and `math-aliases.typ` itself;
imports from the entry file do not cross Typst module scopes. Once cleanup has
started, regenerate into a separate draft directory and diff it instead of
overwriting curated Typst.

## Authority and export contract

Typst is the only authoritative source. The conversion direction is:

```text
main.typ
├── PDF / HTML       (Typst template)
├── latex/main.tex   (Pandoc AST + QLNotes LaTeX filter)
└── markdown/main.md (Pandoc AST + QLNotes Markdown filter)
```

The exported directories are deliberately self-contained:

```text
exports/<name>/
├── latex/
│   ├── main.tex
│   ├── qlnotes-export.cls
│   ├── elegantbook.cls
│   ├── reference.bib
│   └── assets/*.pdf
└── markdown/
    ├── main.md
    ├── reference.bib
    └── main.assets/*.svg
```

Both `main.tex` and `main.md` can be opened and edited directly. The LaTeX
snapshot compiles from its own directory without Typst, Pandoc, CeTZ, or TikZ.
The Markdown snapshot is plain UTF-8 text, uses Typora-compatible SVG sidecar
assets, and keeps citation keys and graph attributes. Regenerating an export
overwrites the snapshot; changes that should survive belong in the Typst
authority.

All layout, conversion, and dependency configuration lives in this toolchain,
not in course content. A course source only imports the Typst module and declares
document metadata.

## Authoring surface

`demo.typ` demonstrates the intended daily-writing API:

```typst
#definition(
  title: [Measure / 测度],
  id: "def-measure",
)[
  ...
]

#theorem(
  title: [Continuity from below / 下连续性],
  id: "thm-continuity-below",
)[
  ...
]

#proof[
  ...
]
```

Semantic metadata is carried by the component itself and is invisible in the
visual outputs:

```typst
#definition(
  title: [Measure / 测度],
  id: "def-measure",
  concepts: ("measure",),
  depends: ("sigma-algebra",),
)[
  ...
]
```

The `qlnotes.typ` module owns layout and target-specific behavior. Course
content should not contain colors, borders, page dimensions, or raw HTML.

Keep proof and solution blocks as siblings after a statement. Nesting a long
solution inside the figure-backed example callout can clip paged output.

## Math aliases

Common mathematical symbols and operators live in `math-aliases.typ` and can
be imported directly:

```typst
#import "math-aliases.typ": *

$ bP (X in cF) = bE X, quad
  Var(X) = bE (X - bE X)^2, quad
  X in bR $
```

The aliases intentionally resemble the existing LaTeX commands, but Typst
identifiers do not use a leading backslash. Keep a space before parentheses
for content aliases such as `bP (A)`; otherwise Typst interprets `bP(A)` as a
function call.

## Diagram migration spikes

The `experiments/` directory contains small, compilable migration probes:

- `aliases-smoke.typ` verifies the alias module in PDF and HTML.
- `cetz-smoke.typ` verifies that one CeTZ drawing can target PDF and inline
  SVG in HTML.
- `probability-support-region.typ` ports the support-region TikZ figure from
  `notes/math/prob/chapters/03-joint&conditional-distribution.tex`.
- `export-roundtrip.typ` verifies the full Typst → LaTeX/Markdown path,
  including stable graph metadata and extracted vector assets.

Run all probes with:

```sh
make spikes
```

For HTML, a CeTZ drawing is passed as a zero-argument function and evaluated
inside `html.frame`. This matters because the frame switches its contents to
the paged target before producing inline SVG. It avoids a checked-in generated
SVG while keeping the Typst drawing as the single source.

## Conversion boundary

Text, headings, math, lists, tables, theorem-like environments, internal
references, citation keys, bibliography data, and semantic graph attributes
are translated into native editable LaTeX and Markdown.

CeTZ is the authoritative source for diagrams. HTML and Markdown receive SVG;
LaTeX receives a vector PDF and a normal `\includegraphics` statement. PNG is
only an on-demand compatibility fallback and is not emitted or committed by
default. The exporter does not attempt to regenerate editable TikZ.
