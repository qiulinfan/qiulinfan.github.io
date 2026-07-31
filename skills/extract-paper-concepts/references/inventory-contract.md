# Concept inventory contract

Use this structure for a complete deliverable.

## 1. Source and coverage

- Paper title and version
- Source files or URL
- Sections, appendices, supplements, figures, and notes read
- Missing or ambiguous material
- Intended learner level and output language

## 2. Paper in one argument

Write five to eight sentences following:

`problem -> setup -> mechanism -> main result -> evidence -> limitations`

Do not teach individual concepts yet.

## 3. Concept index

Use one row per concept:

| ID | Canonical English term | User-language term | Type | Importance | Direct prerequisites | First source location |
|---|---|---|---|---|---|---|

Allowed types: `foundation`, `field`, `mechanism`, `paper-specific`,
`metric`, `assumption-boundary`.

Allowed importance values: `core`, `supporting`, `boundary`.

## 4. Learning stages

Group concept IDs into a topological learning order. Give each stage a one-line
learning goal. Prefer three to six stages with two to six concepts per stage.

## 5. Prerequisite graph

Render a Mermaid `flowchart LR` using `prerequisite --> dependent`. Keep labels
short and quote labels containing punctuation. Follow it with an edge list so
the graph remains machine-readable:

```text
C01 prerequisite-for C04
C02 prerequisite-for C04
```

Every edge must pass this test: "A complete beginner should understand the
source before starting a focused lesson on the target." Do not use the graph
for the paper's section order or proof-dependency order; the argument summary
and `Role in this paper` fields carry those relationships.

## 6. Concept cards

For every concept, use:

```markdown
### C01 — Canonical English term / user-language term

- Aliases:
- Type:
- Importance:
- Evidence: explicit | implicit prerequisite | paper-specific
- Plain-language anchor:
- Role in this paper:
- Direct prerequisites:
- Source locations:
- Often confused with:
- Open ambiguity:
```

The plain-language anchor is one or two sentences, not a full tutorial. The
role must name the part of the paper that would become unintelligible without
the concept.

## 7. Handoff

- First concepts to teach
- Recommended next deep dive and reason
- Terms that require author clarification
- Coverage or extraction warnings

## Selection audit

Before delivery, confirm:

- Each main claim in the argument summary has a matching concept.
- Each selected concept is actually used or necessarily assumed.
- No entry is merely a symbol or a broad filler word.
- Each entry can normally serve as one focused search or lesson topic.
- Direct prerequisite edges form a DAG.
- Prerequisite edges describe learning order, not merely narrative order.
- Canonical English terms are searchable.
- Paper-local meanings are separated from standard meanings.
