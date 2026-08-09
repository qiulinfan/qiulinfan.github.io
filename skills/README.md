# Skills

本目录是个人与社区 Skills 的权威副本，并随 qlblog 提交和同步。普通个人 Skill
一律先放在本目录顶层；现有套件是 `gamemaker/`、`kgdistiller/` 与 `notes/`，保持其
当前成员不动。以后只有用户明确指定时，才新建套件或把 Skills 放入套件，不根据主题
自动归类。从开源网站下载的外部 Skills 统一放在 `community/`，供 Codex 使用但不在
个人主页发布。目录层级不改变 Skill 名称或 Codex 中的扁平清单。
`$CODEX_HOME/skills`（默认 `~/.codex/skills`）必须是 Codex 自己管理的真实目录；
仓库中的每个可见 Skill 分别软链接进去。Codex 生成的 `.system/` 只保留在该真实
目录中，不复制、不定制、不发布，也不纳入本仓库版本管理。

个人全局 Codex 约束的权威源文件是
[`../install/codex/AGENTS.md`](../install/codex/AGENTS.md)。跨设备克隆或移动仓库后，
务必运行 `./skills/link-codex-skills.sh`，把它导入为 `$CODEX_HOME/AGENTS.md`，同时
重建逐 Skill 链接；否则内置 `skill-creator` 不会自动获得本仓库的个人维护协议。

`kgdistiller/` 是知识图谱系统的配套 Skill 套件。其中 `query-kgdistiller` 与
`ingest-kgdistiller` 是薄入口：本目录只保存供 Codex 和网站发现的元数据与委派说明，
规范正文随 `vendor/kgdistiller` submodule 维护。更新 kgdistiller 会同时更新这两个
Skill 的实际行为，入口不得复制或改写其长工作流。

多个 Skill 的编排关系、流程图和简短说明统一维护在 [WORKFLOWS.md](./WORKFLOWS.md)；
Skills 页面只读取本 README 的“个人维护”清单与该文件，不发布“社区来源”内容，也
不另外维护一份页面数据。

## 仓库协议

- 新建个人 Skill 时一律先直接创建在本目录顶层。保留已有套件，但不要根据 Skill
  的主题、名称、依赖或看似所属的系统自动归类。
- 只有当用户明确指定某个分类时，才新建套件目录，或把一个或多个 Skills 放入、
  移入、移出套件。不得仅凭推断使用已有套件。
- 每次重新分类或改变 Skill 在 `skills/` 下的父目录后，立即重新运行
  `./skills/link-codex-skills.sh`；脚本成功前不得视为重分类完成。
- 从开源网站下载的外部 Skill 放入 `community/`，记录准确来源，并保持网站排除。
- 本地维护的个人 Skill 使用英文 frontmatter description 与英文 `agents/openai.yaml`
  发现元数据，便于不同语言的用户稳定发现；社区 Skill 默认保留上游元数据。
- 每个新建或实质更新的个人 Skill 都要明确要求 Agent 的用户可见解释、提示与交接跟随
  用户语言，除非用户指定其他语言；命令、标识符、结构化键/动作码与原始错误保持原样。
- 每次创建或实质更新 skill，都要更新本 README 中对应的一句话用途说明。
- 新建或调整跨 Skill 工具流时，直接编辑 `WORKFLOWS.md` 中的 Markdown 与 Mermaid。
- Skill 的 `name` 与末级目录名都必须在整个集合中唯一；目录名通常与 `name` 一致，
  社区包可保留版本化目录名。
- 永远不要在本目录创建、复制或提交 `.system/`；它是 Codex 生成状态。
- skill 内只保留执行所需文件，不为单个 skill 添加额外 README。
- 完成后运行 skill 校验、检查本 README，并审阅 qlblog Git diff。

## 自用速查：macOS、Linux 与 Windows

### 目标布局

目标布局把 Codex 生成状态与仓库权威内容彻底分开：

```text
<qlblog>/skills/<name>/                 # 普通个人 Skill，默认位置
<qlblog>/skills/<suite>/<name>/         # 明确定义系统的配套 Skill
<qlblog>/skills/community/<name>/       # 外部下载 Skill，不进入网站
<qlblog>/install/codex/AGENTS.md         # 个人全局 Codex 约束，Git 权威副本

<CODEX_HOME>/AGENTS.md            -> <qlblog>/install/codex/AGENTS.md
<CODEX_HOME>/skills/                  # Codex 拥有的真实目录
<CODEX_HOME>/skills/.system/          # Codex 自动生成和更新，不进 Git
<CODEX_HOME>/skills/<name>         -> 上述任一仓库 Skill 目录
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

$RepoSkillManifests = @(Get-ChildItem -LiteralPath $RepoSkills -Filter "SKILL.md" -File -Recurse | Where-Object {
    $RelativeDirectory = [System.IO.Path]::GetRelativePath($RepoSkills, $_.Directory.FullName)
    -not (($RelativeDirectory -split '[\\/]') | Where-Object { $_.StartsWith('.') })
})
$DuplicateNames = @($RepoSkillManifests | Group-Object { $_.Directory.Name } | Where-Object Count -gt 1)
if ($DuplicateNames) {
    throw "Duplicate Skill directory names cannot be flattened: $($DuplicateNames.Name -join ', ')"
}
$SkillNames = @($RepoSkillManifests | ForEach-Object {
    $Match = Select-String -LiteralPath $_.FullName -Pattern '^name:\s*(.+)\s*$' | Select-Object -First 1
    if (-not $Match) {
        throw "Skill is missing frontmatter name: $($_.FullName)"
    }
    $Match.Matches[0].Groups[1].Value.Trim()
})
$DuplicateSkillNames = @($SkillNames | Group-Object | Where-Object Count -gt 1)
if ($DuplicateSkillNames) {
    throw "Duplicate Skill names are ambiguous: $($DuplicateSkillNames.Name -join ', ')"
}

$RepoSkillsPrefix = [System.IO.Path]::GetFullPath($RepoSkills) + [System.IO.Path]::DirectorySeparatorChar
Get-ChildItem -LiteralPath $CodexSkills -Force | Where-Object LinkType | ForEach-Object {
    $Target = Resolve-SymbolicLinkTarget $_
    if ($Target.StartsWith($RepoSkillsPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-Path -LiteralPath (Join-Path $Target "SKILL.md"))) {
        Remove-Item -LiteralPath $_.FullName
    }
}

$RepoSkillManifests | ForEach-Object {
    $SourceDirectory = $_.Directory
    $Destination = Join-Path $CodexSkills $SourceDirectory.Name
    $Existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if (-not $Existing) {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $SourceDirectory.FullName | Out-Null
    } elseif (-not $Existing.LinkType -or
              (Resolve-SymbolicLinkTarget $Existing) -ne [System.IO.Path]::GetFullPath($SourceDirectory.FullName)) {
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

- 修改普通个人 Skill：编辑 `skills/<skill-name>/`；修改套件或社区 Skill：编辑
  `skills/<suite>/<skill-name>/`。按需更新本 README 的一句话说明与第三方出处。
- 重新分类或移动 Skill 的父目录后，必须运行 `./skills/link-codex-skills.sh`，清理
  旧链接并重建 Codex 的扁平 Skill 清单。
- 不修改或版本管理 system Skill；让 Codex 维护 `$CODEX_HOME/skills/.system`。
- 修改后校验：

  ```sh
  python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py" skills/<skill-name>
  # 套件 Skill 则改用：skills/<suite>/<skill-name>
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

### Gamemaker 套件

- [build-unity-scene](./gamemaker/build-unity-scene/)：读取 Unity 项目架构与关卡需求，按既有边界创建或修改场景并完成验证。
- [configure-unity-mcp](./gamemaker/configure-unity-mcp/)：安装、修复、迁移并完整验证 Codex 与 Unity Editor 的 MCP 集成。
- [discuss-game-design](./gamemaker/discuss-game-design/)：基于游戏设计文档讨论具体设计决策，并区分事实、综合、提案与开放问题。
- [play-unity-game](./gamemaker/play-unity-game/)：实际游玩并评估 Unity 游戏或场景，验证玩法循环和复现交互问题。
- [search-game-art](./gamemaker/search-game-art/)：从策划案提取外观、主题、玩法功能与动画需求，搜索并比较经过来源与许可证核验的资源；获明确授权后还可审计下载文件、筛选最小导入子集并交接 Unity 集成。

### kgdistiller 套件

- [extract-and-export-notes](./kgdistiller/extract-and-export-notes/)：从个人笔记或标准论文 Markdown 包提取候选图；笔记分支查询、入库并发布，论文分支只读连接个人图谱并生成不合并的联邦图。
- [ingest-kgdistiller](./kgdistiller/ingest-kgdistiller/)：调用 [`kgdistiller`](https://github.com/qiulinfan/kgdistiller) 随附的写入 Skill，通过 plan/apply 事务、崩溃恢复和 canonical receipt 把已审查知识写入个人图谱；qlblog 只维护发现入口。
- [query-kgdistiller](./kgdistiller/query-kgdistiller/)：调用 [`kgdistiller`](https://github.com/qiulinfan/kgdistiller) 随附的只读 Skill，批量查询、消歧、GraphRAG 对齐并返回小型证据包；qlblog 只维护发现入口。
- [trace-concept-lineage](./kgdistiller/trace-concept-lineage/)：把论文概念批量整理为来源可追溯的概念档案、知识图谱和前置阅读路线。

### 笔记项目

- [create-latex-math-notes](./notes/create-latex-math-notes/)：新建使用 ElegantBook 语法和 LaTeX-to-Typst 适配器的轻量数学笔记项目。
- [create-math-notes](./notes/create-math-notes/)：新建可直接由 VS Code/Tinymist 编辑的 Typst-first 数学课程或专题。

### 全局 Skills

- [multica-selfhost-server](./multica-selfhost-server/)：以可恢复 phase cache 部署唯一 Multica 控制面、loopback-only 内部栈、Tailscale 私网 HTTPS 和固定码 `114514`；由服主侧 Skill 收集成员身份、选择 workspace、把自然语言访问范围映射为 Tailscale 模式、完成两层准入并生成无需客户端理解网络结构的完整 handoff，同时管理首 runtimes、升级备份和撤销。Multica 自动发现全部 providers，本 Skill 不登录或直接验证 provider CLI。最初的本地完整栈能力由用户提供的 `/Users/qiulinfan/Desktop/multica-local-dev` 演化而来。
- [multica-client-setup](./multica-client-setup/)：从零输入、仅 Server URL 或完整 handoff 开始分阶段完成客户端接入，把成员邮箱和准入请求交给服主，由服主决定 workspace 与 Tailscale access mode；随后安装并配置 CLI，按客户端与模式排查 VPN/代理，以 Rules Enhancement 完整适配 macOS Clash Verge 系统代理，并在必要时停于用户重载断点，其余客户端经证据化人工边界处理，再验证身份、membership 和全部本机 online runtimes、创建 agents、运行 smoke，并按确认配置自启动；不处理日常 issue/task、provider CLI 或第二套 server。
- [multica-runtime-client](./multica-runtime-client/)：在 CLI、身份、workspace、daemon 和初始 agents 已配置的前提下，把自然语言工作转成单个可验收 issue，按完整 ID 选择 online runtime 上的 agent，防重复地入队一次，并读取 runs/messages 监控、续接、取消或按授权 rerun；同时检查 runtime/daemon 活动、用量和日志，缺失接入前提时交回 `multica-client-setup`。
- [extract-paper-markdown](./extract-paper-markdown/)：把网页、DOI、标题或 PDF 论文整理为可追溯、无嵌图且无 HTML/Pandoc 转码残留的语义 Markdown 包；只对图表相关页面做定点多模态理解并留下结构化摘要。
- [codex-subagent-testskill](./codex-subagent-testskill/)：单 Skill 测试的默认入口；默认运行一次，也可按用户指定次数用 fresh 原生 subagents 做重复稳定性与压力测试，并记录逐次及总 wall-clock 时间，不冒充进程或认证级隔离。
- [codex-external-agent-testskill](./codex-external-agent-testskill/)：仅在明确需要外部进程、登录或跨 runtime 行为时，由 Codex 通过本机缓存配置启动 Claude Code 或 OpenCode 测试一个 Skill；不再配置或启动 Codex target。
- [codex-subagent-workflow](./codex-subagent-workflow/)：在当前 Codex 会话内用原生 subagents 编排生产任务；优先采用可信项目 `.codex/config.toml` 的标准 `[agents]` 角色，未配置角色时才从任务描述自动拆分，并由主 agent 集成验收。

## 社区来源

本节记录外部下载 Skill 的来源与用途，仅供仓库维护和 Codex 发现；网站构建明确排除
整个 `community/` 目录。

- [find-skill-skillhub-1.0.2](./community/find-skill-skillhub-1.0.2/)：在 SkillHub 按关键词和分类发现、筛选并推荐 skills。
- [mainpdf](./community/mainpdf/)：编辑、转换、OCR、拆分、合并并提取 PDF 的文字、表格和图片。
- [mermaid-diagram-1.0.0](./community/mermaid-diagram-1.0.0/)：把需求或文字描述转换为 Mermaid 流程图、架构图、时序图或思维导图。
