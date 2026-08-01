# QLNotes export contract

## Contents

1. Authority and boundaries
2. Semantic authoring API
3. Environment mapping
4. Knowledge-graph schema
5. Citations and references
6. Diagrams
7. Math aliases
8. Extension checklist
9. Deliberate limits

## 1. Authority and boundaries

Use this data flow:

```text
authoritative .typ
├── Typst paged target ───────────────> local/chapter PDF
├── Typst HTML target ────────────────> web output
└── semantic HTML + metadata
    └── Pandoc AST + qlnotes.lua
        ├── editable LaTeX snapshot
        └── graph-oriented Markdown snapshot
            └── deterministic qlkg compiler
                ├── committed JSONL graph
                └── ignored SQLite search index
```

Never convert from PDF. It has already lost semantic structure.

Keep content files free of layout and export configuration. Regeneration may
overwrite both snapshots, so durable edits must return to Typst.

## 2. Semantic authoring API

The statement components are:

```text
definition theorem lemma corollary proposition example
```

The supporting components are:

```text
proof solution remark note diagram cite-key
```

Keep proof and solution blocks immediately after, but outside, the statement
body:

```typst
#example(id: "ex-bayes")[
  ...
]
#solution[
  ...
]
```

This preserves semantic adjacency while allowing arbitrarily long supporting
text to paginate. Do not nest a long solution inside a figure-backed statement.

Statement calls accept:

```typst
#theorem(
  title: [Bayes' theorem],
  id: "thm-bayes",
  concepts: ("bayes-theorem",),
  depends: ("conditional-probability",),
  aliases: ("Bayes formula",),
)[
  ...
]
```

Use kebab-case IDs with a type prefix (`def-`, `thm-`, `lem-`, `cor-`,
`prop-`, `ex-`, `fig-`). Never use a page number or auto-generated location as
a durable ID.

The Typst template emits one `qlnotes-document-v1` metadata record and one
`qlnotes-v1` record for every graph-relevant node. Every semantic node must have
an ID.

## 3. Environment mapping

| Typst component | HTML class | Markdown class | LaTeX environment |
|---|---|---|---|
| `definition` | `ql-callout--definition` | `definition` | `definition` |
| `theorem` | `ql-callout--theorem` | `theorem` | `theorem` |
| `lemma` | `ql-callout--lemma` | `lemma` | `lemma` |
| `corollary` | `ql-callout--corollary` | `corollary` | `corollary` |
| `proposition` | `ql-callout--proposition` | `proposition` | `proposition` |
| `example` | `ql-callout--example` | `example` | `example` |
| `proof` | `ql-proof` | `proof` | `proof` |
| `solution` | `ql-solution` | `solution` | `qlsolution` |
| `remark` | `ql-remark` | `remark` | `qlremark` |
| `note` | `ql-note` | `note` | `qlnote` |

Markdown uses fenced divs:

```markdown
::: {#def-measure .definition concepts="measure" depends="sigma-algebra"}
**Definition: Measure**

...
:::
```

LaTeX uses native environments plus a machine-readable comment:

```latex
% qlnotes: kind=definition; id=def-measure; concepts=measure; depends=sigma-algebra
\begin{definition}{Measure}\label{def-measure}
...
\end{definition}
```

Keep non-math prose and callouts left-aligned. Display mathematics may use its
normal centered layout.

## 4. Knowledge-graph schema

The Markdown YAML block must include:

```yaml
authority: typst
qlnotes-schema: qlnotes-v1
semantic-node-count: 3
source: main.typ
```

For each semantic node, preserve:

- `id`: stable node identity;
- class/kind: semantic type;
- `concepts`: concepts defined or materially discussed;
- `depends`: prerequisite concepts;
- `aliases`: alternate names suitable for entity resolution.

Keep the attributes as readable comma-separated strings in Markdown. Preserve
the same values in the LaTeX `qlnotes` comment so both snapshots remain
inspectable.

In `qlblog`, `notes/math/knowledge/SPEC.md` defines the downstream `qlkg-v1`
node, edge, provenance, diagnostic, and determinism contract. The graph compiler
must consume the Pandoc AST and must not invent concept identity or dependency
edges with an LLM. Typst remains authoritative: graph corrections return to
Typst metadata and are then regenerated.

## 5. Citations and references

Use the Typst-side citation adapter `#cite-key("folland1999")`. Preserve the
same key as:

```text
Markdown: [@folland1999]
LaTeX:    \autocite{folland1999}
```

Copy the bibliography into each export directory as `reference.bib`. Keep
internal semantic references as readable links in Markdown and as labeled
`\hyperref`/`\ref` references in LaTeX.

## 6. Diagrams

Keep CeTZ source authoritative in Typst:

```typst
#diagram(
  draw,
  id: "fig-joint-support",
  caption: [Joint support],
  alt: [Triangular support region.],
)
```

For HTML, evaluate a zero-argument drawing function inside `html.frame` so
Typst emits inline SVG. The exporter must:

1. extract that SVG to `markdown/main.assets/<id>.svg`;
2. convert it with `rsvg-convert` to `latex/assets/<id>.pdf`;
3. emit normal relative image references in both snapshots.

Do not attempt CeTZ-to-TikZ reconstruction. The editable artifact is the Typst
diagram source; exported SVG/PDF files are vector delivery assets.

Do not place `#diagram` inside a paged-only outer `#figure` or a centered table.
Use normal document flow so the same figure reaches both the paged and HTML
targets.

Use SVG as the default Markdown and web asset because it preserves line art and
mathematics at arbitrary zoom and is displayed by Typora. Treat PNG as an
on-demand fallback for a consumer that rejects SVG; do not emit or commit it in
the default workflow.

This vector rule applies to authored CeTZ diagrams. Legacy screenshots,
scanned work, and other raster figures may remain PNG/JPEG. Typst can embed
those authored images in its self-contained HTML; the exporter extracts and
deduplicates them as deterministic `main.assets/figure-raster-*` files for
Markdown and matching `assets/figure-raster-*` files for LaTeX. It must never
leak `data:image/` URIs into either text snapshot.

## 7. Math aliases

Define common symbols centrally in `math-aliases.typ` and import them into
content. Typst aliases omit the LaTeX leading backslash:

```typst
$ bP (A) = bE X, quad X in bR $
```

Keep a space before parentheses for content aliases. Normalize exported
blackboard-bold symbols to readable LaTeX such as `\mathbb{P}`, `\mathbb{E}`,
and `\mathbb{R}` in the Pandoc filter.

## 8. Extension checklist

For a new construct, verify:

- a Typst API with stable semantic metadata;
- paged and HTML renderers;
- accessible HTML class/structure;
- web CSS;
- Markdown fenced-div mapping;
- native LaTeX mapping and class definition;
- round-trip fixture coverage;
- structural, Markdown parse, and LuaLaTeX compile checks.

## 9. Deliberate limits

- Typst is not reconstructed from exported formats.
- CeTZ diagrams are not translated into editable TikZ.
- Generated LaTeX and Markdown may be edited, but edits do not survive the next
  export unless applied back to Typst.
- Experimental Typst HTML warnings are acceptable only when the build and
  structural checks pass and no semantic content or notation is lost. A warning
  that removes an accent, relation, label, diagram, or other mathematical signal
  is a failure even when compilation succeeds.
