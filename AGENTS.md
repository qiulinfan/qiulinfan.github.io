# qlblog agent guidance

- Preserve the `blogs/` and `site/` separation documented in `README.md`.
- Content from other repositories reaches the site only as docks: `docks.json` registers each dock's public repository, ref, and checkout path, and `site/src/docks/<id>/` holds its adapter (pages, build steps, tests). Never copy dock content into this repository. The `notes` dock (`qiulinfan/notes`) is the authority for notes and the personal kgdistiller instance; never run kgdistiller during a site or Pages build.
- Machine setup (tool configs, the AI agent stack) and the personal global agent guidance live in the private `myrunbook` repository, not here.
- Personal Skills are not maintained here. The private `myskills` repository is their authority and links them into Codex and Claude Code; its `manage-skills` Skill holds the maintenance protocol. Products such as `autoTA`, `kgdistiller`, and `discrete-sprite-lab` present their own Skills, and the site does not list Skills.
- Blog source lives in `site/src/content/posts/` and is exposed through `blogs/posts/`.
- Validate blog changes with `make blog-check` and `make blog-build`.
- Never place credentials in the repository or command output.
