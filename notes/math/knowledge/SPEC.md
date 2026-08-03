# Personal knowledge graph MVP

Status: implemented MVP contract (`qlkg-v1`).

## 1. Goal and boundary

This repository owns the complete knowledge workflow:

```text
authoritative Typst
    -> per-chapter semantic Markdown snapshots
    -> deterministic graph compiler
    -> committed JSONL graph + local SQLite search index
    -> Codex skills that inspect, query, and revise the authority
```

Codex is the agent. This project does not add another agent runtime, chat UI,
daemon, scheduler, hosted graph service, or autonomous background process. A
skill invokes the exporter and graph compiler while handling a user task.

Typst remains the only editable authority for mathematical content. Markdown is
an overwriteable semantic interchange format. The graph is a rebuildable index,
not a second place to hand-edit knowledge.

The MVP stack is deliberately small: Codex skills provide orchestration, Pandoc
provides the structural Markdown AST, Python's standard library compiles the
graph, committed JSONL is the portable graph snapshot, and SQLite FTS5 is the
local query accelerator. It does not use LangGraph, PydanticAI, a graph server,
or a vector database.

## 2. User-visible workflows

### Publish or refresh notes

When Codex runs `export-typst-math-notes`, it must:

1. inspect the changed Typst material and its existing graph metadata;
2. add or correct stable `id`, `concepts`, `depends`, and `aliases` in Typst when
   the new material makes them knowable;
3. export Markdown/LaTeX and build/check HTML;
4. rebuild the repository graph from every configured Markdown snapshot;
5. inspect graph diagnostics and report the graph delta.

Existing low-quality legacy metadata is reported, but does not force an
unrelated whole-course cleanup. New or edited semantic nodes must not introduce
placeholder concepts or guessed prerequisite edges.

### Recall a concept

Codex invokes the repository query command, normally through a skill:

```sh
python3 notes/math/knowledge/scripts/knowledge.py search "Radon Nikodym"
python3 notes/math/knowledge/scripts/knowledge.py show concept:radon-nikodym-theorem
```

Search returns graph IDs. `show` returns the selected node and its incoming and
outgoing evidence edges, including the authoritative Typst path and Markdown
anchor needed to inspect or revise the source.

The repository website also exposes a read-only browser at `/knowledge/`. Its
static `graph.json` route is generated during the Astro build directly from the
committed `qlkg-v1` files. The UI supports full-text recall, node-type filters,
two-hop neighborhood exploration, source evidence, and graph diagnostics. It
does not write graph state or introduce a server-side database.

### Learn from a paper or another subject

The MVP exposes a stable graph and query boundary, but does not yet mutate the
graph from `trace-concept-lineage` or CS notes. A later skill integration should:

1. query existing concepts and aliases;
2. classify extracted concepts as existing, candidate-new, or unresolved;
3. use existing personal concepts to adjust explanation depth;
4. propose a graph delta with evidence;
5. write durable subject knowledge to that subject's authority, then rebuild the
   graph.

Agent-inferred matches must never silently overwrite source-authored identity.
Ambiguous matches remain explicit unresolved candidates.

## 3. Repository layout

```text
notes/math/knowledge/
├── SPEC.md                  # this contract
├── sources.json             # configured authorities and Markdown snapshots
├── graph/                   # deterministic, committed qlkg-v1 snapshots
│   ├── manifest.json
│   ├── nodes.jsonl
│   ├── edges.jsonl
│   └── diagnostics.json
├── scripts/knowledge.py     # build/check/search/show interface
├── tests/test_knowledge.py
└── build/knowledge.sqlite   # ignored, locally rebuildable search index
```

The Web UI lives under `site/src/pages/knowledge/` with its interactive Svelte
component under `site/src/components/knowledge/`. This preserves the repository
boundary: graph data remains under `notes/`, while presentation remains under
`site/`.

`sources.json` is maintained by humans/Codex when a new authoritative entry
point is added. Each entry may name one Markdown path or a repository-relative
glob for its chapter snapshots. Discovery is therefore bounded and reviewable;
the compiler does not ingest arbitrary Markdown from the repository.

## 4. Graph model (`qlkg-v1`)

### Node types

| Type | Stable identity | Purpose |
|---|---|---|
| `document` | configured source ID | One authoritative entry point spanning its chapter snapshots |
| `section` | document ID + Markdown heading anchor | Searchable prose chunk and hierarchy |
| `statement` | document ID + authored semantic ID | Definition, theorem, lemma, proposition, corollary, or example |
| `concept` | percent-encoded authored concept key | Cross-document entity used for recall |
| `figure` | document ID + authored figure ID | Referencable diagram evidence |
| `citation` | citation key | External evidence identity |

Statement IDs are durable because their local IDs are authored in Typst.
Section IDs are structural and may change when a heading changes. Concept IDs
preserve the authored key; the compiler does not merge concepts using an LLM.

Each source-backed node records:

- authoritative Typst path;
- generated Markdown path;
- document ID and local anchor;
- searchable text and explicit semantic attributes.

### Edge relations

| Relation | Meaning | Provenance |
|---|---|---|
| `contains` | document/section hierarchy and contained evidence | structural |
| `about` | a statement explicitly names a concept | authored |
| `requires` | a statement explicitly lists a prerequisite concept | authored |
| `prerequisite-for` | projection from an explicit `depends` concept to each explicit `concepts` value | derived-authored |
| `links-to` | an internal Markdown link resolves to a graph node | authored |
| `cites` | a source-backed node cites a bibliography key | authored |

Every derived prerequisite edge names the statement that supplied its evidence.
Co-occurrence alone never creates an edge.

Aliases remain on their statement. They are promoted to a concept node only
when the statement names exactly one concept; otherwise the mapping is
ambiguous and is not guessed.

## 5. Build and consistency rules

The compiler uses Pandoc's JSON AST rather than regex extraction. It rejects:

- a missing configured authority, Markdown snapshot, or an empty configured glob;
- non-Typst authority or a schema other than `qlnotes-v1`;
- a mismatch between `semantic-node-count` and parsed stable statement IDs;
- duplicate statement IDs within one document;
- duplicate configured source IDs or paths;
- dangling graph edge endpoints.

It reports, without blocking legacy exports:

- semantic statements without concepts;
- generic placeholder concept IDs;
- prerequisite concepts with no positive evidence node;
- low per-document dependency coverage;
- unresolved internal links and prerequisite cycles.

Outputs are sorted and contain no build timestamp. `manifest.json` records source
hashes and a graph content hash, so the same inputs produce byte-identical JSON
artifacts. SQLite is deliberately ignored because it can be rebuilt from the
committed JSONL files and may vary by SQLite version.

## 6. Acceptance criteria

The MVP is accepted when:

1. both current math courses export normally;
2. export automatically rebuilds the graph;
3. `knowledge.py check` proves committed graph files match all configured
   snapshots;
4. the generated graph has no contract errors or dangling endpoints;
5. search finds concepts, aliases, statement text, and section prose;
6. the export skill documents graph exploration, sync, diagnostics, and delta
   reporting as part of its normal acceptance path.

## 7. Deferred work

- a cross-subject source registry above `notes/math/`;
- explicit personal learning-state events (`fresh`, `stale`, `partial`);
- accepted/rejected entity-resolution decisions for paper and CS concepts;
- direct integration with `trace-concept-lineage`;
- an MCP adapter if CLI invocation becomes a measurable bottleneck;
- embeddings or a vector index after lexical/graph retrieval is shown to be
  insufficient.

These extensions must preserve source evidence, deterministic rebuilds, and the
rule that Codex is the only agent runtime.
