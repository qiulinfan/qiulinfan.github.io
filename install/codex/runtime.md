## Runtime specifics: Codex

- Home directory: `$CODEX_HOME`, default `~/.codex`.
- User Skill directory: `$CODEX_HOME/skills`. Codex owns it as a real directory;
  qlblog links each Skill into it individually.
- Global guidance file: `$CODEX_HOME/AGENTS.md`, installed as a link to
  `<qlblog>/install/codex/AGENTS.md`.
- Linker: `<qlblog>/skills/link-codex-skills.sh` on POSIX/WSL, or
  `<qlblog>/skills/link-codex-skills.ps1` on native Windows.
- Scope filter: the Codex linker skips every Skill under
  `<qlblog>/skills/claude-only`, because those Skills depend on Claude
  Code-only capabilities. They stay linked into Claude Code only. Skills under
  `<qlblog>/skills/codex-only` (the Codex-native subagent and test Skills) are
  exclusive to this runtime and are linked here only. A Skill's name never
  affects scope.
- Treat `$CODEX_HOME/skills/.system` as Codex-generated state. Never copy, link,
  customize, publish, or version-control it in qlblog, and never create a
  `.system` directory inside `<qlblog>/skills`.
- Validator:
  `python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py" <skill-dir>`
  (`py -3` on Windows without a `python3` command).
- The built-in `skill-creator` Skill must follow this protocol in addition to
  its own instructions.
