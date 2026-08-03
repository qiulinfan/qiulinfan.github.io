# Research Markdown ingestion

Use this contract for paper distillations, literature notes, and the author's
own research. Register their source with `knowledge_origin: "research"`; the
website derives a square node from that semantic origin. Personal course and
subject notes use `personal-note` and render as circles.

Classify the research source or its topics under every directly relevant,
specific field facet. Deep Learning Theory, Optimization, Computer
Architecture, Geometry, or Programming Languages may overlap; do not introduce
a `Computer Science`, `Mathematics`, or single exclusive parent node. Register
a new field only when this source supplies real content for it.

## Compare against the external brain first

For every candidate concept, derive its canonical English name and aliases,
then search the existing qlblog graph before authoring markers:

```sh
python3 knowledge/scripts/knowledge.py --repo-root . search "canonical term"
python3 knowledge/scripts/knowledge.py --repo-root . show "resolved node"
```

- If the concept already resolves, treat it as known: use `[[canonical name]]`
  at the meaningful paper occurrence and do not create a second authority or
  another entry.
- If it does not resolve and is required to understand the paper, add one
  `--[[canonical name]]--` authority to the distilled Markdown and create its
  detailed entry.
- Preserve the paper's novel claims, mechanisms, limitations, and assumption
  boundaries even when all generic prerequisites are already known.
- Never infer “unknown” merely from wording differences; search aliases and
  inspect the candidate neighborhood.

Treat standard calculus, linear-algebra, and probability tools as search-only
foundations by default: do not promote one to a paper/research authority merely
because a concept inventory lists it. If such a foundation is absent from the
graph *and directly required* to understand the paper's argument, it may become
an unknown concept after semantic review; otherwise leave it assumed. A novel
paper-specific formulation or limitation is always reviewed separately from
the generic tool it builds on.

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
