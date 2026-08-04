---
name: ingest-kgdistiller
description: Apply a reviewed, source-backed knowledge update to a kgdistiller project and return a validation receipt. Use after query-kgdistiller or another extractor has already decided identities, authority markers, refs, entries, aliases, and direct semantic edges; when changed Markdown, Typst, or LaTeX knowledge must enter the personal graph; when an explicitly selected paper concept must be imported with provenance; or when a reviewed cross-namespace alignment must be persisted.
---

# Ingest into kgdistiller

This is qlblog's discovery entry for the Skill shipped with its kgdistiller
submodule. From the repository root, read
`vendor/kgdistiller/skills/ingest-kgdistiller/SKILL.md` completely and follow it.

If that file is absent, stop and initialize or update `vendor/kgdistiller`.
Never reconstruct the write workflow from qlblog graph files or from memory.
