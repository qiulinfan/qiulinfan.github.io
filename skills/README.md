# Skills

本目录是个人与社区 Skills 的权威副本，并随 qlblog 提交和同步。
`$CODEX_HOME/skills`（默认 `~/.codex/skills`）必须是 Codex 自己管理的真实目录；
仓库中的每个可见 Skill 分别软链接进去。Codex 生成的 `.system/` 只保留在该真实
目录中，不复制、不定制、不发布，也不纳入本仓库版本管理。

个人全局 Codex 约束的权威源文件是
[`../install/codex/AGENTS.md`](../install/codex/AGENTS.md)。跨设备克隆或移动仓库后，
务必运行 `./skills/link-codex-skills.sh`，把它导入为 `$CODEX_HOME/AGENTS.md`，同时
重建逐 Skill 链接；否则内置 `skill-creator` 不会自动获得本仓库的个人维护协议。

`query-kgdistiller` 与 `ingest-kgdistiller` 是例外：本目录保存供 Codex 和网站发现
的薄入口，规范正文随 `vendor/kgdistiller` submodule 维护。更新 kgdistiller 会同时
更新这两个 Skill 的实际行为，入口不得复制或改写其长工作流。

多个 Skill 的编排关系、流程图和简短说明统一维护在 [WORKFLOWS.md](./WORKFLOWS.md)；
Skills 页面直接读取本 README 的能力清单与该文件，不另外维护一份页面数据。

## 仓库协议

- 新建个人 skill 时，直接创建在本目录下。
- 每次创建或实质更新 skill，都要更新本 README 中对应的一句话用途说明。
- 新建或调整跨 Skill 工具流时，直接编辑 `WORKFLOWS.md` 中的 Markdown 与 Mermaid。
- skill 目录名通常与 `SKILL.md` 的 `name` 一致；社区包可保留版本化目录名。
- 永远不要在本目录创建、复制或提交 `.system/`；它是 Codex 生成状态。
- skill 内只保留执行所需文件，不为单个 skill 添加额外 README。
- 完成后运行 skill 校验、检查本 README，并审阅 qlblog Git diff。

## 自用速查：macOS、Linux 与 Windows

### 目标布局

目标布局把 Codex 生成状态与仓库权威内容彻底分开：

```text
<qlblog>/skills/<name>/                 # 个人与社区 Skill，Git 权威副本
<qlblog>/install/codex/AGENTS.md         # 个人全局 Codex 约束，Git 权威副本

<CODEX_HOME>/AGENTS.md            -> <qlblog>/install/codex/AGENTS.md
<CODEX_HOME>/skills/                  # Codex 拥有的真实目录
<CODEX_HOME>/skills/.system/          # Codex 自动生成和更新，不进 Git
<CODEX_HOME>/skills/<name>         -> <qlblog>/skills/<name>
```

`CODEX_HOME` 未设置时，默认使用用户主目录下的 `.codex`。安装或修复后重新打开
Codex task，让 skill 清单重新加载。

### macOS

```sh
git clone git@github.com:qiulinfan/qiulinfan.github.io.git qlblog
cd qlblog
./skills/link-codex-skills.sh

ls -ld ~/.codex/AGENTS.md ~/.codex/skills ~/.codex/skills/.system
test ! -L ~/.codex/skills
realpath ~/.codex/AGENTS.md
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

ls -ld ~/.codex/AGENTS.md ~/.codex/skills ~/.codex/skills/.system
test ! -L ~/.codex/skills
readlink -f ~/.codex/AGENTS.md
```

### Windows：优先使用 WSL

若 Codex 和仓库都在 WSL 中运行，把仓库克隆到 WSL 自己的 Linux 文件系统，
然后直接执行上面的 Linux 步骤。不要把 WSL 的 `~/.codex` 与 Windows 原生的
`%USERPROFILE%\.codex` 当成同一个目录。

### Windows：原生 PowerShell

先在 Windows 设置中启用开发者模式，或使用管理员 PowerShell；逐 Skill 目录链接
和全局 `AGENTS.md` 文件链接需要其中一种权限。进入仓库根目录后，先把旧的
`%USERPROFILE%\.codex\skills` 整目录链接和 `system-skills` 链接移动到备份位置，
再创建真实的 `skills` 目录、逐项链接和全局约束链接：

```powershell
$RepoSkills = (Resolve-Path ".\skills").Path
$RepoRoot = (Resolve-Path ".").Path
$GlobalAgentsSource = Join-Path $RepoRoot "install\codex\AGENTS.md"
$CodexHome = if ($env:CODEX_HOME) {
    $env:CODEX_HOME
} else {
    Join-Path $HOME ".codex"
}

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup = Join-Path $CodexHome "skill-layout-backups\$Stamp"
$CodexSkills = Join-Path $CodexHome "skills"
$GlobalAgents = Join-Path $CodexHome "AGENTS.md"
$LegacySystem = Join-Path $CodexHome "system-skills"

function Resolve-SymbolicLinkTarget([System.IO.FileSystemInfo]$Item) {
    $Target = [string]$Item.Target
    if (-not [System.IO.Path]::IsPathRooted($Target)) {
        $Target = Join-Path $Item.DirectoryName $Target
    }
    return [System.IO.Path]::GetFullPath($Target)
}

New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
New-Item -ItemType Directory -Force -Path $Backup | Out-Null

$ExistingSkills = Get-Item -LiteralPath $CodexSkills -Force -ErrorAction SilentlyContinue
if ($ExistingSkills -and $ExistingSkills.LinkType) {
    if ((Resolve-SymbolicLinkTarget $ExistingSkills) -ne [System.IO.Path]::GetFullPath($RepoSkills)) {
        throw "Existing skills link points outside this repository: $CodexSkills"
    }
    Remove-Item -LiteralPath $CodexSkills
} elseif ($ExistingSkills -and -not $ExistingSkills.PSIsContainer) {
    throw "Existing skills path is not a directory: $CodexSkills"
}
New-Item -ItemType Directory -Force -Path $CodexSkills | Out-Null
$RepoSystem = Join-Path $RepoSkills ".system"
$CodexSystem = Join-Path $CodexSkills ".system"
if ((Test-Path -LiteralPath $RepoSystem) -and -not (Test-Path -LiteralPath $CodexSystem)) {
    Copy-Item -Recurse -LiteralPath $RepoSystem -Destination $CodexSystem
}
$ExistingLegacySystem = Get-Item -LiteralPath $LegacySystem -Force -ErrorAction SilentlyContinue
if ($ExistingLegacySystem) {
    if (-not $ExistingLegacySystem.LinkType) {
        throw "Legacy system-skills is not a symbolic link: $LegacySystem"
    }
    $AllowedSystemTargets = @(
        [System.IO.Path]::GetFullPath($RepoSystem),
        [System.IO.Path]::GetFullPath($CodexSystem)
    )
    if ((Resolve-SymbolicLinkTarget $ExistingLegacySystem) -notin $AllowedSystemTargets) {
        throw "Legacy system-skills points to an unknown location: $LegacySystem"
    }
    Remove-Item -LiteralPath $LegacySystem
}

Get-ChildItem -LiteralPath $RepoSkills -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "SKILL.md")
} | ForEach-Object {
    $Destination = Join-Path $CodexSkills $_.Name
    $Existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if (-not $Existing) {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $_.FullName | Out-Null
    } elseif (-not $Existing.LinkType -or
              (Resolve-SymbolicLinkTarget $Existing) -ne [System.IO.Path]::GetFullPath($_.FullName)) {
        throw "Existing Skill conflicts with repository authority: $Destination"
    }
}
$ExistingGlobalAgents = Get-Item -LiteralPath $GlobalAgents -Force -ErrorAction SilentlyContinue
if (-not $ExistingGlobalAgents) {
    New-Item -ItemType SymbolicLink -Path $GlobalAgents -Target $GlobalAgentsSource | Out-Null
} elseif ($ExistingGlobalAgents.LinkType) {
    if ((Resolve-SymbolicLinkTarget $ExistingGlobalAgents) -ne
        [System.IO.Path]::GetFullPath($GlobalAgentsSource)) {
        throw "Existing global AGENTS.md points elsewhere: $GlobalAgents"
    }
} elseif (-not $ExistingGlobalAgents.PSIsContainer -and
          (Get-FileHash $GlobalAgents).Hash -eq (Get-FileHash $GlobalAgentsSource).Hash) {
    Move-Item -LiteralPath $GlobalAgents -Destination (Join-Path $Backup "AGENTS.md-before-link")
    New-Item -ItemType SymbolicLink -Path $GlobalAgents -Target $GlobalAgentsSource | Out-Null
} else {
    throw "Existing global AGENTS.md differs: $GlobalAgents"
}

Get-Item $GlobalAgents, $CodexSkills | Select-Object FullName, LinkType, Target
Write-Host "Backup: $Backup"
```

PowerShell 的 `New-Item -ItemType SymbolicLink` 用法和 Windows 权限说明见
[Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item#example-7-create-a-symbolic-link-to-a-file-or-folder)。

### 日常修改与同步

- 修改个人或社区 skill：编辑 `skills/<skill-name>/`，并按需更新本 README 的
  一句话说明与第三方出处。
- 不修改或版本管理 system Skill；让 Codex 维护 `$CODEX_HOME/skills/.system`。
- 修改后校验：

  ```sh
  python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py" skills/<skill-name>
  git diff --check
  git status --short -- skills
  ```

  Windows 如果没有 `python3` 命令，可把它替换为 `py -3`。
- 换机器或 `git pull` 后，在 macOS/Linux/WSL 重新运行
  `./skills/link-codex-skills.sh`；Windows 原生重新运行上面的 PowerShell。
- macOS/Linux/WSL 的自动备份位于
  `<CODEX_HOME>/skill-layout-backups/<时间戳>/`；Windows 原生使用相同的相对位置。
- 如果脚本发现未知、内容冲突或指向仓库外部的个人 Skill 或全局 `AGENTS.md`，会
  拒绝覆盖。Codex 的 `.system` 始终留在 `$CODEX_HOME/skills`，不由仓库接管。

## 个人维护

- [build-unity-scene](./build-unity-scene/)：读取 Unity 项目架构与关卡需求，按既有边界创建或修改场景并完成验证。
- [configure-unity-mcp](./configure-unity-mcp/)：安装、修复、迁移并完整验证 Codex 与 Unity Editor 的 MCP 集成。
- [create-latex-math-notes](./create-latex-math-notes/)：新建使用 ElegantBook 语法和 LaTeX-to-Typst 适配器的轻量数学笔记项目。
- [create-math-notes](./create-math-notes/)：新建可直接由 VS Code/Tinymist 编辑的 Typst-first 数学课程或专题。
- [discuss-game-design](./discuss-game-design/)：基于游戏设计文档讨论具体设计决策，并区分事实、综合、提案与开放问题。
- [extract-and-export-notes](./extract-and-export-notes/)：从跨领域 Git 改动提取 Markdown、Typst、LaTeX 候选知识，委托查询和入库后发布网页。
- [extract-paper-concepts](./extract-paper-concepts/)：从网页、DOI 或标题找到规范 PDF，逐页核验并预处理为无图片、图表可追溯的 TeX，再查询个人知识库并生成默认不合并的联邦概念图。
- [ingest-kgdistiller](./ingest-kgdistiller/)：调用 [`kgdistiller`](https://github.com/qiulinfan/kgdistiller) 随附的写入 Skill，通过 plan/apply 事务、崩溃恢复和 canonical receipt 把已审查知识写入个人图谱；qlblog 只维护发现入口。
- [query-kgdistiller](./query-kgdistiller/)：调用 [`kgdistiller`](https://github.com/qiulinfan/kgdistiller) 随附的只读 Skill，批量查询、消歧、GraphRAG 对齐并返回小型证据包；qlblog 只维护发现入口。
- [play-unity-game](./play-unity-game/)：实际游玩并评估 Unity 游戏或场景，验证玩法循环和复现交互问题。
- [run-workflow-with-agents](./run-workflow-with-agents/)：先读取 Git 忽略的本机 agent/runtime profile，以缓存的基础 agent 为默认，并可按 workflow/skill 路由，再用 Claude Code、Codex 或 OpenCode 的原生单 worker / coordinator + workers 机制执行生产工作流。
- [search-game-art](./search-game-art/)：搜索游戏美术资源并给出经过来源与许可证核验的候选清单，不自动下载或导入。
- [test-skill-with-agent](./test-skill-with-agent/)：先读取 Git 忽略的本机 agent/runtime profile，以缓存的 Claude Code、Codex 或 OpenCode 基础 agent（或可选 skill 路由）运行隔离 trials，支持 smoke、回归、负向、安全、重复稳定性和有界并发压力测试。
- [trace-concept-lineage](./trace-concept-lineage/)：把论文概念批量整理为来源可追溯的概念档案、知识图谱和前置阅读路线。

## 社区来源

- [find-skill-skillhub-1.0.2](./find-skill-skillhub-1.0.2/)：在 SkillHub 按关键词和分类发现、筛选并推荐 skills。
- [mainpdf](./mainpdf/)：编辑、转换、OCR、拆分、合并并提取 PDF 的文字、表格和图片。
- [mermaid-diagram-1.0.0](./mermaid-diagram-1.0.0/)：把需求或文字描述转换为 Mermaid 流程图、架构图、时序图或思维导图。
