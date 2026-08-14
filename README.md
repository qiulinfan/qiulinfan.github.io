# qiulinfan.github.io

个人知识、内容、稳定 Skills 与网站仓库：

- [`install/`](install/)：可移植的个人工具配置、全局 agent guidance 与安全安装说明。
- [`notes/`](notes/)：Markdown、Typst、LaTeX 权威源与共享渲染工具链；不提交 PDF、课程归档或构建物。
- [`blogs/`](blogs/)：日常知识分享和碎碎念。
- [`skills/`](skills/)：默认的新个人 Skills、稳定工作流与有来源记录的 community Skills。
- [`knowledge/`](knowledge/)：一个本地 kgdistiller 实例的个人配置、决策、私有图谱和已采用静态导出。
- [`site/`](site/)：主页、博客、笔记、Skills 与知识图谱的同一个 Astro 前端。

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

- [`gamemaker`](https://github.com/qiulinfan/gamemaker) 自闭合维护游戏制作、Unity、TA Skills、预制 agents、profiles、linker 与测试。
- [`kgdistiller`](https://github.com/qiulinfan/kgdistiller) 自闭合维护知识引擎、CLI/MCP、论文/笔记 Skills、预制 agents、linker 与测试。

两个产品的开发 checkout 都通过各自 linker，把每个 Skill 直接链接到
`$CODEX_HOME/skills`。因此产品仓中的本地修改会实时反映到 Codex；qlblog 的 linker
只管理 qlblog 自有 Skill，并与产品链接共存。产品迭代本身不会改变网站。只有在明确
采用某个已提交版本时，才由 kgdistiller 重新导出
[`knowledge/export/site/`](knowledge/export/site/)；bundle manifest 记录实际产品 commit
和全部 artifact hashes，这就是 qlblog 的版本锁。

## 网站与部署

开发、检查、构建和 GitHub Pages 只验证并消费已提交静态导出，不 checkout、安装或
运行 kgdistiller，也不需要 submodule：

```sh
make blog-install
make knowledge-check
make blog-check
make blog-build
```

新建博客或本地预览：

```sh
make blog-new NAME=my-first-post
make blog-dev
```

## 显式刷新知识实例

只有知识创作或采用新产品版本时才需要已安装的 kgdistiller CLI：

```sh
make knowledge-build
make knowledge-authoring-check

kgdistiller --repo-root . export site \
  --output knowledge/export/site \
  --product-commit <full-kgdistiller-commit> \
  --source-repository https://github.com/qiulinfan/qiulinfan.github.io \
  --replace
make knowledge-check
```

采用时先把来源、registry 与私有图谱提交为一个 clean qlblog commit，再运行 export；
manifest 会锁定这个 source commit 与实际执行导出的 clean kgdistiller commit。验证通过后，
再用后一个 qlblog commit 提交四文件静态 bundle。dirty checkout 会被拒绝。

实例 authority、public bundle contract 与完整采用流程见
[`knowledge/SPEC.md`](knowledge/SPEC.md) 和
[`knowledge/WORKFLOW.md`](knowledge/WORKFLOW.md)。

## Skill 默认规则

普通新个人 Skill 默认创建在本仓库 `skills/` 顶层并运行
`skills/link-codex-skills.sh`（macOS/Linux/WSL）或
`skills/link-codex-skills.ps1`（原生 Windows）。只有用户明确指定一组
Skills/Workflows 为独立产品时，才把其源码、agents、workflows、测试与 linker 一起
迁入独立仓库，并从 qlblog 删除重复 authority。
