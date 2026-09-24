# qlblog agent guidance

This is the development runbook for agents working in this repository.
`README.md` belongs to the owner and is written for readers: edit it only when
the owner asks, and keep development documentation here.

## Rules

- Preserve the `blogs/` and `site/` separation documented in `README.md`.
- Content from other repositories reaches the site only as docks: `docks.json` registers each dock's public repository, ref, and checkout path, and `site/src/docks/<id>/` holds its adapter (pages, build steps, tests). Never copy dock content into this repository. The `notes` dock (`qiulinfan/notes`) is the authority for notes and the personal kgdistiller instance; never run kgdistiller during a site or Pages build.
- Machine setup (tool configs, the AI agent stack) and the personal global agent guidance live in the private `myrunbook` repository, not here.
- Personal Skills are not maintained here. The private `myskills` repository is their authority and links them into Codex and Claude Code; its `manage-skills` Skill holds the maintenance protocol. Products such as `autoTA`, `kgdistiller`, and `discrete-sprite-lab` present their own Skills, and the site does not list Skills.
- Blog source lives in `site/src/content/posts/` and is exposed through `blogs/posts/`.
- Validate blog changes with `make blog-check` and `make blog-build`.
- Never place credentials in the repository or command output.

## Layout

- `blogs/posts/`: blog posts in Markdown or MDX; the directory maps to Fuwari's
  post source directory.
- `site/`: the Astro site built on [Fuwari](https://github.com/saicaca/fuwari):
  homepage, blog, Works, Playground, and dock sections. Fuwari's MIT license is
  kept in `site/FUWARI-LICENSE`.
- `docks.json`: the dock registry.
- This repository (`qiulinfan/qiulinfan.github.io`) deploys the user root site
  `https://qiulinfan.github.io/`.

## Writing a blog post

From the repository root:

```sh
make blog-new NAME=my-first-post
make blog-dev
```

Edit `blogs/posts/my-first-post.md` and preview at <http://localhost:4321/>.
Front matter:

```yaml
---
title: 文章标题
published: 2026-07-13
description: 一句话摘要
image: ""
tags: [标签]
category: 分类
draft: false
lang: zh_CN
---
```

Then run `make blog-check` and `make blog-build`; the static output lands in
`site/dist/`.

## Site

- `site/src/styles/variables.styl` is the only source of visual tokens: colors,
  text levels, radii, shadows, and surface semantics. Components consume its
  CSS variables and never define another light/dark palette.
- `site/src/components/GlobalStyles.astro` is the only place that assembles
  global styles; import any new global style file there.
- Where things live:
  - `site/src/config.ts`: site name, author, navigation, and license.
  - `site/astro.config.mjs`: site URL and Markdown plugins.
  - `site/src/content/spec/about.md`: the About page.
  - `site/public/`: files published as-is, such as the favicon.
  - `site/src/assets/`: images processed by Astro.
  - `site/src/components/home/`: the homepage and the Works and Playground
    pages.
  - `site/src/data/home.ts`: Works entries (serious work, later research) and
    Playground entries (games and small tools).

## Docks

Sections beyond the homepage come from other repositories. `docks.json`
registers each dock's public repository, ref, and local checkout;
`site/src/docks/<id>/` is its adapter (pages, build steps, tests), and
`site/src/docks/integration.ts` injects its routes and runs its steps around the
build. Only the `notes` dock exists today.

- Local development reads the working copy at the checkout path (`../notes`),
  so changes preview without a push. `make docks-bootstrap` shallow-clones a
  missing checkout together with its submodules.
- `astro build` runs each adapter's build steps. The notes adapter runs
  `make web` in the notes repository to build its standalone Typst pages, so
  the machine needs the Typst version pinned in the notes `Makefile`.
- Every build writes each dock's commit to `docks.json` at the site root, so
  the deployed version can be checked.
- When the notes repository's `main` passes its own checks, its CI triggers
  this repository's Pages workflow.
- `knowledge/sources.json` in the notes repository is the authority for the
  `web` address of every note and knowledge node; `/notes/` and the homepage's
  note entries read only that registry. Each source sets `publish` (whether its
  page is built) and `listed` (whether it appears in public listings), and
  `listed: true` requires `publish: true`; neither affects local knowledge
  ingestion. Pages compiled outside Astro, such as Typst, declare their outputs
  in `web_artifacts`: `astro build` first runs the notes `make web`, then
  installs only the artifacts of `publish: true` sources. The site publishes no
  knowledge-graph pages or JSON endpoints; the adopted bundle's `graph.json` is
  only an internal build record.
- To add a section: once its repository is public, add a row to `docks.json`,
  write the adapter in `site/src/docks/<id>/`, and add a navigation entry in
  `site/src/config.ts`.

## Build and deploy

Checks, builds, and GitHub Pages read only committed dock content; they never
check out, install, or run kgdistiller.

```sh
make docks-bootstrap
make blog-install
make blog-check
make blog-build
```

A push to `main` deploys through `.github/workflows/pages.yml`.

## Products

`autoTA` and `kgdistiller` are independent product repositories with their own
Skills, agents, workflows, installers, and tests; nothing of theirs is mirrored
here. Product changes never change the site by themselves: the knowledge graph
changes only when the notes repository adopts a committed kgdistiller version
and re-exports `knowledge/export/site/`, whose bundle manifest pins the product
commit and every artifact hash.

## Obsidian vault

The repository root is an Obsidian vault usable on macOS, Windows, and Linux.
`.obsidian/` commits app settings, hotkeys, the enabled plugin list, and
credential-free plugin settings; open the root with **Open folder as vault**.
Each machine must trust the vault and allow community plugins, then install
`Completr`, `Quick Latex`, and `YOLO` from the official community plugin
browser; plugin code is not committed. YOLO's `data.json`, OAuth tokens, and
`YOLO/` state are git-ignored and hold credentials: never force them into Git.
