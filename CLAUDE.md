# qlblog guidance for Claude Code

Read and follow `AGENTS.md` for repository conventions.

Personal global Claude Code guidance for this machine lives at `~/.claude/CLAUDE.md`
(or `$CLAUDE_CONFIG_DIR/CLAUDE.md`), installed as a link to the generated
`install/claude/CLAUDE.md`. That file is built from `install/agents/core.md` plus
`install/claude/runtime.md`; edit those sources and run `make agents-guidance`
instead of editing the generated file.

Personal Skills live in the private `myskills` repository, whose linker installs
them into `~/.claude/skills`; its `manage-skills` Skill holds the maintenance
protocol.

For AI-agent installation or updates, read `install/agent-stack.md` completely before
proposing or running commands. Obtain separate explicit confirmation before installing
persistent daemons, gateways, messaging integrations, scheduled jobs, or self-hosted
services.
