# qlblog agent guidance

- Preserve the `notes/`, `blogs/`, `skills/`, and `site/` separation documented in `README.md`.
- The reusable knowledge graph engine is the `vendor/kgdistiller` Git submodule tracking `main`; personal sources, registry, graph snapshots, skills, and site integration remain in this repository.
- `skills/` is the authority for locally maintained personal and community Skills. Keep existing suite directories such as `gamemaker/`, `kgdistiller/`, and `notes/`, but never infer a classification from a Skill's topic or relationships: create new personal Skills at the top level, and create a suite or move/place Skills into one only when the user explicitly requests that exact classification. Downloaded open-source Skills follow the already established `community/` convention and must stay out of the website. After every reclassification or parent-directory move under `skills/`, rerun `skills/link-codex-skills.sh`. Codex receives all visible Skills as a flat set of per-Skill local symlinks. `query-kgdistiller` and `ingest-kgdistiller` are thin discovery entries whose canonical instructions travel with `vendor/kgdistiller`.
- Codex-generated system Skills belong only under `$CODEX_HOME/skills/.system`; never copy, symlink, customize, publish, or version-control that directory in this repository.
- The version-controlled source for personal global Codex guidance is `install/codex/AGENTS.md`; install it as `$CODEX_HOME/AGENTS.md` with `skills/link-codex-skills.sh` after cloning or moving the repository.
- Run `git submodule update --init vendor/kgdistiller` before knowledge commands in a fresh checkout. CI and ordinary work use the committed engine revision; `make kgdistiller-update` is the explicit upgrade path.
- Blog source lives in `site/src/content/posts/` and is exposed through `blogs/posts/`.
- Validate blog changes with `make blog-check` and `make blog-build`.
- When the user asks to install or update AI agents, read `install/agent-stack.md` completely and follow its safety contract.
- Never install a persistent daemon, gateway, scheduled task, messaging integration, or self-hosted service without explicit confirmation.
- Never place credentials in the repository or command output.
