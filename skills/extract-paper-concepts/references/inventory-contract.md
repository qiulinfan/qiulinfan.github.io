# Federated paper inventory contract

Use this structure for the complete paper deliverable. Query the external brain
before writing sections 5 and 6.

## 1. Source and coverage

- Paper title, authors, version/date, DOI or arXiv ID, canonical landing URL,
  final PDF URL, access date, PDF page count, and PDF SHA-256
- PDF preflight manifest path, normalized TeX path, TeX SHA-256, and whether an
  official source archive assisted transcription
- Counts of OCR/visual-transcription pages, native LaTeX tables, TikZ/PGFPlots
  objects, text-described visual objects, and unresolved conversion warnings
- Sections, appendices, supplements, equations, tables, figures, and notes read
- Missing or ambiguous material
- Intended learner level and output language
- Candidate and target graph/snapshot digests

Do not proceed when a core claim or prerequisite depends on an unresolved PDF
transcription warning. Every cited paper location must include the original PDF
page and, when available, its theorem/equation/table/figure label; machine
records should also retain the normalized TeX line or span.

## 2. Paper in one argument

Write five to eight sentences following:

`problem -> setup -> mechanism -> main result -> evidence -> limitations`

Do not teach individual concepts here.

## 3. Candidate index

Use one row per paper candidate:

| ID | Canonical English term | User-language term | Type | Importance | Direct prerequisites | First PDF/TeX source location |
|---|---|---|---|---|---|---|

Allowed types: `foundation`, `field`, `mechanism`, `paper-specific`, `metric`,
and `assumption-boundary`.

Allowed importance values: `core`, `supporting`, and `boundary`.

## 4. External-brain comparison

Use one row per candidate:

| Candidate | Status | Personal node | Bridge | Missing/conflicting material | Identity evidence |
|---|---|---|---|---|---|

Allowed statuses are `known`, `partial`, `new`, `conflict`, and `uncertain`.
Only identity-authoritative evidence may create an `exact-match` bridge.

## 5. Learning stages and federated graph

Group all candidate IDs into a topological learning order. Known candidates
remain in the route because the paper uses them, even though they receive no
new entry.

Render the paper prerequisite graph using `prerequisite -> dependent`, then
list machine-readable paper edges. List bridges separately:

```text
paper:C01 prerequisite-for paper:C04
paper:C01 exact-match personal:measure-space
```

Never reinterpret a bridge as a personal semantic edge.

## 6. Status-sensitive records

### Known candidate

Do not write a definition, plain-language anchor, or concept explanation.

```markdown
### C01 — Canonical term / user-language term — known

- Personal node:
- Bridge:
- Role in this paper:
- Paper source locations:
```

### Partial candidate

Explain only what is absent from the personal node.

```markdown
### C02 — Canonical term / user-language term — partial

- Personal node and bridge:
- Known coverage:
- Missing condition, role, claim, or relation:
- Why the gap matters in this paper:
- Paper source locations:
```

### New candidate

```markdown
### C03 — Canonical term / user-language term — new

- Aliases:
- Type and importance:
- Evidence: explicit | implicit prerequisite | paper-specific
- Plain-language anchor:
- Role in this paper:
- Direct prerequisites:
- Source locations:
- Often confused with:
- Open ambiguity:
```

### Conflict or uncertain candidate

Do not create an entry or bridge. Record the competing claims or candidate
senses, their provenance, and the evidence required for review.

## 7. Handoff

- First concepts to learn
- Recommended next deep dive and reason
- New/partial concepts eligible for an explicitly requested import
- Known concepts that will become refs during import
- Terms requiring review or author clarification
- Coverage or extraction warnings

## Selection audit

Confirm that every main claim has a matching candidate, every candidate is
actually used or necessarily assumed, names are searchable, prerequisite edges
form a DAG, known entries are not duplicated, partial records contain only the
gap, and the default deliverable does not mutate the personal graph.
