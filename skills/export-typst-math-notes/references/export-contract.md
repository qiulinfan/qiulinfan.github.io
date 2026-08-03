# QLNotes export contract

## Data flow and authority

```text
authoritative Typst
├── Typst paged target ───────────────> optional local PDF
├── Typst HTML target ────────────────> ignored HTML / GitHub Pages
├── semantic HTML + Pandoc filter ────> per-chapter LaTeX and Markdown
└── #kn / #ref source scan + agent ───> qlkg-v2 graph and backlinks
```

Never convert from PDF. Generated snapshots may be edited for downstream use,
but durable corrections return to Typst before regeneration.

## Semantic authoring API

Formal statement components are `definition`, `axiom`, `theorem`, `lemma`,
`corollary`, `proposition`, and `example`. Supporting components are `proof`,
`solution`, `remark`, `note`, `diagram`, and `cite-key`.

Keep proofs and solutions immediately after, not inside, their statement. Keep
ordinary prose and callouts left-aligned; only display math and intentional
figures use centered layout.

Knowledge identity is independent of the statement wrapper:

```typst
#definition(title: [#kn[σ-algebra]])[
  ...
]

By #ref[σ-algebra], ...
```

- `#kn` has one globally unique authored name and one authority location;
- `#ref` has any number of occurrences and links to that authority;
- the synchronizer assigns a hidden stable machine ID and emits `data-ql-kn`
  plus a stable `kn-<id>` anchor; authors never maintain that ID;
- `#kn` displays the authored name as black bold text;
- `#ref` emits `data-ql-ref` and remains a readable hyperlink in snapshots;
- statement-local labels may coexist, but do not create graph nodes;
- examples and sections have no automatic graph meaning.

## Environment mapping

| Typst | HTML | Markdown | LaTeX |
|---|---|---|---|
| `definition` | `ql-callout--definition` | `definition` div | `definition` |
| `axiom` | `ql-callout--axiom` | `axiom` div | `axiom` |
| `theorem` | `ql-callout--theorem` | `theorem` div | `theorem` |
| `lemma` | `ql-callout--lemma` | `lemma` div | `lemma` |
| `corollary` | `ql-callout--corollary` | `corollary` div | `corollary` |
| `proposition` | `ql-callout--proposition` | `proposition` div | `proposition` |
| `example` | `ql-callout--example` | `example` div | `example` |
| `proof` | `ql-proof` | `proof` div | `proof` |
| `solution` | `ql-solution` | `solution` div | `qlsolution` |

Each chapter Markdown frontmatter uses `qlnotes-schema: qlnotes-v2` and records
its knowledge-node count. Exported LaTeX/Markdown preserve readable knowledge
labels, hidden IDs, and links, but `knowledge/scripts/knowledge.py` scans authority
Typst rather than reconstructing identity from an export.

## Knowledge graph

`knowledge/SPEC.md` is authoritative for `qlkg-v2`. The graph distinguishes:

- source-defined knowledge nodes (`#kn`);
- agent-created discipline/field/topic nodes;
- semantic edges with evidence;
- authored `#ref` occurrences used as backlinks.

Source synchronization may target a repository, subject, course, or file. A
missing definition in the selected scope makes its node orphaned; it does not
delete metadata or semantic edges. A semantic edge changes only through an
explicit agent delta.

## Citations and references

Use `#cite-key("folland1999")`, preserved as `[@folland1999]` in Markdown and
`\autocite{folland1999}` in LaTeX. Copy `reference.bib` into both export roots.
Preserve document-local Typst references independently from global `#ref`.

## Diagrams

Keep CeTZ source authoritative and call it through `#diagram(...)` with a stable
figure ID, caption, and nonempty alt text. HTML uses inline SVG. Markdown uses
`.assets/<entry>--<id>.svg`, supported by Typora. LaTeX uses a corresponding
vector PDF asset. Do not reconstruct TikZ and do not default to PNG.

Authored raster screenshots may remain raster; exporters must extract them to
deterministic asset files and must never leak `data:image/` URIs into text.

## Math aliases

Define shared notation only in `math-aliases.typ`. Import it into every chapter
module. Typst content aliases use a space before parentheses, for example
`bP (A)`. Normalize exported blackboard-bold symbols to standard LaTeX.

## Extension checklist

When adding a construct, update:

- the Typst API and paged/HTML renderers;
- accessible HTML class and CSS;
- the Pandoc/Lua Markdown mapping;
- the native LaTeX mapping and class;
- relevant graph scanning only if `#kn/#ref` semantics change;
- focused fixture coverage.

Typst is never reconstructed from snapshots; CeTZ is never translated to TikZ;
successful exports do not require PDF or page-image inspection.
