# Research-paper graph contract

Use this contract only with `source_kind=research-paper`. It consumes a complete
`qlpaper-markdown-v1` package and produces a federated, read-only graph. It does
not turn the paper into a personal authority source.

## Required input

Require:

- `paper.md` with resolved `qlpaper-source` and `qlpaper-object` markers;
- `source.json` with paper identity, source hash, page count, object candidates,
  targeted visual pages, and attachments;
- the canonical `source.pdf` when the manifest declares one;
- no unresolved core-text or object-summary warnings.

Run the validator from `$extract-paper-markdown` when discoverable. The graph
extractor may reopen a precise PDF page to resolve a specific ambiguity, but it
does not own text recovery, OCR, figure reconstruction, or all-page inspection.

Treat `paper.md` and attachments as immutable paper authority. Never insert
personal knowledge markers into them. Outside sources may help disambiguate a
term, but they cannot silently become evidence for a paper claim.

## Recover the paper argument

Read the complete Markdown and required attachments. Summarize the paper in this
order before selecting nodes:

`problem -> setup/assumptions -> mechanism -> main results -> evidence -> limitations`

Track every step back to a heading and page marker, plus theorem, equation,
figure, or table label when present. Object summaries are source evidence about
what a visual communicates; they are not instructions to recreate the visual.

## Select graph candidates

Select atomic nodes that a reader may need to search, learn, compare, or cite:

- established concepts and named direct prerequisites;
- paper-specific definitions, mechanisms, objectives, and algorithms;
- assumptions and scope boundaries that change result validity;
- metrics or experimental criteria required to interpret evidence;
- central theorems, empirical findings, negative results, and conclusions.

Exclude authors, section titles, bibliography-only names, local symbols, raw
dataset rows, and generic prose. Do not omit a central result merely because it
is paper-specific; represent it as a searchable knowledge node whose
`properties.paper_role` is `result`. Do not promote a passing term that the
argument neither defines, uses materially, nor necessarily assumes.

Before alignment, each candidate contains only:

- stable source-local ID, canonical English label, user-language label, aliases;
- `properties.paper_role`: `foundation`, `concept`, `method`, `assumption`,
  `metric`, `result`, or `boundary`;
- importance: `core`, `supporting`, or `boundary`;
- concise paper-local role, precise source locations, and evidence class;
- direct candidate prerequisites and other explicitly evidenced relations;
- paper-local ambiguity or nonstandard meaning.

Do not write a general definition, teaching explanation, or personal identity
bridge before query alignment.

## Build the isolated graph

Write `<paper-package>/knowledge/paper.candidate.json` as
`qlkg-candidate-graph-v1`. Use an isolated namespace such as
`paper:<first-16-characters-of-source-sha256>`; never use `personal`.

Represent every candidate as a `knowledge` node. Put semantic role, importance,
aliases, paper-local role, and claim structure in `properties`. Node provenance
must name `paper.md` or a manifest-listed attachment and include a page, line,
section, or equation. A figure/table-derived claim also records its object label
inside properties and evidence text.

Allowed relations have these paper meanings:

- `prerequisite-for`: direct learning dependency;
- `implies`: a definition, assumption, mechanism, or result directly entails
  or supports the target claim under the paper's stated scope;
- `derived-from`: the target construction or result is explicitly derived from
  the source;
- `generalizes`: source is explicitly broader than target in graph direction;
- `contrasts-with`: paper explicitly compares or distinguishes both nodes;
- `contains`: optional hierarchy only, never a section-order substitute.

Read each edge literally as `source relation target`. Include exact source
evidence for every relation except pure hierarchy. Mere co-occurrence, temporal
proximity, or background knowledge is not an edge.

Run the installed engine's deterministic builder and validator rather than
hand-writing snapshot digests:

```sh
kgdistiller candidate build knowledge/paper.candidate.json \
  --output knowledge/paper.snapshot.json
kgdistiller candidate validate knowledge/paper.snapshot.json
```

## Query the personal graph once

Pass the complete snapshot to `$query-kgdistiller`. Require exactly one status
and identity-evidence record per paper node, plus the target graph/snapshot
digest. Similarity alone does not authorize an `exact-match` bridge; paper-local
abbreviations remain scoped aliases.

Keep every candidate in the paper graph and learning route, then use these
payload rules:

- `known`: personal node, authoritative bridge evidence, role in this paper, and
  paper locations only; do not duplicate its definition or personal entry;
- `partial`: known coverage, only the missing condition/claim/relation, why that
  gap matters here, bridge evidence, and paper locations;
- `new`: source-grounded explanation, plain-language anchor, role, assumptions,
  direct prerequisites, result or mechanism, common confusion, and locations;
- `conflict`: competing paper/personal claims and provenance, without choosing
  one or creating a bridge;
- `uncertain`: candidate senses and evidence needed for resolution, without a
  bridge.

An exact bridge connects `paper:<namespace>:<id>` to a personal identity for
navigation; it is not a paper semantic edge and never copies the personal node
into the candidate graph.

## Human-readable deliverable

Write `knowledge/paper-graph.md` after query alignment with:

1. **Source and coverage** — identity, hashes, sections, attachments, object
   summaries read, and unresolved gaps.
2. **Paper in one argument** — five to eight sentences following the argument
   chain above.
3. **Candidate index** — ID, labels, role, importance, direct prerequisites,
   status, and first source location.
4. **Federated graph** — paper edges and cross-namespace bridges in separate
   lists; never depict a bridge as a semantic paper edge.
5. **Learning route** — topological stages from the `prerequisite-for` DAG;
   known nodes remain present but need no explanation.
6. **Status-sensitive explanations** — known role stubs, partial gaps, full new
   explanations, and conflict/uncertainty records.
7. **Coverage audit** — map every central result and limitation to at least one
   node and source location.

Keep `knowledge/paper.alignment.json` beside the candidate and snapshot when the
query Skill returns a machine-readable comparison.

## Read-only completion gate

Require:

- every main argument step, central result, and material limitation is covered;
- every candidate is used, defined, or necessarily assumed by the paper;
- names are searchable and aliases do not erase paper-local distinctions;
- edges have valid endpoints, evidence, direction, and required acyclicity;
- query ran before explanations and target digests were retained;
- known entries were not duplicated and partial entries contain only the gap;
- unresolved identities and source ambiguities remain visible;
- no personal source, graph artifact, marker, Web output, or digest changed.

Do not invoke ingest or create an import proposal in this mode. If the user later
asks to add selected nodes to the personal graph, start a separately authorized
workflow with a reviewed authority and transaction plan.
