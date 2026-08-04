# Research knowledge ingestion

Use this contract for paper distillations, literature notes, and the author's
own research. Register their source with `knowledge_origin: "research"`; the
website derives a square node from that semantic origin. Personal course and
subject notes use `personal-note` and render as circles.

Classify the research source or its topics under every directly relevant,
specific field facet. Deep Learning Theory, Optimization, Computer
Architecture, Geometry, or Programming Languages may overlap; do not introduce
a `Computer Science`, `Mathematics`, or single exclusive parent node. Register
a new field only when this source supplies real content for it.

## Compare the candidate graph against the external brain first

Distill the paper into an isolated `qlkg-agent-snapshot-v1` namespace such as
`paper:<digest>`. Keep snapshots and review artifacts below the ignored
`knowledge/build/` directory. Then run the GraphRAG/alignment path before
authoring identities:

```sh
python3 knowledge/kgd.py agent align knowledge/build/paper.snapshot.json \
  --output knowledge/build/reviews/paper.alignment.json
python3 knowledge/kgd.py agent compare knowledge/build/paper.snapshot.json
python3 knowledge/kgd.py agent propose knowledge/build/paper.snapshot.json \
  --target-authority notes/research/paper.md \
  --output knowledge/build/reviews/paper.proposal.json \
  --delta-output knowledge/build/reviews/paper.delta.json
```

Alignment uses exact names, global aliases, evidence-backed paper-scoped
aliases, lexical/acronym candidates, typed graph consistency, and optional
disposable similarity evidence. An abbreviation is not identity. If `AC`
retrieves both `absolutely continuous` and `alternating current`, keep it
ambiguous until the paper's explicit definition and graph neighborhood support
a reviewed decision.

Persist each accepted or rejected decision in `knowledge/alignments.json`:

```sh
python3 knowledge/kgd.py reconcile alignment \
  knowledge/build/paper.snapshot.json ac absolute-continuity-of-signed-measures \
  --predicate exact-match --status reviewed \
  --justification paper-defines-the-same-mathematical-concept \
  --evidence "The paper explicitly defines AC relative to a measure."
```

Never hand-edit mapping fingerprints. A reviewed mapping is authoritative only
while both endpoints retain the recorded fingerprints; changed paper or
personal content returns it to review. Re-run `agent align` and `agent compare`
after each reconciliation.

- If a concept resolves, treat it as known: use `[[canonical name]]` at the
  meaningful paper occurrence and do not create a second authority or entry.
- If it remains absent and is required to understand the paper, add one
  `--[[canonical name]]--` authority to the distilled Markdown and create its
  detailed entry.
- Preserve novel claims, mechanisms, limitations, and assumption boundaries
  even when all generic prerequisites are known.
- Never infer “unknown” merely from wording differences; inspect aliases,
  alignment evidence, and the candidate neighborhood.

Treat standard calculus, linear-algebra, and probability tools as search-only
foundations by default. Do not promote one to a paper authority merely because
a concept inventory lists it. If such a foundation is absent and directly
required to understand the paper's argument, it may become unknown after
semantic review; otherwise leave it assumed. Review a novel paper-specific
formulation or limitation separately from the generic tool it builds on.

## Apply unknown concepts in two reviewed passes

The first proposal supplies native marker suggestions but deliberately excludes
new nodes from its delta. Review those suggestions, register the research
authority with specific field facets and `knowledge_origin: "research"`, then
edit the distilled Markdown:

- replace known concepts with `[[canonical name]]` refs at meaningful uses;
- add one `--[[canonical name]]--` authority for each genuinely unknown concept;
- keep paper-local abbreviations in prose/evidence, not global aliases.

Synchronize the marker-bearing file, then regenerate alignment, comparison, and
proposal so the safe delta targets real personal node IDs:

```sh
python3 knowledge/kgd.py scan --file notes/research/paper.md
python3 knowledge/kgd.py sync --file notes/research/paper.md
python3 knowledge/kgd.py agent align knowledge/build/paper.snapshot.json \
  --output knowledge/build/reviews/paper.alignment.json
python3 knowledge/kgd.py agent compare knowledge/build/paper.snapshot.json
python3 knowledge/kgd.py agent propose knowledge/build/paper.snapshot.json \
  --target-authority notes/research/paper.md \
  --output knowledge/build/reviews/paper.proposal.json \
  --delta-output knowledge/build/reviews/paper.delta.json
```

Read the regenerated delta and source diff. Apply only after every identity,
entry, relation, direction, and evidence sentence is reviewed:

```sh
python3 knowledge/kgd.py apply knowledge/build/reviews/paper.delta.json
python3 knowledge/kgd.py sync --file notes/research/paper.md
python3 knowledge/kgd.py curate-check --file notes/research/paper.md
python3 knowledge/workflow.py
make knowledge-check
make blog-check
make blog-build
```

## Write contextual research entries

Use `text` as a concise searchable summary and an optional structured `entry`
for the detailed dossier. Supported fields are:

- `summary`: canonical definition or claim;
- `context`: why the concept appears and the assumptions under which it is used;
- `role`: its role in the paper or research argument;
- `prerequisites`: direct canonical node IDs or names;
- `confusions`: nearby ideas that must not be conflated;
- `open_questions`: gaps, unproved claims, or assumption boundaries;
- `sources`: precise source locations.

Example delta node:

```json
{
  "id": "architecture-data-alignment",
  "text": "Architecture–data alignment requires the architecture's effective operator directions to cover the directions carrying nontrivial data structure.",
  "entry": {
    "summary": "Architecture–data alignment matches representable operator geometry to data geometry.",
    "context": "The paper studies a Gaussian target with token-axis covariance and compares two simplified denoiser classes.",
    "role": "It unifies the token-sharing positive result and flattened bottleneck obstruction.",
    "prerequisites": ["probability-flow-ode", "spectral-low-rank-approximation-obstruction"],
    "confusions": ["This is not a claim that attention universally dominates autoencoders."],
    "open_questions": ["The current result is limited to a solvable Gaussian setting."],
    "sources": ["main.tex:474-489", "main.tex:606-623"]
  },
  "properties": {
    "entry_origin": "agent-extracted",
    "knowledge_origin": "research"
  }
}
```

The graph writer stores entry bodies in per-authority shards under
`knowledge/graph/entries/by-source/`. `nodes.jsonl` retains only the
`properties.entry_path` locator. Do not hand-edit shard paths or duplicate the
entry body in node properties.
