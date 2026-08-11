# Personal Codex guidance

## General engineering defaults

Apply these defaults only when the user's request and closer project guidance
do not specify otherwise:

- Choose the simplest coherent implementation that fully satisfies the current
  requirements. Avoid speculative abstractions, configuration layers, and
  indirection.
- Deliver non-trivial systems in working end-to-end slices. Add capabilities on
  top of a runnable baseline; do not replace verified behavior with unfinished
  complexity.
- Keep components cohesive and concerns separated, but do not create
  abstractions or layers without a concrete responsibility.
- Before adding a dependency or reimplementing common functionality, inspect
  the project's existing dependencies and consult their current documentation
  and types. Prefer established, well-maintained libraries when they reduce
  total complexity or improve reliability.
- For consequential or hard-to-reverse design decisions, inspect the
  repository's existing patterns and, when useful, established products or
  reference implementations before inventing a custom approach.
- Prefer durable architectural choices. When a temporary stopgap is necessary,
  make the trade-off explicit, bound its scope, and record the condition for
  removing it.
- Do not add compatibility layers, fallbacks, or migrations by default. First
  determine whether users, persisted data, public interfaces, or deployment
  constraints require compatibility; never remove or break them without clear
  scope and authorization.

## Personal Skill maintenance

When using the built-in `skill-creator`, or when creating or materially
updating a personal or community Skill, apply this protocol in addition to the
active Skill's own instructions:

- Treat the visible `skills/` directory in the qlblog checkout that owns this
  tracked file as the default authoritative personal Skill store. Locate that
  checkout from a qlblog-owned Skill link in `$CODEX_HOME/skills` and walk up to
  its repository `skills/` root; on platforms where `$CODEX_HOME/AGENTS.md` is a
  symbolic link, its target is an equivalent locator. A Windows linker may use
  a same-volume hard link for this file when symbolic-link permission is
  unavailable, so do not infer the checkout from that file alone. If no linked
  qlblog Skill resolves to one unambiguous checkout, stop and ask for its new
  location instead of creating an untracked Skill elsewhere.
- Initialize every new personal Skill at the top level of `<qlblog>/skills`.
  Preserve existing suite directories, but never infer categorization from a
  Skill's topic, name, dependencies, or apparent system membership. Create a
  suite or move/place Skills into any suite only when the user explicitly asks
  for that exact classification. Put downloaded open-source Skills under the
  already established `community/` convention, which Codex may discover but
  qlblog must not publish. Then run
  `<qlblog>/skills/link-codex-skills.sh` on POSIX/WSL or
  `<qlblog>/skills/link-codex-skills.ps1` on native Windows; it exposes both top-level and suite
  Skills as a flat set of individually linked entries in Codex's user Skill
  directory.
- When the user explicitly promotes a Skill/workflow series into an independent
  product, that product repository becomes its only authority. Keep its Skills,
  workflows, agents, tests, and linker together there; remove qlblog mirrors.
  The current promoted products are `gamemaker` and `kgdistiller`. Run each
  product's own linker so local edits are visible immediately; qlblog's linker
  must neither manage nor remove links owned by those product checkouts.
- After every reclassification or other parent-directory move under
  `<qlblog>/skills`, rerun the platform-appropriate qlblog linker immediately so
  stale links are removed and the flat Codex view is rebuilt. Do not report the
  reclassification complete until that command succeeds.
- Before changing a visible Skill, read `<qlblog>/skills/README.md` and
  `<qlblog>/skills/WORKFLOWS.md` when present.
- Write frontmatter descriptions and `agents/openai.yaml` discovery metadata
  for locally maintained personal Skills in English so the collection remains
  portable across users. Preserve upstream metadata for downloaded community
  Skills unless the user explicitly requests a local adaptation.
- Include an explicit language-alignment rule in every new or materially
  updated personal Skill: user-facing explanations, prompts, and handoffs must
  match the user's language unless the user requests another language. Keep
  commands, identifiers, structured keys/action codes, and raw errors unchanged.
- Keep the collection catalog accurate. Update a Skill's README entry only
  when its purpose, triggers, scope, name, provenance, or other user-visible
  behavior changed; do not create churn. For imported, installed, or adapted
  Skills, record a precise upstream source and distinguish local modifications.
- Keep workflow documentation accurate when a Skill's role, inputs, outputs,
  ordering, boundaries, failure behavior, or links change. Do not edit an
  already accurate workflow merely to create churn.
- Honor catalog exclusions and the rule against auxiliary README files inside
  individual Skill directories.
- Treat `$CODEX_HOME/skills/.system` (default `~/.codex/skills/.system`) as
  Codex-generated state. Never copy, link, customize, publish, or
  version-control it in qlblog.
- Validate every created or materially changed Skill with the active
  `skill-creator` validator, run `git diff --check`, and inspect the qlblog Git
  diff before reporting success.
