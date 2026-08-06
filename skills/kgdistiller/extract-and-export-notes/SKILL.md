---
name: extract-and-export-notes
description: Extract a source-grounded candidate knowledge graph from either Git-modified personal Markdown, Typst, or LaTeX notes, or from a validated qlpaper Markdown package. For personal notes, preserve author markers, query existing knowledge, transactionally ingest reviewed changes, and publish the web graph. For research papers, identify concepts, assumptions, methods, and conclusions; query the personal graph for identity and gaps; explain only new or missing knowledge; and return an isolated federated paper graph without ingesting or publishing it. Use for note curation, note-to-web export, or paper-Markdown-to-knowledge-graph distillation.
---

# Extract source-grounded knowledge graphs

Use one of two source modes. Both build and query a bounded candidate graph;
only the personal-note mode may mutate or publish the personal knowledge base.

## Select the source mode

- `personal-note`: use for Git-modified registered Markdown, Typst, or LaTeX
  notes containing native knowledge/reference markers. This is the default only
  when the request and repository scope clearly describe authored notes.
- `research-paper`: use when the user says the source is a paper or the input is
  a package whose `paper.md` begins with `qlpaper-markdown-v1`. A raw PDF is not
  valid input; first use `$extract-paper-markdown`.

State the selected mode before extraction. Never mix both authorities into one
candidate graph or silently treat a paper as a personal note.

## Enforce common boundaries

Discover `$query-kgdistiller` before identity decisions. Treat it as the only
interface to existing personal knowledge: never inspect graph JSONL, entry
shards, or SQLite directly. Build `qlkg-candidate-graph-v1`, use kgdistiller's
deterministic `candidate build`, and pass the resulting complete
`qlkg-agent-snapshot-v1` to the query Skill in one bounded batch.

Extract names, source locations, node roles, and direct relations before the
query, but do not write general explanations or decide identity from similarity.
Require one `known`, `partial`, `new`, `conflict`, or `uncertain` result per
candidate and retain target graph/snapshot digests.

Use only source-supported `contains`, `prerequisite-for`, `implies`,
`generalizes`, `contrasts-with`, and `derived-from` edges. Every semantic edge
needs evidence; `contains` and `prerequisite-for` must remain acyclic.

## Run personal-note mode

Read and follow
[references/curation-contract.md](references/curation-contract.md). Select the
smallest coherent Git change scope from `knowledge/sources.json`, including both
sides of tracked renames. Preserve the author's native markers and file-scoped
authority. Do not promote ordinary prose, generated output, or an unregistered
file into authoritative knowledge.

After query alignment, preserve known identities as refs, author only missing
content for partial/new nodes, and stop for conflict/uncertain nodes. Read
[references/validation.md](references/validation.md), pass the reviewed patch
and query digests to `$ingest-kgdistiller`, and require a committed canonical
receipt before publication.

Use [references/migration.md](references/migration.md) only for the LaTeX adapter.
Then read [references/export-contract.md](references/export-contract.md), run the
appropriate graph/Web checks, and publish the registered personal source. A
failed or missing ingest receipt blocks the Web phase.

## Run research-paper mode

Read and follow
[references/research-paper-contract.md](references/research-paper-contract.md).
Validate the paper package when the `$extract-paper-markdown` validator is
available, then read `paper.md` and all manifest-listed semantic attachments.
Use its page, heading, equation, figure, and table markers as provenance. Reopen
the source PDF only for a specific unresolved semantic ambiguity; do not repeat
all-page visual review.

Select independently explainable concepts plus paper-specific assumptions,
methods, results, and boundaries required to recover the full argument. Query
the personal graph before writing explanations. Keep known candidates in the
paper graph as bridged paper-local roles without duplicate definitions; explain
only the missing part of partial candidates and fully explain new candidates.
Retain competing senses and evidence for conflict/uncertain candidates.

Write the isolated candidate, snapshot, alignment response, and human-readable
`paper-graph.md` under `<paper-package>/knowledge/` unless another output path is
requested. The output connects the paper namespace to personal nodes with
explicit bridges, but it never merges namespaces.

Research-paper mode must not invoke `$ingest-kgdistiller`, edit knowledge
markers, modify the paper Markdown package, update the personal graph, or publish
the Web site—even when all candidates are confidently aligned. A later import is
a separate user-authorized workflow, outside this mode.

## Deliver

For personal notes, return the changed authority scope, candidate/query digests,
committed ingest receipt, validation commands, and published paths.

For research papers, return source provenance, package validation, candidate and
snapshot paths/digests, query target digest, node/edge/bridge counts, learning
order, unknown or partial explanations, and all conflict/uncertainty records.
Confirm that the personal graph digest did not change.

Stop instead of guessing when source authority is ambiguous, the paper package
has unresolved core content, identity is conflicting, a required Skill or
validator is unavailable, or an external effect lacks authorization.
