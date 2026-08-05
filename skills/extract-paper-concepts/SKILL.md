---
name: extract-paper-concepts
description: Read a complete academic paper or paper repository, extract a source-grounded isolated concept graph, query kgdistiller before writing full entries, omit duplicate entries for knowledge already present in the personal knowledge base, and return a federated paper-to-personal snapshot without mutating the personal graph. Use for PDF, LaTeX, Markdown, Word, or linked papers; prerequisite learning maps; paper concept inventories; and explicit, separately authorized handoffs of selected missing concepts to ingest-kgdistiller.
---

# Extract a federated paper concept graph

Own the paper and its candidate graph. Treat the personal knowledge base as an
external service: call `$query-kgdistiller` before explaining concepts, and call
`$ingest-kgdistiller` only when the user explicitly requests an import.

## Establish the paper boundary

Identify the canonical version and read the complete main text, central
equations and results, figure/table captions, conclusion, limitations, and any
appendix or supplement required by the argument. Resolve LaTeX inputs,
bibliography, and notation files. For PDF, inspect every page and visually check
equations or diagrams where extraction may be unreliable.

Distinguish paper claims from repository notes and outside background. Record
what was read, missing, or ambiguous. Never infer the concept set from only an
abstract, introduction, filename, or citation list.

## Build the candidate graph before entries

First summarize the argument as:

`problem -> setup -> mechanism -> main result -> evidence -> limitations`

Then select atomic concepts that are independently teachable and necessary for
the paper's argument. Include foundations, mechanisms, paper-specific results,
assumptions, metrics, and important distinctions. Exclude local symbols,
authors, datasets, section headings, and generic filler words unless they are
independently necessary.

Include every named direct prerequisite that the paper operationally uses in a
definition, construction, theorem, or proof, even when it looks elementary or
likely to be known already. The external-brain query, not the extractor's
memory, decides whether that prerequisite is known. In particular, do not
extract a normalized, derived, or bounded construction while omitting the
named base operation from which the source explicitly builds it.

For each candidate record only:

- stable source-local ID and canonical English name;
- user-language name and paper-local aliases;
- type and importance;
- its role in this paper;
- exact source locations and evidence class;
- direct candidate prerequisite IDs;
- ambiguity or nonstandard paper-local meaning.

Do not write its general explanation or full concept card yet. Write a bounded
`qlkg-candidate-graph-v1`, then call kgdistiller's `candidate build` entry point
to create an isolated `qlkg-agent-snapshot-v1` namespace such as
`paper:<digest>`. Do not hand-write the snapshot envelope or digests. Keep both
artifacts below the paper's ignored build/learning workspace. Candidate
prerequisite edges express learning order, not section order or generic
co-occurrence.

## Query the external brain once

Pass the complete candidate snapshot to `$query-kgdistiller`. Do not open the
personal graph, entry shards, or SQLite. Require a target graph/snapshot digest
and one `known`, `partial`, `new`, `conflict`, or `uncertain` result per
candidate.

Paper abbreviations such as `AC` remain scoped evidence. They never become
global aliases, and similarity never decides identity. Preserve unresolved
senses for review.

## Build the federated deliverable

Follow [references/inventory-contract.md](references/inventory-contract.md).
Keep every candidate in the learning index and paper graph, then vary its
payload by query status:

- `known`: include only the paper-local role, evidence, and an exact bridge to
  the personal node; do not reproduce or paraphrase its knowledge entry;
- `partial`: explain only the missing condition, role, claim, or relation and
  bridge the known portion;
- `new`: write the complete source-grounded concept card;
- `conflict`: show both claims and provenance without choosing one;
- `uncertain`: show the candidate senses and non-authoritative matching
  evidence without creating a bridge.

The result is a federated snapshot, not a merged graph. Keep candidate nodes and
paper edges in the paper namespace; store cross-namespace mappings as bridges.
Do not copy personal entries into the snapshot merely for convenience.

If a reusable artifact is requested, write the inventory to the user-specified
path. Otherwise use `<paper-root>/learning/<paper-stem>-concepts.md` and keep the
machine-readable snapshot beside it. End with the first concepts to learn,
recommended next deep dive, unresolved terminology, and coverage warnings.

## Import only by explicit request

The default workflow must leave the personal `graph_sha256` unchanged. If the
user explicitly requests import:

1. select the requested `new` concepts and missing parts of `partial` concepts;
2. create or update one registered research authority with exact paper sources;
3. represent every `known` concept as a ref;
4. send the reviewed source patch, bridges, entries, edges, and query digests to
   `$ingest-kgdistiller`, review its transaction plan, and require a committed
   canonical receipt.

Do not import unresolved or conflicting identities. Do not treat producing the
paper snapshot as permission to persist an alignment.

## Quality gate

Before delivery verify:

- paper coverage and version are explicit;
- every core argument step maps to at least one candidate;
- every named direct prerequisite used by a core candidate is itself present
  in the candidate graph and can receive a query classification or bridge;
- every candidate has a paper role and precise source evidence;
- the candidate builder validated schema, endpoints, source locations, counts,
  ordering, and digests;
- direct prerequisite edges form a DAG;
- query ran before full entries were written;
- known concepts have no duplicated entry;
- partial entries describe only the gap;
- bridges connect namespaces without merging them;
- the personal graph digest is unchanged unless import was explicitly asked;
- all unresolved terminology remains visible.
