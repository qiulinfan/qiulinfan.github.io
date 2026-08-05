# qlblog knowledge graph policy

The reusable compiler, schema invariants, and local browser live in the
[`vendor/kgdistiller`](../vendor/kgdistiller/) submodule tracking `main`. The
Agent Skill remains authoritative under `skills/`. This file is
the host policy for qlblog's personal sources, taxonomy, curation, and site
integration.

`qlkg-v2` is the repository-wide, agent-maintained knowledge graph. Authored
documents remain readable on their own; the graph adds identity, hierarchy,
dependencies, canonical links, and backlinks without turning every heading or
statement into a node.

## Authority model

- Each configured `.typ`, `.md`, or `.tex` file is authoritative in its own
  source format; one directory and one synchronization scope may mix formats.
- Typst remains authoritative for migrated mathematics notes, Markdown for
  notes written directly in Markdown, and LaTeX when it is configured as a
  maintained source rather than a one-time migration input.
- `knowledge/graph/*.json*` is the deterministic, committed graph snapshot.
- Contextual entry bodies live in deterministic per-authority shards under
  `knowledge/graph/entries/`; `nodes.jsonl` stores only `entry_path` locators.
- `knowledge/build/knowledge.sqlite` is an ignored local search index.
- `knowledge/alignments.json` stores reviewed, fingerprint-bound mappings from
  isolated paper/research namespaces into the personal graph.
- `knowledge/workflow-policy.json` freezes legacy rollout exceptions and the
  explicit non-authority toolchain/asset classes; new notes cannot enter it as
  a curation bypass.
- Agent-created metadata and semantic edges are durable graph knowledge. A source
  edit does not silently delete them.

Generated Markdown from a Typst authority is never ingested again as a second
authority. Its markers are a portable graph-facing projection. Source type is
inferred per file, and every adapter preserves the same global node identity
and single canonical authority rule.

Each source declares `knowledge_origin`: `personal-note` for the author's
ordinary notes, or `research` for paper-derived and original-research entries.
The website renders personal knowledge as circles and research knowledge as
squares.

Site visibility is independent from graph ingestion. Every source explicitly
declares `publish` and `listed`: `publish` controls whether the notes site emits
that authority's public pages, while `listed` controls whether the source is
shown in `/notes/` and on the homepage. A listed source must also be published.
Neither flag removes the source, its taxonomy, or its knowledge from the local
graph; the public graph projection includes only sources with `publish: true`.
Sources compiled outside Astro may declare `web_artifacts`, whose
`source` paths are relative to the source root and whose `route` values are
relative to the canonical `web` URL; the Pages workflow installs only artifacts
belonging to sources with `publish: true`.

`subject` and `course` are source-selection metadata only. Values such as
`math` and `cs` never become graph nodes. The visible taxonomy begins with
specific fields such as Analysis, Measure Theory, Probability Theory,
Combinatorics, Computer Architecture, Optimization, or Deep Learning Theory.
Create a field only when at least one configured source or topic belongs to it.

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
agent explicitly places that format's authority marker on a genuinely important
concept.

## Source authoring APIs

### Typst

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

### Markdown

Use a dashed double-bracket marker for the one canonical definition and an
ordinary double-bracket marker for references:

```markdown
> **Definition: --[[cache line]]--**
>
> A cache is organized as a collection of [[cache line|lines]].
```

`--[[Name]]--` is a `kn`; the dashes are syntax and do not render. `[[Name]]`
is a `ref` and produces a backlink. `[[Name|display text]]` uses `Name` for
global identity and the alias only for display. These roles never depend on a
heading, blockquote, first occurrence, or file ordering.

On the notes website, a Markdown `kn` renders as emphasized text with the stable
`kn-<id>` anchor and no hyperlink. A Markdown `ref` renders as a hyperlink to
the canonical authority. The renderer resolves occurrences from the committed
graph by authority, line, and source name; it does not reconstruct identity.
Before Astro starts or builds, `knowledge.py publish --format markdown`
synchronizes every configured Markdown authority and then requires every local
node to have its agent-authored entry and every confirmed direct cross-file
dependency to have its ref. The deterministic publisher never writes semantic
prose or edges on the agent's behalf.

### LaTeX

Use explicit macros in the authoritative `.tex` file:

```tex
\kn{cache line}
By \knref{cache line}, spatial locality can reuse one transfer.
```

The graph scanner reads these macros from LaTeX. Web export deterministically
maps them to `#kn[...]` and `#ref[...]` during LaTeX-to-Typst conversion, then
uses the Typst HTML pipeline. Generated Typst is an ignored build intermediate,
not a second authority. An ElegantBook `main.tex` expands its synchronized
chapter inputs into a self-contained Typst project containing `main.typ`, the
QLNotes runtime, assets, and preview commands. HTML is compiled only from that
Typst project; LaTeX has no independent web renderer.

Every active knowledge node in a curation-complete authority has a concise
`text` entry distilled by the agent from its authoritative statement, proof,
and explanation. The entry is source-grounded searchable prose, not a second
authority; provenance continues to point to the canonical source location.
Source synchronization preserves the entry and its agent metadata. Legacy
authorities may remain entry-pending until their first pass through the new
file workflow; `audit` exposes that rollout state, and a newly curated file may
not return to pending.

Research entries may additionally carry a structured dossier with `summary`,
`context`, `role`, `prerequisites`, `confusions`, `open_questions`, and
`sources`. Before creating one, the agent searches canonical names and aliases
in the existing graph. A known concept becomes a ref; only a genuinely missing
concept receives a new authority and dossier.

Formal-statement components may still carry local Typst labels for document-local
cross-references. Their legacy `id`, `concepts`, `depends`, and `aliases` fields do
not define graph identity.

## Graph model

Node types:

- `field`: a top-level semantic facet, such as analysis, geometry, algebra,
  optimization, programming languages, or computer architecture;
- `topic`: a curated course-level cluster, never an imported section heading;
- `knowledge`: an authored or agent-extracted concept.

Fields form a flat, overlapping facet layer, not a discipline tree. There is no
`Mathematics`, `Computer Science`, or other universal root, and `contains`
never links one field to another. A topic may be contained by several fields;
therefore every knowledge node inherits one or more field memberships through
its topic. A source file without a topic may attach its knowledge nodes directly
to several fields. Multiple field memberships are expected and express
interdisciplinary content rather than a taxonomy conflict.

The source registry owns this explicit classification:

```json
{
  "fields": [
    {"id": "analysis", "label": "Analysis", "text": "..."},
    {"id": "optimization", "label": "Optimization", "text": "..."}
  ],
  "sources": [{
    "subject": "math",
    "fields": ["analysis"],
    "topics": [{
      "glob": "papers/*.md",
      "id": "diffusion-training-dynamics",
      "label": "Diffusion Training Dynamics",
      "fields": ["optimization"]
    }]
  }]
}
```

Topic fields are additive to source fields. The synchronizer records the
effective field IDs on topic and knowledge properties and materializes all
corresponding `contains` paths. Field creation and classification are explicit
agent decisions stored in this registry; the scanner does not infer them from
paths or prose.

When only one knowledge node crosses an additional boundary, the reviewed agent
delta sets `properties.additional_fields` rather than broadening its whole
topic. The next scoped sync unions those explicit facets with the registry
baseline and creates direct field-to-knowledge classification edges.

Semantic relations:

- `contains`: field-facet/topic classification only;
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
agent adds at least one format-native reference marker at a meaningful use.
Same-file concepts and merely transitive foundational ancestors do not require global refs. This file-level
usage record is independent of the node-to-node semantic edge.

## Incremental synchronization

The same compiler supports repository, subject, course, directory, and file
scopes:

```sh
python3 knowledge/kgd.py sync
python3 knowledge/kgd.py sync --subject math
python3 knowledge/kgd.py sync --course measure-theory
python3 knowledge/kgd.py sync \
  --file notes/cs/computer-organization
python3 knowledge/kgd.py sync \
  --file notes/math/measure-theory/chapters/01-sigma-algebra-与-measure.typ
```

`scan` accepts the same scope and previews definitions, references, errors, and
nodes that would become orphaned without writing artifacts. File arguments and
registry patterns may select `.typ`, `.md`, and `.tex` together.
Directory selection expands only configured descendants; it does not ingest
arbitrary files that merely share a supported suffix.
An explicit file must also match exactly one source's bounded `files` pattern;
living below a registered root is insufficient. The host workflow checks every
tracked or new supported note path and rejects missing or overlapping ownership.

For a selected file, synchronization replaces only that file's authored
definition/reference occurrences. Everything outside the scope is retained. A
duplicate active authority marker is an error, so moving a canonical definition is normally:

1. remove the old authority marker and synchronize that changed file;
2. the node becomes `source_status: orphaned`, while its metadata and semantic
   edges remain;
3. add the same name at the new authority and synchronize the new file;
4. the existing node becomes active at the new source.

This orphan interval is intentional. Removing prose invalidates source
provenance, not the accumulated knowledge about the concept. Semantic edges are
removed only by an explicit agent delta.

## Agent extraction, query, and ingestion

Client Skills treat kgdistiller as an opaque external brain. They never scan
`knowledge/graph/*.jsonl`, entry shards, or SQLite to decide identity. The
workflow has three separate capabilities:

1. `extract-and-export-notes` extracts a domain-neutral, source-backed candidate graph from Git-
   changed note authorities and preserves user markers;
2. `query-kgdistiller` performs read-only batch resolution, bounded retrieval,
   GraphRAG alignment, and candidate comparison;
3. `ingest-kgdistiller` is the only capability allowed to reconcile identity,
   apply reviewed deltas, synchronize authorities, or validate personal-graph
   writes.

A known candidate becomes a format-native ref and receives no duplicate entry.
A new candidate may receive one authority and source-grounded entry. Partial
knowledge adds only the missing condition, claim, role, or relation. Uncertain
and conflicting identities remain review operations.

Paper extraction happens before full entry writing. An isolated research
snapshot is compared against the personal namespace; known nodes remain paper-
local roles connected by cross-namespace bridges, while only new and missing
partial knowledge receives an explanation. This default comparison never
mutates the personal graph or alignment registry. Explicit paper import creates
a registered research authority, writes known concepts as refs, and hands only
reviewed new/partial knowledge to `ingest-kgdistiller`.

Scoped abbreviation evidence can rank candidates but cannot create a global
alias. When persistence is explicitly requested, reviewed mappings are stored
in `knowledge/alignments.json` with both endpoint fingerprints; a changed
endpoint invalidates the hard decision.

An agent delta has this shape:

```json
{
  "schema": "qlkg-agent-delta-v2",
  "remove_nodes": [],
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
├── WORKFLOW.md
├── sources.json
├── workflow-policy.json
├── alignments.json
├── kgd.py                    # thin host adapter to vendor/kgdistiller
├── graph/
│   ├── manifest.json
│   ├── nodes.jsonl
│   ├── edges.jsonl
│   ├── references.jsonl
│   ├── diagnostics.json
│   └── entries/
│       ├── by-source/<authority-filename-with-extension>.jsonl
│       └── meta/<subject>/<course>.jsonl
└── build/knowledge.sqlite       # ignored
```

Required invariants:

- one active authority marker per authored name at most, across all formats;
- stable deterministic artifacts;
- entry bodies are hydrated from manifest-listed shards, each capped below
  48 MiB; `nodes.jsonl` never duplicates their text;
- every Typst-authored knowledge node has deterministic, active-content-free
  `label_html` generated from its original `typst_name`; other formats use the
  escaped plain-label fallback;
- no dangling semantic edge endpoints;
- no cycles in `contains` or `prerequisite-for`;
- no discipline/root nodes and no field-to-field `contains` edges;
- every active knowledge node resolves to at least one configured field, while
  any number of additional field memberships is valid;
- unresolved references and orphaned nodes are visible warnings;
- a scoped sync never rewrites unrelated source state;
- examples and section headings create zero implicit nodes.

Run:

```sh
make knowledge-check
python3 knowledge/kgd.py audit
make knowledge-search QUERY="conditional expectation"
python3 knowledge/kgd.py show "Dominated convergence theorem"
python3 knowledge/kgd.py curate-check --file path/to/file.md
python3 knowledge/kgd.py publish --format markdown
python3 knowledge/workflow.py
```

The host workflow always validates every newly complete authority and every
changed authority. Its pending baseline permits untouched legacy files to
remain in rollout, but changing one forces that file through `curate-check`.

`audit` is a deterministic readiness report: it measures entry coverage by
authority, semantic connectedness, relation counts, cross-course bridges,
effective field memberships, and edge metadata completeness. Isolated nodes
and pending authorities are rollout signals, not automatic semantic errors;
only an agent reading the authority may decide whether to add a node, ref,
entry, field, or edge.
