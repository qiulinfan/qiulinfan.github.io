---
name: extract-and-export-notes
description: Extract candidate knowledge graphs from Git-modified Markdown, Typst, and LaTeX notes across mathematical, technical, scientific, humanities, architecture, and everyday domains; preserve user-written knowledge markers; delegate existing-knowledge resolution to query-kgdistiller; delegate reviewed graph writes to ingest-kgdistiller; and publish validated notes to the web. Use when Codex authors, updates, migrates, exports, or validates knowledge-bearing notes at file, directory, course, subject, or repository scope.
---

# Extract and export knowledge from multi-source notes

Own two things: extract a candidate graph from changed note authorities, and
publish the validated authorities. Treat kgdistiller as an external brain;
delegate all personal-graph queries to `$query-kgdistiller` and all personal-
graph mutation to `$ingest-kgdistiller`.

## Load only the relevant contracts

From the repository root, read:

- `knowledge/SPEC.md` and `knowledge/sources.json`;
- [references/curation-contract.md](references/curation-contract.md) for
  semantic extraction;
- [references/export-contract.md](references/export-contract.md) and
  [references/validation.md](references/validation.md) for the selected format;
- `notes/math/toolchain/README.md` only for Typst or LaTeX;
- [references/migration.md](references/migration.md) only for LaTeX migration.

Do not use this Skill to distill a paper. Use `$extract-paper-concepts`.

## Select the changed authority scope

Use Git staged, unstaged, untracked, deleted, and renamed paths to select the
smallest complete scope. Every new or changed `.md`, `.typ`, or `.tex` note must
match exactly one bounded source in `knowledge/sources.json`. Stop on missing or
overlapping ownership.

Read each complete changed authority, not only its hunks. Generated Markdown,
Typst intermediates, HTML, and PDF are never authorities. Preserve every user-
authored authority or ref marker unless the user explicitly requests an
identity change or the query handoff proves that it duplicates an established
personal identity.

## Extract a candidate graph

Extract only source-supported candidates from the changed authority:

- explicit authority and ref occurrences;
- independently teachable, searchable, reusable concepts introduced or
  materially changed by the edit;
- one atomic identity per concept, with local aliases kept separate;
- concise candidate entries and exact source spans;
- direct typed semantic relations with concrete evidence;
- meaningful immediate cross-file dependencies.

Apply the same identity standard across domains. A reusable architecture
component, scientific phenomenon, causal mechanism, design constraint,
procedure, historical idea, or everyday practice may be a node when the source
actually teaches it. Do not require a theorem wrapper, equation, formal
definition, or mathematics-specific vocabulary.

Do not promote headings, examples, equations, file order, keyword co-occurrence,
or every formal wrapper. Do not inspect `knowledge/graph/*.jsonl`, entry shards,
or SQLite to decide whether a candidate already exists.

Write the bounded source-local records as `qlkg-candidate-graph-v1`, then call
kgdistiller's `candidate build` entry point to produce the isolated
`qlkg-agent-snapshot-v1`. Do not hand-write the snapshot envelope, counts, or
digests. Hand the complete validated snapshot to `$query-kgdistiller` in one
batch.

## Apply the query decision to the source

Use only identity-authoritative query results:

- `known`: write a format-native ref to the personal node and create no entry;
- `new`: retain or add one format-native authority marker and its candidate
  source-grounded entry;
- `partial`: author only the missing condition, claim, role, or relation; do not
  duplicate the known definition;
- `uncertain` or `conflict`: stop automatic source edits and return the evidence
  for review.

Use the native syntax:

```text
Typst:   #kn[Name]        #ref[Name]
Markdown --[[Name]]--     [[Name]] or [[Name|display]]
LaTeX:   \kn{Name}        \knref{Name}
```

A ref records source usage and a backlink; it is not a semantic edge. Add it
only for a direct, immediate dependency whose authority is another file.

Pass the reviewed native source patch, expected complete marker/ref state,
candidate and query digests, decision table, entries, and typed edge delta to
`$ingest-kgdistiller`. It must run transaction plan before apply and return a
canonical `qlkg-ingest-receipt-v1`. Do not run `apply`, `sync`, `reconcile`, or
edit graph artifacts in this Skill. Continue only after the receipt reports
`committed`, successful scoped curation, and global validation.

## Publish the validated authority

Follow the selected format section of `references/export-contract.md`:

- Typst: run the owning course `make`/web checks and compile with QLNotes;
- Markdown: publish the configured authority through Astro `/notes/` routes;
- LaTeX: convert the maintained source into an ignored self-contained Typst
  project, then compile its web artifact.

Never reconstruct Typst from generated Markdown or convert from PDF. Keep
generated snapshots, HTML, SQLite, deltas, and compiler logs ignored. Treat the
source registry's `web` value as the only canonical public route.

## Validate and report

Run the affected course checks, then the shared workflow and website checks
required by `references/validation.md`. At minimum verify the source policy,
knowledge workflow, graph, Astro checks, and production build for the changed
scope.

Report:

- changed authority paths and formats;
- candidate counts and query classifications;
- reused nodes/refs versus new or partial entries;
- the ingestion receipt and diagnostics;
- exported routes and whether they are local or deployed.

Never report an export as closed if query, ingestion, curation, or publication
was skipped for a graph-affecting source change.
