# qlblog agent guidance

- Preserve the `blogs/`, `install/`, and `site/` separation documented in `README.md`.
- Content from other repositories reaches the site only as docks: `docks.json` registers each dock's public repository, ref, and checkout path, and `site/src/docks/<id>/` holds its adapter (pages, build steps, tests). Never copy dock content into this repository. The `notes` dock (`qiulinfan/notes`) is the authority for notes and the personal kgdistiller instance; never run kgdistiller during a site or Pages build.
- Personal Skills are not maintained here. The private `myskills` repository is their authority and links them into Codex and Claude Code; its `manage-skills` Skill holds the maintenance protocol. Products such as `autoTA`, `kgdistiller`, and `discrete-sprite-lab` present their own Skills, and the site does not list Skills.
- Personal global agent guidance has one runtime-neutral authority, `install/agents/core.md`, plus one delta per runtime (`install/codex/runtime.md`, `install/claude/runtime.md`). `install/codex/AGENTS.md` and `install/claude/CLAUDE.md` are generated from those three files and committed; never edit them by hand. Run `make agents-guidance` after changing a source and `make agents-check` to verify. `install/README.md` gives the one-time commands that link each generated file into its runtime home.
- Blog source lives in `site/src/content/posts/` and is exposed through `blogs/posts/`.
- Validate blog changes with `make blog-check` and `make blog-build`.
- When the user asks to install or update AI agents, read `install/agent-stack.md` completely and follow its safety contract.
- Never install a persistent daemon, gateway, scheduled task, messaging integration, or self-hosted service without explicit confirmation.
- Never place credentials in the repository or command output.
