---
name: extract-paper-concepts
description: Find the canonical PDF for a paper URL, DOI, title, or landing page; normalize PDF or other non-TeX input into a visually verified, image-free TeX transcription; extract a source-grounded isolated concept graph; query kgdistiller before writing full entries; omit duplicate entries for knowledge already present in the personal knowledge base; and return a federated paper-to-personal snapshot without mutating the personal graph. Use for web-linked papers, PDFs, scans, LaTeX or Markdown paper repositories, Word manuscripts, prerequisite learning maps, paper concept inventories, and explicit, separately authorized imports of selected missing concepts.
---

# Extract a federated paper concept graph

Own paper acquisition, PDF-to-TeX normalization, and the isolated candidate
graph. Treat the personal knowledge base as an external service: call
`$query-kgdistiller` before explaining concepts, and call
`$ingest-kgdistiller` only when the user explicitly requests an import.

## Resolve the complete paper

For a URL, DOI, title, abstract page, or HTML viewer, search the web for the
canonical landing page and a lawful complete PDF. Prefer publisher/proceedings,
arXiv, and author or institutional sources. Confirm title, authors, version,
date, page count, appendices, and supplements. Never treat an abstract, search
snippet, viewer shell, or related paper as the requested paper, and never bypass
access controls.

For a maintained LaTeX or Markdown paper repository, resolve all included text,
bibliography, notation, appendix, and supplement files. It may be read directly
when it is complete and version-matched; otherwise acquire the canonical PDF and
normalize it. Use an official matching source archive only as a transcription
aid, not as a substitute for checking the PDF.

## Normalize non-TeX input before extraction

For PDF, scan, Word, or another non-TeX primary input, read and follow
[references/pdf-normalization-contract.md](references/pdf-normalization-contract.md).
Export a Word or other paginated manuscript to PDF first so page-level visual
evidence and the same normalization gate apply.
Keep the immutable PDF, page renders, extracted text, manifest, and normalized
TeX in an existing ignored build/learning workspace; otherwise use a temporary
directory and report it. Do not modify ignore rules without permission.

Resolve this Skill's directory and run the bundled preflight after the PDF is
local:

```sh
python3 <skill-directory>/scripts/prepare_pdf.py PAPER.pdf --output-dir WORKSPACE \
  --landing-url LANDING_URL --pdf-url PDF_URL --identifier DOI_OR_ARXIV
```

Inspect every rendered page, repair extraction or OCR errors, and complete
`WORKSPACE/normalized/paper.tex`. Preserve text, native equations, LaTeX
tables, and only high-confidence TikZ/PGFPlots reconstructions. Embed no image
assets. Replace every visual object that cannot be faithfully reconstructed
with a source-located semantic description of its components, encodings,
relations, trends, quantities, and conclusion.

Validate the complete transcription before selecting concepts:

```sh
python3 <skill-directory>/scripts/validate_normalized_tex.py \
  --manifest WORKSPACE/source.json \
  --tex WORKSPACE/normalized/paper.tex --compile
```

Treat the normalized TeX as the paper text supplied to candidate extraction,
while retaining PDF page numbers as evidence. Record both TeX line/span and PDF
page/object labels in candidate provenance. Stop if a core statement, equation,
table, or figure remains unreadable or materially ambiguous.

## Establish the semantic boundary

Read the complete normalized paper text, central equations and results,
conclusion, limitations, and any appendix or supplement required by the
argument. Cross-check all layout-sensitive material against the source PDF.

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
machine-readable snapshot beside it. Also return the acquired PDF provenance,
normalization manifest, normalized TeX path and hashes, and conversion warnings.
End with the first concepts to learn, recommended next deep dive, unresolved
terminology, and coverage warnings.

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

- canonical landing/PDF provenance, version, PDF hash, and page count are explicit;
- PDF preprocessing passed the normalization contract before extraction;
- every PDF page was rendered, inspected, and mapped into the normalized TeX;
- no external image command or unresolved transcription marker remains;
- every table, TikZ reconstruction, and described visual object preserves its
  source number/page and claim-relevant semantics;
- normalized TeX compiles and its hash is reported;
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
