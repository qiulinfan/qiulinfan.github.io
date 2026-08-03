# QLNotes export contract

## Data flow and authority

```text
authoritative .typ ───────────────────> Typst HTML / snapshots
authoritative .md  ───────────────────> Markdown HTML
authoritative .tex ── maintained pass ─> generated .typ ──> Typst HTML
all configured source suffixes + agent ────────────────> qlkg-v2 + backlinks
```

Never convert from PDF. A course or selected directory may mix `.typ`, `.md`,
and `.tex`; scan each configured file in its native syntax. Generated Markdown
snapshots remain downstream artifacts, while a configured Markdown source is
an authority. Durable corrections return to the configured authority before
regeneration.

A directory scope expands only files admitted by its owning source's configured
patterns. A Markdown authority publishes at `source.web/<relative-stem>`;
terminal `README` and `index` stems fold into their parent route. A LaTeX
authority's local HTML output is an ignored artifact, while its canonical node
URLs use the source registry's `web` value.

The ElegantBook LaTeX pass always emits a self-contained preview project before
HTML: `main.typ`, converted chapter modules, a copied QLNotes runtime, assets,
and preview commands. Unsupported template constructs fail explicitly so the
LaTeX and Typst adapters can be updated together; they never disappear silently.

## Semantic authoring API

Formal statement components are `definition`, `axiom`, `theorem`, `lemma`,
`corollary`, `proposition`, and `example`. Supporting components are `proof`,
`solution`, `remark`, `note`, `diagram`, and `cite-key`.

Keep proofs and solutions immediately after, not inside, their statement. Keep
ordinary prose and callouts left-aligned; only display math and intentional
figures use centered layout.

Knowledge identity is independent of the statement wrapper and source format:

```typst
#definition(title: [#kn[σ-algebra]])[
  ...
]

By #ref[σ-algebra], ...
```

```markdown
--[[σ-algebra]]--

By [[σ-algebra]], ...
```

```latex
\kn{σ-algebra}

By \knref{σ-algebra}, ...
```

- an authority marker (`#kn[...]`, `--[[...]]--`, or `\kn{...}`) has one
  globally unique authored name and one authority location;
- a ref marker (`#ref[...]`, `[[...]]`, or `\knref{...}`) may occur any number
  of times and links to that authority;
- the synchronizer assigns a hidden stable machine ID and emits `data-ql-kn`
  plus a stable `kn-<id>` anchor; authors never maintain that ID;
- an authority marker displays the authored name as non-link emphasized text;
- the graph stores searchable plain `label` plus Typst-rendered inline MathML in
  `properties.label_html`; web views prefer the latter and escape fallback text;
- a ref emits `data-ql-ref` or an equivalent canonical hyperlink in HTML;
- Typst-to-Markdown renders authority as `--[[name]]--` and refs as `[[name]]`;
  direct Markdown uses the same unambiguous syntax, with `[[name|display]]`
  available for ref display text;
- a title defining several independent concepts contains several authority
  occurrences rather than one bundled node;
- statement-local labels may coexist, but do not create graph nodes;
- examples and sections have no automatic graph meaning.

## Environment mapping

| Typst | HTML | Markdown | LaTeX |
|---|---|---|---|
| `definition` | `ql-callout--definition` | blockquote | `definition` |
| `axiom` | `ql-callout--axiom` | blockquote | `axiom` |
| `theorem` | `ql-callout--theorem` | blockquote | `theorem` |
| `lemma` | `ql-callout--lemma` | blockquote | `lemma` |
| `corollary` | `ql-callout--corollary` | blockquote | `corollary` |
| `proposition` | `ql-callout--proposition` | blockquote | `proposition` |
| `example` | `ql-callout--example` | blockquote | `example` |
| `proof` | `ql-proof` | blockquote | `proof` |
| `solution` | `ql-solution` | blockquote | `qlsolution` |

Generated chapter Markdown frontmatter uses `qlnotes-schema: qlnotes-v2` and records
its knowledge-node count. Markdown deliberately drops fenced-div classes and
hidden IDs; statement type remains as the bold first line of a blockquote.
Inline math uses `$...$`, while display math always uses `$$` delimiters on
separate lines. The graph scanner reads configured authorities directly rather
than reconstructing identity from a downstream export.

## Knowledge graph

`knowledge/SPEC.md` is authoritative for `qlkg-v2`. The graph distinguishes:

- source-defined knowledge nodes (the format-appropriate authority marker);
- registry-curated field facets and topics, with multiple field membership;
- semantic edges with evidence;
- authored ref occurrences used as backlinks.

There are no discipline roots. Source `subject` and `course` values remain
operational metadata and never appear as `Mathematics` or `Computer Science`
nodes. `contains` is limited to field-to-topic/knowledge and
topic-to-knowledge classification.

For each changed file, the agent also writes a concise source-grounded `text`
entry for every locally authoritative node. A direct immediate prerequisite
defined in another file requires a meaningful file-level ref marker; same-file
and transitive ancestors do not. Scripts validate these reviewed decisions but do
not infer them.

Source synchronization may target a repository, subject, course, or file. A
missing definition in the selected scope makes its node orphaned; it does not
delete metadata or semantic edges. A semantic edge changes only through an
explicit agent delta.

Node entry bodies are not stored inline in `nodes.jsonl`. The graph manifest
lists per-authority entry shards, and each node with an entry stores only its
`properties.entry_path`. Consumers hydrate the shards before search or display.

## Citations and references

Use `#cite-key("folland1999")`, preserved as `[@folland1999]` in Markdown and
`\autocite{folland1999}` in LaTeX. Copy `reference.bib` into both export roots.
Preserve document-local references independently from global graph refs.

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
- relevant graph scanning when any authority/ref syntax changes;
- graph-label MathML rendering and its focused fixture when name presentation
  changes;
- focused fixture coverage.

Typst is never reconstructed from snapshots; CeTZ is never translated to TikZ;
successful exports do not require PDF or page-image inspection.
