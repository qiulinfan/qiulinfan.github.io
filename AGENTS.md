# qlblog agent guidance

- Preserve the `notes/`, `blogs/`, `skills/`, and `site/` separation documented in `README.md`.
- The reusable knowledge graph engine is the `vendor/kgdistiller` Git submodule tracking `main`; personal sources, registry, graph snapshots, skills, and site integration remain in this repository.
- `skills/` is the only authority for every locally maintained Skill. Codex and sibling tool repositories consume those skills through local symlinks.
- Run `git submodule update --init vendor/kgdistiller` before knowledge commands in a fresh checkout. CI and ordinary work use the committed engine revision; `make kgdistiller-update` is the explicit upgrade path.
- Blog source lives in `site/src/content/posts/` and is exposed through `blogs/posts/`.
- Validate blog changes with `make blog-check` and `make blog-build`.
- When the user asks to install or update AI agents, read `install/agent-stack.md` completely and follow its safety contract.
- Never install a persistent daemon, gateway, scheduled task, messaging integration, or self-hosted service without explicit confirmation.
- Never place credentials in the repository or command output.
