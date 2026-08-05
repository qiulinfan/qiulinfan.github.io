# Skills

本目录是个人领域 skills 的权威副本，并随 qlblog 提交和同步。
`~/.codex/skills` 应作为一个完整目录软链接指向本目录，而不是为每个 skill
分别创建链接。定制过的 Codex system skills 保存在受版本控制但不公开展示的
`.system/`；`~/.codex/system-skills` 整目录软链接到该位置。
`.skills_store_lock.json` 仍是仅在本机保留的 Codex 管理状态。

`query-kgdistiller` 与 `ingest-kgdistiller` 是例外：本目录保存供 Codex 和网站发现
的薄入口，规范正文随 `vendor/kgdistiller` submodule 维护。更新 kgdistiller 会同时
更新这两个 Skill 的实际行为，入口不得复制或改写其长工作流。

## 仓库协议

- 新建个人 skill 时，直接创建在本目录下。
- 每次创建或实质更新 skill，都要更新本 README 中对应的一句话用途说明。
- skill 目录名通常与 `SKILL.md` 的 `name` 一致；社区包可保留版本化目录名。
- `.system/` 中的 system skills 不加入下方清单，也不发布到网页。
- skill 内只保留执行所需文件，不为单个 skill 添加额外 README。
- 完成后运行 skill 校验、检查本 README，并审阅 qlblog Git diff。

## 自用速查：macOS、Linux 与 Windows

### 目标布局

无论在哪个系统，最终都保持两个整目录链接；不要为每个 skill 单独建链接：

```text
<qlblog>/skills/                    # 个人与社区 skills，Git 权威副本
<qlblog>/skills/.system/            # 定制 system skills，Git 跟踪但不公开

<CODEX_HOME>/skills          -> <qlblog>/skills
<CODEX_HOME>/system-skills   -> <qlblog>/skills/.system
```

`CODEX_HOME` 未设置时，默认使用用户主目录下的 `.codex`。安装或修复后重新打开
Codex task，让 skill 清单重新加载。

### macOS

```sh
git clone git@github.com:qiulinfan/qiulinfan.github.io.git qlblog
cd qlblog
./skills/link-codex-skills.sh

ls -ld ~/.codex/skills ~/.codex/system-skills
realpath ~/.codex/skills
realpath ~/.codex/system-skills
```

自定义过 `CODEX_HOME` 时：

```sh
CODEX_HOME=/absolute/path/to/codex-home ./skills/link-codex-skills.sh
```

### Linux

Linux 与 macOS 使用同一个脚本：

```sh
git clone git@github.com:qiulinfan/qiulinfan.github.io.git qlblog
cd qlblog
./skills/link-codex-skills.sh

ls -ld ~/.codex/skills ~/.codex/system-skills
readlink -f ~/.codex/skills
readlink -f ~/.codex/system-skills
```

### Windows：优先使用 WSL

若 Codex 和仓库都在 WSL 中运行，把仓库克隆到 WSL 自己的 Linux 文件系统，
然后直接执行上面的 Linux 步骤。不要把 WSL 的 `~/.codex` 与 Windows 原生的
`%USERPROFILE%\.codex` 当成同一个目录。

### Windows：原生 PowerShell

先在 Windows 设置中启用开发者模式，或使用管理员 PowerShell；创建目录符号链接
需要其中一种权限。进入仓库根目录后执行下面的 PowerShell。它会先把已有目录或
链接移动到带时间戳的备份目录，不会直接删除：

```powershell
$RepoSkills = (Resolve-Path ".\skills").Path
$RepoSystem = Join-Path $RepoSkills ".system"
$CodexHome = if ($env:CODEX_HOME) {
    $env:CODEX_HOME
} else {
    Join-Path $HOME ".codex"
}

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup = Join-Path $CodexHome "skill-layout-backups\$Stamp"
$SkillsLink = Join-Path $CodexHome "skills"
$SystemLink = Join-Path $CodexHome "system-skills"

New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
New-Item -ItemType Directory -Force -Path $Backup | Out-Null

if (Get-Item -LiteralPath $SkillsLink -Force -ErrorAction SilentlyContinue) {
    Move-Item -LiteralPath $SkillsLink -Destination (Join-Path $Backup "skills-before")
}
if (Get-Item -LiteralPath $SystemLink -Force -ErrorAction SilentlyContinue) {
    Move-Item -LiteralPath $SystemLink -Destination (Join-Path $Backup "system-skills-before")
}

New-Item -ItemType SymbolicLink -Path $SkillsLink -Target $RepoSkills | Out-Null
New-Item -ItemType SymbolicLink -Path $SystemLink -Target $RepoSystem | Out-Null

Get-Item $SkillsLink, $SystemLink | Select-Object FullName, LinkType, Target
Write-Host "Backup: $Backup"
```

PowerShell 的 `New-Item -ItemType SymbolicLink` 用法和 Windows 权限说明见
[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item#example-7-create-a-symbolic-link-to-a-file-or-folder)。

### 日常修改与同步

- 修改个人或社区 skill：编辑 `skills/<skill-name>/`，并按需更新本 README 的
  一句话说明与第三方出处。
- 修改 system skill：编辑 `skills/.system/<skill-name>/`；提交到 Git，但不要
  加入下方清单，也不要发布到网页。
- 修改后校验：

  ```sh
  python3 skills/.system/skill-creator/scripts/quick_validate.py skills/<skill-name>
  git diff --check
  git status --short -- skills
  ```

  Windows 如果没有 `python3` 命令，可把它替换为 `py -3`。
- 换机器或 `git pull` 后，在 macOS/Linux/WSL 重新运行
  `./skills/link-codex-skills.sh`；Windows 原生重新运行上面的 PowerShell。
- macOS/Linux/WSL 的自动备份位于
  `<CODEX_HOME>/skill-layout-backups/<时间戳>/`；Windows 原生使用相同的相对位置。
- 如果脚本发现未知、内容冲突或指向仓库外部的个人 skill，会拒绝覆盖。新机器上
  已有的 system skills 会先完整备份，再由仓库中的 `.system/` 接管。

## 个人维护

- [build-unity-scene](./build-unity-scene/)：读取 Unity 项目架构与关卡需求，按既有边界创建或修改场景并完成验证。
- [configure-unity-mcp](./configure-unity-mcp/)：安装、修复、迁移并完整验证 Codex 与 Unity Editor 的 MCP 集成。
- [create-latex-math-notes](./create-latex-math-notes/)：新建使用 ElegantBook 语法和 LaTeX-to-Typst 适配器的轻量数学笔记项目。
- [create-math-notes](./create-math-notes/)：新建可直接由 VS Code/Tinymist 编辑的 Typst-first 数学课程或专题。
- [discuss-game-design](./discuss-game-design/)：基于游戏设计文档讨论具体设计决策，并区分事实、综合、提案与开放问题。
- [export-typst-math-notes](./export-typst-math-notes/)：从 Git 改动提取 Markdown、Typst、LaTeX 候选知识，委托查询和入库后发布网页。
- [extract-paper-concepts](./extract-paper-concepts/)：通读论文，查询个人知识库后生成不重复已知词条、默认不合并的联邦概念图。
- [ingest-kgdistiller](./ingest-kgdistiller/)：调用 [`kgdistiller`](https://github.com/qiulinfan/kgdistiller) 随附的写入 Skill，通过 plan/apply 事务、崩溃恢复和 canonical receipt 把已审查知识写入个人图谱；qlblog 只维护发现入口。
- [query-kgdistiller](./query-kgdistiller/)：调用 [`kgdistiller`](https://github.com/qiulinfan/kgdistiller) 随附的只读 Skill，批量查询、消歧、GraphRAG 对齐并返回小型证据包；qlblog 只维护发现入口。
- [play-unity-game](./play-unity-game/)：实际游玩并评估 Unity 游戏或场景，验证玩法循环和复现交互问题。
- [search-game-art](./search-game-art/)：搜索游戏美术资源并给出经过来源与许可证核验的候选清单，不自动下载或导入。
- [test-skill-with-agent](./test-skill-with-agent/)：在隔离环境中用真实或委派 agent 测试 skill，并独立检查产物、权限、改动和凭据泄漏。
- [trace-concept-lineage](./trace-concept-lineage/)：把论文概念批量整理为来源可追溯的概念档案、知识图谱和前置阅读路线。

## 社区来源

- [find-skill-skillhub-1.0.2](./find-skill-skillhub-1.0.2/)：在 SkillHub 按关键词和分类发现、筛选并推荐 skills。
- [mainpdf](./mainpdf/)：编辑、转换、OCR、拆分、合并并提取 PDF 的文字、表格和图片。
- [mermaid-diagram-1.0.0](./mermaid-diagram-1.0.0/)：把需求或文字描述转换为 Mermaid 流程图、架构图、时序图或思维导图。
