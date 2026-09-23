# qiulinfan.github.io

个人主页、博客、稳定 Skills 与网站仓库：

- [`install/`](install/)：可移植的个人工具配置、Codex 与 Claude Code 的全局 agent guidance 与安全安装说明。
- [`blogs/`](blogs/)：日常知识分享和碎碎念。
- [`skills/`](skills/)：默认的新公开个人 Skills 与稳定工作流；两份 registry 分别声明站点展示的
  自有公开仓库，以及只供本地 linking 的私有/第三方仓库，外部 Skill 内容都留在各自 authority。
- [`docks.json`](docks.json)：网站挂载的外部仓库（dock）登记表。
- [`site/`](site/)：主页、博客、Works、Playground、Skills 与各 dock 栏目的 Astro 前端。

笔记与知识图谱在独立仓库 [`notes`](https://github.com/qiulinfan/notes)，作为 `notes` dock
发布在 `/notes/`。

## Obsidian Vault

仓库根目录本身就是可跨 macOS、Windows 与 Linux 打开的 Obsidian Vault。
`.obsidian/` 中提交应用设置、快捷键、启用的插件列表和不含凭据的插件设置，
因此 clone 后用 Obsidian 的 **Open folder as vault** 选择仓库根目录即可复用配置。
首次打开时仍需由用户确认信任 Vault 并允许 community plugins；这是 Obsidian 的本机安全边界。

Windows 上的基本流程：

```powershell
git clone https://github.com/qiulinfan/qiulinfan.github.io.git
cd qiulinfan.github.io
```

随后在 Windows 版 Obsidian 中打开这个目录，并在官方 community plugin browser 安装、启用
`Completr`、`Quick Latex` 和 `YOLO`。插件程序由官方市场按机器安装，不在本仓库重复发布；
安装完成后，仓库中的 Completr、Quick Latex 设置和全局快捷键会直接生效。YOLO 的
`data.json`、OAuth token 与 `YOLO/` 运行状态被 `.gitignore` 明确排除，所以每台机器必须
单独填写 API key 或重新 OAuth 登录。普通 Vault 内容与可移植设置继续通过
`git pull` / `git push` 同步，不要把任何机器上的 YOLO 凭据强制加入 Git。

## 独立 workflow 产品

高频迭代的 workflow series 不在本仓库镜像：

- [`autoTA`](https://github.com/qiulinfan/autoTA) 自闭合维护技术美术(TA)管线:素材搜索/2D/3D/托管生成/绑定对齐 Skills、预制 agents、profile、linker 与测试(2026-08 由 gamemaker 改名并专精)。
- [`kgdistiller`](https://github.com/qiulinfan/kgdistiller) 自闭合维护知识引擎、CLI/MCP、论文/笔记 Skills、预制 agents、linker 与测试。

两个产品的开发 checkout 都通过各自 linker，把每个 Skill 直接链接到
`$CODEX_HOME/skills`。因此产品仓中的本地修改会实时反映到 Codex；qlblog 的 linker
只管理 qlblog 自有 Skill，并与产品链接共存。产品迭代本身不会改变网站。只有在 notes
仓库明确采用某个已提交版本时，才由 kgdistiller 重新导出它的 `knowledge/export/site/`；
bundle manifest 记录实际产品 commit 和全部 artifact hashes，这就是知识图谱的版本锁。

## Docks

主页之外的栏目来自其他仓库。[`docks.json`](docks.json) 登记每个 dock 的公开仓库、分支和
本地 checkout 位置；`site/src/docks/<id>/` 是它的 adapter，包含页面、构建步骤和测试，
由 `site/src/docks/integration.ts` 注入路由。当前只有 `notes` dock。

- 本地开发直接读取 checkout 位置上的工作副本（`../notes`），改完不用 push 就能预览。
  缺失的 checkout 由 `make docks-bootstrap` 浅克隆，连同递归的 submodule。
- `astro build` 运行各 adapter 的构建步骤；notes adapter 会调用 notes 仓库的 `make web`
  生成独立 Typst 页面，因此本机需要 notes `Makefile` 中固定版本的 Typst。
- 每次构建把各 dock 的 commit 写入站点根目录的 `docks.json`，可以核对线上版本。
- notes 仓库 push 到 `main` 并通过自身检查后，触发本仓库的 Pages workflow 重新部署。

新增栏目：仓库公开后在 `docks.json` 加一行，在 `site/src/docks/<id>/` 写 adapter，
在 `site/src/config.ts` 加导航项。

## 网站与部署

开发、检查、构建和 GitHub Pages 只读取 dock 中已提交的内容，不 checkout、安装或
运行 kgdistiller：

```sh
make agents-check
make docks-bootstrap
make blog-install
make blog-check
make blog-build
```

新建博客或本地预览：

```sh
make blog-new NAME=my-first-post
make blog-dev
```

## Skill 默认规则

普通新公开个人 Skill 默认创建在本仓库 `skills/` 顶层，然后为本机装了的每个运行时运行
对应 linker。只有用户明确指定一组 Skills/Workflows 为独立产品时，才把其源码、
agents、workflows、测试与 linker 一起迁入独立仓库，并从 qlblog 删除重复 authority。

| 运行时 | 全局 guidance | Skill 目录 | macOS/Linux/WSL | 原生 Windows |
| --- | --- | --- | --- | --- |
| Codex | `$CODEX_HOME/AGENTS.md` | `$CODEX_HOME/skills` | `skills/link-codex-skills.sh` | `skills\link-codex-skills.ps1` |
| Claude Code | `~/.claude/CLAUDE.md` | `~/.claude/skills` | `skills/link-claude-skills.sh` | `skills\link-claude-skills.ps1` |

两个 linker 都只逐 Skill 链接到目标运行时自己拥有的真实目录，互不干扰，也不动
`autoTA`、`kgdistiller` 等独立产品自己建立的链接。Claude Code 的 home 可以用
`CLAUDE_CONFIG_DIR` 覆盖，Codex 的用 `CODEX_HOME`。

Claude Code 侧有一条额外的作用域规则：任何 authority 的 `codex-only/` 目录都会被跳过；
该作用域用于依赖 Codex 专属能力的 Skill，只链接进 Codex。
不要手工补链，也不要放宽过滤器。

两个运行时的全局 guidance 共享同一份权威 `install/agents/core.md`，各自只维护一份
运行时增量；改完任意一份都要运行 `make agents-guidance` 重新生成
`install/codex/AGENTS.md` 与 `install/claude/CLAUDE.md`，`make agents-check` 校验是否已同步。
