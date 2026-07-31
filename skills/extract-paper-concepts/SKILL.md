---
name: extract-paper-concepts
description: Read a complete academic paper or paper repository and produce a source-grounded, beginner-first inventory of the concepts required to understand it. Use when Codex must extract and prioritize technical concepts from PDF, LaTeX, Markdown, Word, or linked paper sources; build a prerequisite graph or learning order; prepare a handoff for a tutor or a later concept-research task; or explain what a paper assumes a new reader already knows.
---

# Extract Paper Concepts

Read the whole paper before deciding what its key concepts are. Produce a
learning map, not a bag of frequent words.

## Default audience and language

- Assume the learner has no background in the paper's field unless the user
  states otherwise.
- Write explanations in the user's language.
- Preserve the canonical English name for every concept so it can be searched
  later.
- Define notation only to identify a concept. Leave full teaching to a
  follow-up task such as `$trace-concept-lineage`.

## 1. Establish the source boundary

1. Identify the canonical paper and all files that contribute to it.
2. Read the title, abstract, every main-text section, theorem or proposition,
   equations central to the argument, figure and table captions, conclusion,
   limitations, and appendices or supplements that contain required arguments.
3. For LaTeX, resolve `\input`, `\include`, bibliography, and custom notation
   files. For a PDF, extract all pages and visually inspect pages where
   equations, diagrams, or extraction quality matter. Use the appropriate
   document or PDF tooling when available.
4. Treat project notes and references as supporting context; clearly
   distinguish them from claims present in the paper.
5. Record what was and was not read. Never infer the paper's full concept set
   from only its abstract, introduction, filename, or citation list.

If there are multiple drafts and the current version is not discoverable,
state the ambiguity before selecting one.

## 2. Build candidates in two passes

### Pass A: argument skeleton

Summarize the paper as:

`problem -> setup -> mechanism -> main result -> evidence -> limitations`

This skeleton determines which concepts are central.

### Pass B: concept candidates

Collect concepts from:

- prerequisites in mathematics, statistics, and the application domain;
- objects being modeled;
- mechanisms or algorithms;
- architectural or modeling assumptions;
- theorem machinery and proof ideas;
- objectives, metrics, and experimental controls;
- distinctions the authors rely on, including easily confused neighboring
  concepts.

A concept is a reusable idea with explanatory content. Do not promote a local
symbol, author name, dataset name, section heading, or generic word such as
"model" into a concept unless understanding it is independently necessary.
Merge aliases and singular/plural variants.

Keep entries atomic enough to become the input to one later deep dive. As a
test, the canonical English title should normally work as one focused search
query. Split a title joined by "and" when its parts have different definitions,
mechanisms, or prerequisite paths. Retain a compound only when it is an
established unit or when splitting it would create meaningless fragments.

## 3. Select at the right granularity

Score each candidate from 0 to 2 on:

- **centrality**: removing it breaks the paper's main argument;
- **prerequisite value**: later concepts depend on it;
- **recurrence**: it matters in more than one part of the paper;
- **beginner surprise**: the paper assumes knowledge a novice is unlikely to
  have.

Prefer concepts scoring at least 4, then add any low-scoring prerequisite
needed to make the map teachable. Normally keep 15–35 concepts for a full
paper. Use fewer for a short note and more only when the paper truly spans
several fields. Do not bundle several foundations merely to stay under the
range.

Balance the final inventory across:

1. foundations;
2. field-level concepts;
3. mechanisms and algorithms;
4. paper-specific constructions and results;
5. assumptions, metrics, and scope boundaries.

Split an entry when its parts need different prerequisite paths. Merge entries
when a novice could not meaningfully learn them separately.

## 4. Ground every entry

For each selected concept:

- give it a stable ID such as `C01`;
- provide canonical English name, user-language name, and aliases;
- explain it in one plain-language sentence;
- state exactly why it is needed in this paper;
- cite section, equation, theorem, figure, page, or source-file location;
- list only direct prerequisite IDs;
- label importance as `core`, `supporting`, or `boundary`;
- label evidence as `explicit`, `implicit prerequisite`, or `paper-specific`;
- record uncertainty instead of inventing a definition.

Do not use outside knowledge to silently change the authors' meaning. If the
paper uses a term nonstandardly, record both the paper-local meaning and the
standard meaning as an ambiguity.

## 5. Construct the learning graph

Create directed edges `prerequisite -> dependent`. An edge means the learner
should understand the source concept first in order to learn the target
concept. Do not encode section order, causal order inside the paper, or the
fact that one paper result uses another as a learning prerequisite. Those
relations belong in each concept's `Role in this paper` and in the argument
skeleton.

Keep only edges necessary for teaching, remove redundant shortcuts, and ensure
the graph is acyclic. Check apparently inverted edges explicitly: foundational
mathematics or an ODE/SDE normally precedes the paper-specific model that uses
it. Give a topological learning order grouped into short stages.

Pay special attention to distinctions that beginners commonly collapse. Add a
contrast note when two concepts are related but not interchangeable.

## 6. Deliver the inventory

Follow [references/inventory-contract.md](references/inventory-contract.md)
exactly. Use its compact table for scanning and its concept cards for the
handoff.

If the user requests a reusable artifact or another agent will consume the
result, save it to the user-specified path. Otherwise use
`<paper-root>/learning/<paper-stem>-concepts.md` when repository writes are
authorized, or return the complete inventory in the response.

End with:

- the 3–5 concepts that should be taught first;
- the single concept recommended for the next deep dive and why;
- unresolved terminology or missing-source warnings.

## Quality gate

Before delivering, verify:

- source coverage is explicit and complete;
- every core claim in the argument skeleton maps to at least one concept;
- every concept has local evidence and a paper-specific role;
- aliases are merged and neighboring terms are distinguished;
- each entry is focused enough for one later concept-research task;
- all prerequisite IDs exist and the graph has no cycle;
- prerequisite edges express learning order rather than paper narrative order;
- the learning order introduces notation only after its prerequisites;
- the inventory is useful to a complete beginner, not merely accurate for an
  expert;
- no concept card pretends to be a full tutorial.
