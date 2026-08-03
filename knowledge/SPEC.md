# qlkg-v2 knowledge graph contract

`qlkg-v2` is the repository-wide, agent-maintained knowledge graph. Authored
documents remain readable on their own; the graph adds identity, hierarchy,
dependencies, canonical links, and backlinks without turning every heading or
statement into a node.

## Authority model

- Typst is authoritative for migrated mathematics notes.
- Markdown is authoritative for subjects that are written directly in Markdown.
- `knowledge/graph/*.json*` is the deterministic, committed graph snapshot.
- `knowledge/build/knowledge.sqlite` is an ignored local search index.
- Agent-created metadata and semantic edges are durable graph knowledge. A source
  edit does not silently delete them.

Generated Markdown from a Typst authority is never ingested again as a second
authority. Its Obsidian `[[wikilinks]]` are a portable graph-facing projection,
not enough by themselves to distinguish a definition from a reference. Future
Markdown and LaTeX source adapters must declare their source type and recover
definition/reference roles from that authority's own explicit syntax while
preserving the same global node identity and single canonical authority rule.

## What is a knowledge node?

A node should be independently teachable, searchable, reusable across documents,
and specific enough to have a stable identity. In the current mathematics pass,
the automatic candidates are only named:

- definitions;
- axioms;
- theorems;
- propositions;
- lemmas;
- corollaries.

Sections, examples, exercises, remarks, proofs, equations, figures, and diagrams
are not nodes merely because they exist. They become nodes only when an author or
agent explicitly places `#kn` on a genuinely important concept.

## Typst authoring API

Exactly one definition point owns a global knowledge name:

```typst
#definition(
  title: [#kn[Dominated convergence theorem]],
)[
  ...
]
```

`#kn` renders as black bold text and records the canonical authority location.
The authored name is the public identity and must be unique across the
repository. The synchronizer resolves it to a hidden stable machine ID, which
authors never write or maintain. It also compiles every authored name once with
Typst's HTML target: `label` remains plain searchable text, while
`properties.label_html` preserves exact inline MathML and emphasis for web UI.

Any number of references may use the same name:

```typst
#ref[Dominated convergence theorem]
```

`#ref` renders that name as a hyperlink to the active canonical definition and
is stored as a backlink occurrence. A reference is not itself a node and is not
automatically a semantic edge.

One `#kn` occurrence identifies one concept. If one authored title defines
several independently reusable concepts, the agent places a separate `#kn`
around each concept. Synonyms and abbreviations remain aliases of one node. A
script may scan explicit markers, but must never split a title or promote an
unmarked title into knowledge automatically.

Every active knowledge node in a curation-complete authority has a concise
`text` entry distilled by the agent from its authoritative statement, proof,
and explanation. The entry is source-grounded searchable prose, not a second
authority; provenance continues to point to the canonical Typst location.
Source synchronization preserves the entry and its agent metadata. Legacy
authorities may remain entry-pending until their first pass through the new
file workflow; `audit` exposes that rollout state, and a newly curated file may
not return to pending.

Formal-statement components may still carry local Typst labels for document-local
cross-references. Their legacy `id`, `concepts`, `depends`, and `aliases` fields do
not define graph identity.

## Graph model

Node types:

- `discipline`: the broadest hierarchy, such as mathematics;
- `field`: a major area, such as measure theory;
- `topic`: a curated course-level cluster, never an imported section heading;
- `knowledge`: an authored or agent-extracted concept.

Semantic relations:

- `contains`: hierarchy only;
- `prerequisite-for`: direct learning dependency;
- `implies`, `generalizes`, `contrasts-with`, `derived-from`: explicit semantic
  claims when supported by the source.

Agents should store direct, high-confidence edges rather than transitive closure,
document order, keyword co-occurrence, or “mentioned together” relationships.
Every agent edge carries origin, confidence, and evidence.

Relation directions are semantic: `A prerequisite-for B` means B directly
requires A; `A implies B` means A logically entails B; `A generalizes B` means B
is recovered as a special case; `A derived-from B` means A is directly built or
proved from B. `contrasts-with` is symmetric and is stored once with endpoints
ordered by ID. Do not use `prerequisite-for` as a generic association.

The source file is the reference-curation unit. If a file directly uses an
existing immediate prerequisite whose canonical authority is another file, the
agent adds at least one `#ref` at a meaningful use. Same-file concepts and merely
transitive foundational ancestors do not require global refs. This file-level
usage record is independent of the node-to-node semantic edge.

## Incremental synchronization

The same compiler supports four scopes:

```sh
python3 knowledge/scripts/knowledge.py --repo-root . sync
python3 knowledge/scripts/knowledge.py --repo-root . sync --subject math
python3 knowledge/scripts/knowledge.py --repo-root . sync --course measure-theory
python3 knowledge/scripts/knowledge.py --repo-root . sync \
  --file notes/math/measure-theory/chapters/01-sigma-algebra-与-measure.typ
```

`scan` accepts the same scope and previews definitions, references, errors, and
nodes that would become orphaned without writing artifacts.

For a selected file, synchronization replaces only that file's authored
definition/reference occurrences. Everything outside the scope is retained. A
duplicate active `#kn` is an error, so moving a canonical definition is normally:

1. remove the old `#kn` and synchronize that changed file;
2. the node becomes `source_status: orphaned`, while its metadata and semantic
   edges remain;
3. add the same name at the new authority and synchronize the new file;
4. the existing node becomes active at the new source.

This orphan interval is intentional. Removing prose invalidates source
provenance, not the accumulated knowledge about the concept. Semantic edges are
removed only by an explicit agent delta.

## Agent ingestion

During export, the agent:

1. handles one changed file and reads its existing graph neighborhoods;
2. preserves user-authored `#kn` markers and semantically decides any additional
   nodes, splits, aliases, and cross-file `#ref` occurrences;
3. runs a scoped scan and resolves duplicate or dangling names;
4. extracts a source-grounded entry for every node defined in the file;
5. extracts direct, correctly typed relations from statements, proofs, and
   explicit comparisons;
6. applies a `qlkg-agent-delta-v2` containing node entries, edge upserts, and any
   explicit removals;
7. synchronizes and runs file-level curation validation before export.

An agent delta has this shape:

```json
{
  "schema": "qlkg-agent-delta-v2",
  "nodes": [],
  "edges": [
    {
      "source": "fatou-lemma",
      "relation": "prerequisite-for",
      "target": "dominated-convergence-theorem",
      "confidence": "high",
      "evidence": "the proof uses Fatou's lemma"
    }
  ],
  "remove_edges": []
}
```

## Files and validation

```text
knowledge/
├── SPEC.md
├── sources.json
├── scripts/knowledge.py
├── graph/
│   ├── manifest.json
│   ├── nodes.jsonl
│   ├── edges.jsonl
│   ├── references.jsonl
│   └── diagnostics.json
├── tests/
└── build/knowledge.sqlite       # ignored
```

Required invariants:

- one active `#kn` per authored name at most;
- stable deterministic artifacts;
- every Typst-authored knowledge node has deterministic, active-content-free
  `label_html` generated from its original `typst_name`;
- no dangling semantic edge endpoints;
- no cycles in `contains` or `prerequisite-for`;
- unresolved `#ref` and orphaned nodes are visible warnings;
- a scoped sync never rewrites unrelated source state;
- examples and section headings create zero implicit nodes.

Run:

```sh
make knowledge-check
python3 knowledge/scripts/knowledge.py --repo-root . audit
make knowledge-search QUERY="conditional expectation"
python3 knowledge/scripts/knowledge.py --repo-root . show "Dominated convergence theorem"
python3 knowledge/scripts/knowledge.py --repo-root . curate-check --file path/to/file.typ
```

`audit` is a deterministic readiness report: it measures entry coverage by
authority, semantic connectedness, relation counts, cross-course bridges, and
edge metadata completeness. Isolated nodes and pending authorities are rollout
signals, not automatic semantic errors; only an agent reading the authority may
decide whether to add a node, ref, entry, or edge.
