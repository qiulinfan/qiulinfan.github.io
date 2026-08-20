## Runtime specifics: Claude Code

- Home directory: `~/.claude`. When `CLAUDE_CONFIG_DIR` is set, it replaces
  `~/.claude` for every path below.
- User Skill directory: `<claude-home>/skills`. Claude Code owns it as a real
  directory; qlblog links each eligible Skill into it individually, and Claude
  Code follows those links when it reads `SKILL.md`.
- Global guidance file: `<claude-home>/CLAUDE.md`, installed as a link to
  `<qlblog>/install/claude/CLAUDE.md`.
- Linker: `<qlblog>/skills/link-claude-skills.sh` on POSIX/WSL, or
  `<qlblog>/skills/link-claude-skills.ps1` on native Windows.
- Scope filter: the Claude linker skips every Skill under
  `<qlblog>/skills/codex-only`, because those Skills drive Codex-native
  subagents or Codex-selected external runtimes and cannot be executed here.
  They stay linked into Codex only. Skills under `<qlblog>/skills/claude-only`
  are exclusive to this runtime and are linked here only. A Skill's name never
  affects scope. Do not hand-link a skipped Skill, and do not widen the filter;
  if a Skill must run under both runtimes, give it a runtime-neutral
  implementation and move it out of the scope directory, and only when the
  user asks for that.
- Claude Code has no generated `.system` Skill directory. Never create,
  simulate, or version-control one for this runtime.
- A personal Skill is invoked by its directory name; frontmatter `name` is only
  the display label. Keep the two identical for every locally maintained Skill.
- Skill precedence is enterprise over personal over project, and plugin Skills
  are namespaced `plugin:skill`, so these links never silently shadow a project
  Skill of a different name.
- Validator: run the Codex `quick_validate.py` named in the Codex runtime
  section when this machine also has Codex installed; otherwise check the
  Skill against the frontmatter and layout contract in
  `<qlblog>/skills/README.md` by hand before reporting success.
