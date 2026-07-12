# qlblog agent guidance

- Preserve the `notes/`, `blogs/`, `skills/`, and `site/` separation documented in `README.md`.
- Blog source lives in `site/src/content/posts/` and is exposed through `blogs/posts/`.
- Validate blog changes with `make blog-check` and `make blog-build`.
- When the user asks to install or update AI agents, read `install/agent-stack.md` completely and follow its safety contract.
- Never install a persistent daemon, gateway, scheduled task, messaging integration, or self-hosted service without explicit confirmation.
- Never place credentials in the repository or command output.
