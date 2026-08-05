# QLNotes semantic curation contract

Use this contract for every changed Typst, Markdown, or LaTeX file that defines
or uses knowledge.
Semantic judgment belongs to the extracting agent. `$query-kgdistiller` owns
existing-knowledge resolution and `$ingest-kgdistiller` owns graph mutation.
Scripts only inspect explicit markers, apply reviewed decisions, and validate
deterministic invariants.

## File-scoped authority

Treat one source file as the curation unit. Read the entire file, including
statements, adjacent proofs, explanatory prose, and comparisons. Extract a
candidate batch or isolated snapshot, then delegate existing-graph lookup to
`$query-kgdistiller`. Never inspect graph JSONL, entry shards, or SQLite from
this extraction workflow.

Preserve a user-authored authority marker as an accepted identity unless it conflicts with
an existing canonical node or bundles several independent concepts. Do not
rename or remove it merely to improve style.

The explicit marker spellings are format-specific:

- Typst: `#kn[Concept]` and `#ref[Concept]`;
- Markdown: `--[[Concept]]--` and `[[Concept]]` (optionally
  `[[Concept|display text]]` for a ref);
- LaTeX: `\kn{Concept}` and `\knref{Concept}`.

In Markdown, bare `[[Concept]]` is always a reference, never an authority.
For unmarked prose, decide semantically whether it defines an independently
teachable, searchable, reusable concept. Never promote every formal title by
regex, position, or wrapper type.

This rule is domain-neutral. Architecture components and tradeoffs, software
abstractions, physical or biological mechanisms, historical ideas, practical
procedures, and everyday-life concepts are eligible when the authority teaches
them as stable reusable knowledge. Formal mathematics statements are examples,
not a restriction on the graph.

## One concept per node

One authority marker denotes one concept. If a title defines several independently reusable
concepts, keep the readable title but mark each identity separately:

```typst
#definition(
  title: [#kn[Norm] and #kn[Semi-norm]],
)[...]
```

Split comma lists, conjunctions, paired constructions, and a concept bundled
with one of its properties when the parts can be taught or reused separately.
Do not split genuine aliases, translations, abbreviations, or two notations for
the same concept; keep one canonical node and add aliases through the node
delta. If an item already has a canonical node elsewhere, use the native ref
marker, not a second authority marker.

Multiple nodes may share the same authoritative statement and source line. Add
semantic edges between them only when the source supports a real relation; do
not connect them solely because they share a title.

When splitting an already-synchronized composite node, preserve its stable ID
for the primary concept. If the primary name does not already resolve to that
ID, include the reviewed alias decision in the handoff to
`$ingest-kgdistiller`. Add the remaining concepts as candidate authorities only
after `$query-kgdistiller` classifies them as new.
Do not leave the old bundle orphaned or delete its accumulated edges merely
because its public label became more precise; review and redirect any edge whose
meaning belonged to a different component.

## Source-grounded node entries

For every authority marker whose authority is in the selected file, upsert a nonempty
`text` entry through `qlkg-agent-delta-v2`. Write one to three compact sentences
that let a reader recognize the concept without opening the full note:

- state the definition or theorem claim, including essential hypotheses;
- preserve the source's mathematical meaning and important distinctions;
- synthesize the statement and its explanation instead of copying a long span;
- do not add facts that the authoritative file does not support;
- follow the authority's dominant language while preserving established domain
  terminology, notation, names, and units;
- update the entry when the authority changes materially;
- preserve an explicitly reviewed entry unless the source now contradicts it.

Use the node's existing provenance as the authority link. Set
`properties.entry_origin` to `agent-extracted` for an agent-written entry. The
source synchronizer must preserve `text` and agent properties.

For ordinary personal notes, the compact `text` entry is sufficient. Paper-
derived or original-research entries are prepared by
`$extract-paper-concepts` only for new or missing partial knowledge. They may
also carry `summary`, `context`, `role`, `prerequisites`, `confusions`,
`open_questions`, and precise `sources`. `$ingest-kgdistiller` applies the
reviewed dossier. The graph writer shards these bodies by authority; never
place a full dossier inside node properties.

An untouched legacy authority may still appear as pending in the global audit.
That is migration state, not permission to leave a selected file incomplete:
once an authority is processed by this workflow, all of its active nodes must
have entries and it must remain curation-complete on later exports.

Example delta node:

```json
{
  "id": "banach-space",
  "type": "knowledge",
  "text": "A Banach space is a normed vector space that is complete in the metric induced by its norm.",
  "properties": {
    "entry_origin": "agent-extracted"
  }
}
```

## Direct cross-file references

Add at least one format-appropriate ref marker in the selected file when all of the
following hold:

1. the file semantically uses an existing concept;
2. that concept is a direct, immediate prerequisite of a definition, theorem,
   proof, or explanation in the file;
3. its canonical authority is a different source file, regardless of format.

Place the ref at the first meaningful use, or in the title when the file restates
an externally defined result. One file-level occurrence per directly used
concept is sufficient; repeat it only when another occurrence materially helps
navigation.

Do not require a global ref for:

- a concept defined canonically in the same file;
- a remote foundational ancestor reached only through transitive prerequisites;
- generic mathematical vocabulary that is not represented by a repository node;
- proximity, keyword overlap, or a passing mention unrelated to the argument.

A ref marker records source usage and creates a backlink. It does not create a semantic
edge. Conversely, a cross-file direct `prerequisite-for` edge whose consumer is
defined in the selected file must have file-level ref coverage.

## Relation selection and direction

Use the narrowest source-supported relation. Never use `prerequisite-for` as a
generic substitute for every association.

- `prerequisite-for`: `A -> B` when understanding or proving `B` directly
  requires `A`.
- `implies`: `A -> B` when the assertion `A` logically entails `B`. For an
  explicitly proved equivalence, store both directions as `implies`.
- `generalizes`: `A -> B` when `A` strictly extends `B`, which is recovered as a
  special case.
- `derived-from`: `A -> B` when `A` is constructed, defined, or proved directly
  from `B`, and dependency wording is more precise than a learning prerequisite.
- `contrasts-with`: store one edge for an explicit conceptual contrast. Because
  the relation is symmetric, order the two node IDs lexicographically for a
  deterministic representation.
- `contains`: reserve for configured `field -> topic/knowledge` and
  `topic -> knowledge` classification; do not use it for theorem ingredients,
  document layout, field-to-field nesting, or coarse discipline roots.

Field classification is deliberately many-to-many. Preserve every directly
relevant field facet supported by the source; do not force an interdisciplinary
topic into one exclusive parent. `subject=math` and `subject=cs` are file-scope
metadata, not semantic nodes. New field names require an explicit registry
entry and real content; never pre-populate empty umbrella fields.
Use registry source/topic `fields` for shared classification. If only one node
has another directly relevant facet, set its reviewed
`properties.additional_fields`; do not misclassify the whole source merely to
obtain one cross-field edge.

Choose a relation in this order before falling back to `prerequisite-for`:

1. explicit “if and only if”, equivalent characterization, or two-way theorem:
   use the supported `implies` directions between assertion nodes;
2. explicit extension, weakening of hypotheses, or special-case recovery: use
   `generalizes` from the more general result to the special case;
3. an assertion explicitly obtained by applying, constructing from, or reducing
   to another result: use `derived-from` from the obtained assertion to the
   supporting result;
4. an explicit opposition or distinction: use `contrasts-with`;
5. a definition, hypothesis, or proof tool that must be learned first but does
   not satisfy the cases above: use `prerequisite-for`.

If an explicit comparison introduces an independently reusable counterpart only
in prose, first decide whether that occurrence is its authoritative definition
and deserves its own authority marker. A comparison theorem or proposition node does not
replace either concept endpoint. Create `contrasts-with` only after both
endpoints have source-grounded identities; do not invent a placeholder node just
to make every file contain every relation type.

A theorem cited in a proof is not automatically a prerequisite edge. Prefer
`derived-from` when the source says the result follows by applying that theorem;
prefer `prerequisite-for` when the cited concept is a required hypothesis,
definition, or reusable proof tool. Before applying a delta containing several
new edges, verify that at least two relation types were considered and explain
why a single type is correct if only one survives.

Store only direct edges with high confidence and a concrete evidence sentence.
Inspect the statement and proof. Do not store transitive closure, chronology,
historical influence, topic co-membership, or keyword co-occurrence. Remove or
replace a prior edge when the newly read authority shows that its type or
direction is wrong.

## Required extraction handoff

For each selected file:

1. read the complete changed authority and extract candidates with evidence;
2. send one batch or isolated snapshot to `$query-kgdistiller`;
3. turn known identities into native refs and new identities into authorities;
4. stop on every uncertain or conflicting identity;
5. prepare the reviewed source diff and delta without opening graph artifacts;
6. pass them with the query digests to `$ingest-kgdistiller`;
7. require a successful scoped curation/global-check receipt;
8. export and validate the owning course.

If the ingestion receipt reports an empty entry or a confirmed cross-file
direct dependency without a ref, return to semantic extraction. Do not silence
it by inventing a generic entry, deleting a valid edge, or adding a contextless
ref.
