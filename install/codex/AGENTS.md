# Personal Codex guidance

## Personal Skill maintenance

When using the built-in `skill-creator`, or when creating or materially
updating a personal or community Skill, apply this protocol in addition to the
active Skill's own instructions:

- Treat the visible `skills/` directory in the qlblog checkout that owns this
  tracked file as the authoritative personal Skill store. The installed global
  file should be a link to `<qlblog>/install/codex/AGENTS.md`; resolve that link
  to locate the checkout. If the checkout moved or cannot be resolved, stop and
  ask for its new location instead of creating an untracked Skill elsewhere.
- Initialize new personal Skills directly under `<qlblog>/skills`, then run
  `<qlblog>/skills/link-codex-skills.sh` so Codex discovers the new directory.
- Before changing a visible Skill, read `<qlblog>/skills/README.md` and
  `<qlblog>/skills/WORKFLOWS.md` when present.
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
