# Skills

本目录是 qlblog 自有个人与社区 Skills 的权威副本。普通个人 Skill 默认直接
创建在本目录顶层；只有用户明确指定分类时才新建套件或移动 Skill，当前保留的
本地套件是 `notes/`。从开源网站下载的外部 Skills 统一放在 `community/`，
供本机 agent 运行时使用但不在个人主页发布。

本目录同时服务两个运行时：Codex 与 Claude Code。两者各有一个 linker，把同一份工作树
逐 Skill 链接到各自拥有的真实 Skill 目录，因此本地修改对两边都实时生效。跨运行时可用是
默认；运行时专属只由作用域目录声明——`codex-only/` 下的 Skill 只链接进 Codex，
`claude-only/` 下的 Skill 只链接进 Claude Code，名称不参与作用域判定，见下文“运行时与作用域”。

当用户明确把一组高频迭代 Skills/Workflows 提升为独立产品后，产品仓库成为唯一
源码权威，qlblog 删除对应副本。每个产品用自己的 linker 把开发工作树逐 Skill
链接到 `$CODEX_HOME/skills`；因此本地修改实时生效，而 qlblog 只保留自己的
Skills 与网站内容。`$CODEX_HOME/skills` 与 `~/.claude/skills` 都必须保持为对应运行时
管理的真实目录，Codex 的 `.system/` 也只留在 `$CODEX_HOME/skills`，不复制、不定制、
不发布、不纳入本仓库。Claude Code 没有对应的生成目录，也不要伪造一个。

个人全局约束的权威源文件是与运行时无关的
[`../install/agents/core.md`](../install/agents/core.md)，加上各运行时增量
[`../install/codex/runtime.md`](../install/codex/runtime.md) 与
[`../install/claude/runtime.md`](../install/claude/runtime.md)。安装用的
[`../install/codex/AGENTS.md`](../install/codex/AGENTS.md) 与
[`../install/claude/CLAUDE.md`](../install/claude/CLAUDE.md) 由
`make agents-guidance` 生成并提交，不要手改。跨设备克隆或移动仓库后，务必为本机装了的
每个运行时运行平台对应的 linker，把生成文件导入为 `$CODEX_HOME/AGENTS.md` 与
`~/.claude/CLAUDE.md`，同时重建逐 Skill 链接；否则 `skill-creator` 之类的 Skill
创作流程不会自动获得本仓库的个人维护协议。

独立产品仓库当前包括 [`autoTA`](https://github.com/qiulinfan/autoTA) 与
[`kgdistiller`](https://github.com/qiulinfan/kgdistiller)。它们的 Skills、预制 agents、
工作流、测试与安装脚本都在各自仓库维护，不由 qlblog 镜像或转发。

多个 Skill 的编排关系、流程图和简短说明统一维护在 [WORKFLOWS.md](./WORKFLOWS.md)；
Skills 页面只读取本 README 的“个人维护”清单与该文件，不发布“社区来源”内容，也
不另外维护一份页面数据。

## 运行时与作用域

| 运行时 | home | 全局 guidance | Skill 目录 | POSIX/WSL linker | 原生 Windows linker |
| --- | --- | --- | --- | --- | --- |
| Codex | `$CODEX_HOME`，默认 `~/.codex` | `<home>/AGENTS.md` | `<home>/skills` | `link-codex-skills.sh` | `link-codex-skills.ps1` |
| Claude Code | `$CLAUDE_CONFIG_DIR`，默认 `~/.claude` | `<home>/CLAUDE.md` | `<home>/skills` | `link-claude-skills.sh` | `link-claude-skills.ps1` |

- 作用域只由目录决定，名称不参与：`codex-only/` 与 `claude-only/` 是运行时作用域目录，
  与 `notes/` 这类语义套件正交。作用域目录之外的所有 Skill 链接进两个运行时。
- Claude Code linker 跳过 `codex-only/` 下的 Skill，当前是
  `codex-only/codex-subagent-workflow`、`codex-only/codex-subagent-testskill`、
  `codex-only/codex-external-agent-testskill`。它们编排的是 Codex 原生 subagent 或由
  Codex 选择的外部运行时，在 Claude Code 里没有对应能力，只链接进 Codex。
- Codex linker 跳过 `claude-only/` 下的 Skill（依赖 Claude Code 专属能力时使用；当前为空，
  目录在第一个此类 Skill 出现时才创建）。两个脚本都会打印被跳过的清单。
- 只有当 Skill 确实依赖某个运行时的专属能力、或用户明确要求时，才把它放入作用域目录。
  不要手工把被跳过的 Skill 补链进另一个运行时的 Skill 目录，也不要放宽过滤器。确实需要
  两个运行时都能用时，改成运行时无关的实现并移出作用域目录，且仅在用户明确要求时这么做。
- 两个 linker 互不干扰，也都不动 `autoTA`、`kgdistiller` 等独立产品自己建立的链接。

## 仓库协议

- 新建个人 Skill 时一律先直接创建在本目录顶层。保留已有套件，但不要根据 Skill
  的主题、名称、依赖或看似所属的系统自动归类。
- 无论在哪个运行时里创作，跨运行时 Skill 都保持运行时无关：不依赖 `$CODEX_HOME`
  专属路径、Codex 原生 subagent、Codex 选择的外部运行时或 Claude Code 专属工具。
  必须依赖某个运行时的专属能力时，直接创建在对应的 `codex-only/` 或 `claude-only/`。
- 只有当用户明确指定某个分类时，才新建套件目录，或把一个或多个 Skills 放入、
  移入、移出套件。不得仅凭推断使用已有套件。
- 每次重新分类或改变 Skill 在 `skills/` 下的父目录后，立即为本机装了的每个运行时
  重新运行平台对应的 qlblog linker；脚本成功前不得视为重分类完成。
- 从开源网站下载的外部 Skill 放入 `community/`，记录准确来源，并保持网站排除。
- 本地维护的个人 Skill 使用英文 frontmatter description 与英文 `agents/openai.yaml`
  发现元数据，便于不同语言的用户稳定发现；社区 Skill 默认保留上游元数据。
- frontmatter `name` 与末级目录名保持一致：Claude Code 用目录名作为调用名，
  frontmatter `name` 只是显示标签，两者不一致会让调用名与文档对不上。
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
<qlblog>/skills/<name>/                 # 普通个人 Skill，默认位置，链接进两个运行时
<qlblog>/skills/<suite>/<name>/         # 仅限用户明确指定的本地套件
<qlblog>/skills/codex-only/<name>/      # Codex 专属作用域目录，只链接进 Codex
<qlblog>/skills/claude-only/<name>/     # Claude Code 专属作用域目录，只链接进 Claude Code
<qlblog>/skills/community/<name>/       # 外部下载 Skill，不进入网站
<product>/skills/<name>/                # 独立产品的唯一开发权威
<qlblog>/install/agents/core.md         # 运行时无关的全局约束，Git 权威源
<qlblog>/install/codex/runtime.md       # Codex 增量，Git 权威源
<qlblog>/install/claude/runtime.md      # Claude Code 增量，Git 权威源
<qlblog>/install/codex/AGENTS.md        # 生成并提交的 Codex 安装文件
<qlblog>/install/claude/CLAUDE.md       # 生成并提交的 Claude Code 安装文件

<CODEX_HOME>/AGENTS.md            -> <qlblog>/install/codex/AGENTS.md
<CODEX_HOME>/skills/                  # Codex 拥有的真实目录
<CODEX_HOME>/skills/.system/          # Codex 自动生成和更新，不进 Git
<CODEX_HOME>/skills/<name>         -> qlblog 或独立产品中的唯一 Skill 目录

<CLAUDE_HOME>/CLAUDE.md           -> <qlblog>/install/claude/CLAUDE.md
<CLAUDE_HOME>/skills/                 # Claude Code 拥有的真实目录
<CLAUDE_HOME>/skills/<name>        -> qlblog 中 codex-only/ 之外的 Skill 目录
```

`CODEX_HOME` 未设置时默认 `~/.codex`，`CLAUDE_CONFIG_DIR` 未设置时默认 `~/.claude`。
安装或修复后重新打开 Codex task 或重启 Claude Code 会话，让 skill 清单重新加载。

### macOS

```sh
git clone git@github.com:qiulinfan/qiulinfan.github.io.git qlblog
cd qlblog
./skills/link-codex-skills.sh
./skills/link-claude-skills.sh

ls -ld ~/.codex/AGENTS.md ~/.codex/skills ~/.codex/skills/.system
ls -ld ~/.claude/CLAUDE.md ~/.claude/skills
test ! -L ~/.codex/skills
test ! -L ~/.claude/skills
realpath ~/.codex/AGENTS.md ~/.claude/CLAUDE.md
```

只装了其中一个运行时，就只运行对应的那一个脚本。自定义过 home 时：

```sh
CODEX_HOME=/absolute/path/to/codex-home ./skills/link-codex-skills.sh
CLAUDE_CONFIG_DIR=/absolute/path/to/claude-home ./skills/link-claude-skills.sh
```

### Linux

Linux 与 macOS 使用同一个脚本：

```sh
git clone git@github.com:qiulinfan/qiulinfan.github.io.git qlblog
cd qlblog
./skills/link-codex-skills.sh
./skills/link-claude-skills.sh

ls -ld ~/.codex/AGENTS.md ~/.codex/skills ~/.codex/skills/.system
ls -ld ~/.claude/CLAUDE.md ~/.claude/skills
test ! -L ~/.codex/skills
test ! -L ~/.claude/skills
readlink -f ~/.codex/AGENTS.md ~/.claude/CLAUDE.md
```

### Windows：优先使用 WSL

若 agent 和仓库都在 WSL 中运行，把仓库克隆到 WSL 自己的 Linux 文件系统，
然后直接执行上面的 Linux 步骤。不要把 WSL 的 `~/.codex`、`~/.claude` 与 Windows 原生的
`%USERPROFILE%\.codex`、`%USERPROFILE%\.claude` 当成同一个目录。

### Windows：原生 PowerShell

进入仓库根目录后运行原生 linker。它会把旧的 qlblog-owned 失效链接清掉，把每个
当前 Skill 以 Junction 直接连到工作树，并修复全局 `AGENTS.md` 链接；现有
`$CODEX_HOME\skills\.system` 与其他产品仓的链接始终原样保留：

```powershell
& .\skills\link-codex-skills.ps1
& .\skills\link-claude-skills.ps1
```

两个脚本的安全边界一致，`link-claude-skills.ps1` 用 `-ClaudeHome` 或
`CLAUDE_CONFIG_DIR` 指定非默认 home。
若已有冲突链接或从旧 POSIX 安装留下 Windows 无法读取的 reparse link，先核对它是
链接而不是真实文件，再对相应脚本显式加 `-Force` 重跑。`-Force`
仍拒绝覆盖真实文件、目录或无法证明属于当前 qlblog checkout 的 Skill 链接。仓库被
移动到新绝对路径后，旧的 broken Junction 已无法自行证明 owner；先人工核对并删除
那些旧 qlblog Junction，再运行 linker，不能用 `-Force` 越过这个边界。

### 日常修改与同步

- 修改普通个人 Skill：编辑 `skills/<skill-name>/`；修改套件或社区 Skill：编辑
  `skills/<suite>/<skill-name>/`。按需更新本 README 的一句话说明与第三方出处。
- 重新分类或移动 Skill 的父目录后，必须为每个运行时运行平台对应的 qlblog linker，
  清理旧链接并重建该运行时的扁平 Skill 清单。把 Skill 移入 `codex-only/` 或
  `claude-only/` 之后，另一侧的 linker 会自动移除它留下的旧链接；改名不影响作用域。
- 不修改或版本管理 system Skill；让 Codex 维护 `$CODEX_HOME/skills/.system`。
- 改了 `install/agents/core.md` 或任一 `install/*/runtime.md` 后运行
  `make agents-guidance`，并用 `make agents-check` 确认生成文件已同步。
- 修改后校验：

  ```sh
  python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py" skills/<skill-name>
  # 套件 Skill 则改用：skills/<suite>/<skill-name>
  git diff --check
  git status --short -- skills
  ```

  Windows 如果没有 `python3` 命令，可把它替换为 `py -3`。
- 换机器或 `git pull` 后，在 macOS/Linux/WSL 重新运行
  `./skills/link-codex-skills.sh` 与 `./skills/link-claude-skills.sh`；Windows 原生
  重新运行 `.\skills\link-codex-skills.ps1` 与 `.\skills\link-claude-skills.ps1`。
- macOS/Linux/WSL 的自动备份位于各运行时 home 下的
  `skill-layout-backups/<时间戳>/`；Windows 原生使用相同的相对位置。
- 未知、内容冲突或指向仓库外部的 Skill 链接始终拒绝覆盖。全局
  `AGENTS.md` / `CLAUDE.md` 是唯一例外：显式 `-Force` 可修复未知的 reparse link，但内容
  不同的真实文件仍会被拒绝。Codex 的 `.system` 始终留在
  `$CODEX_HOME/skills`，不由仓库接管。

## 独立产品

- [autoTA](https://github.com/qiulinfan/autoTA)：技术美术管线(素材搜索、2D/3D 生产、托管生成、绑定对齐)与交接回执契约；仓库内 Skills 和预制 agents 由产品 linker 直接接入本地 Codex。(前身 gamemaker)
- [kgdistiller](https://github.com/qiulinfan/kgdistiller)：知识蒸馏引擎、论文/笔记 Skills、预制 agents 与事务工作流；qlblog 只采用并展示其静态导出。

## 个人维护

### 笔记项目

- [create-latex-math-notes](./notes/create-latex-math-notes/)：检查或配置本地 TeX 环境，并新建不依赖 qlblog shared toolchain 或第三方 vendored class 的自包含 LuaLaTeX 数学笔记项目；PDF 只作 ignored local build，网页发布仍走 Typst。
- [create-math-notes](./notes/create-math-notes/)：新建可直接由 VS Code/Tinymist 编辑的 Typst-first 数学课程或专题。

### 全局 Skills

- [multica-selfhost-server](./multica-selfhost-server/)：以可恢复 phase cache 部署唯一 Multica 控制面、loopback-only 内部栈、Tailscale 私网 HTTPS 和固定码 `114514`；由服主侧 Skill 收集成员身份、选择 workspace、把自然语言访问范围映射为 Tailscale 模式、完成两层准入并生成无需客户端理解网络结构的完整 handoff，同时管理首 runtimes、升级备份和撤销，并让生产宿主机的 daemon、cache 与自启动保持默认并发 `10`。Multica 自动发现全部 providers，本 Skill 不登录或直接验证 provider CLI。最初的本地完整栈能力由用户提供的 `/Users/qiulinfan/Desktop/multica-local-dev` 演化而来。
- [multica-client-setup](./multica-client-setup/)：从零输入、仅 Server URL 或完整 handoff 开始分阶段完成客户端接入，把成员邮箱和准入请求交给服主，由服主决定 workspace 与 Tailscale access mode；随后安装并配置 CLI，按客户端与模式排查 VPN/代理，以 Rules Enhancement 完整适配 macOS Clash Verge 系统代理，并在必要时停于用户重载断点，其余客户端经证据化人工边界处理，再验证身份、membership 和全部本机 online runtimes、创建 agents、运行 smoke，并以 daemon 全局默认并发 `10` 持久化和核验获授权的自启动；新建 Codex agent 时显式使用无需 Windows sandbox setup 的固定启动参数，不处理日常 issue/task、provider CLI 或第二套 server。
- [multica-runtime-client](./multica-runtime-client/)：在 CLI、身份、daemon 和本机 runtimes 已配置的前提下，按明确授权防重复地新建 workspace 和 agents，或把自然语言工作转成单个可验收 issue；新建 Codex agent 时强制使用独立 home 可工作的固定 sandbox/approval 参数，随后按完整 ID 入队一次并读取 runs/messages 监控、续接、取消或按授权 rerun，同时检查跨 workspace 的 daemon 全局容量、活动、用量和日志，缺失接入前提时交回 `multica-client-setup`。
- [codex-subagent-testskill](./codex-only/codex-subagent-testskill/)：单 Skill 测试的默认入口；默认运行一次，也可按用户指定次数用 fresh 原生 subagents 做重复稳定性与压力测试，并记录逐次及总 wall-clock 时间，不冒充进程或认证级隔离。
- [codex-external-agent-testskill](./codex-only/codex-external-agent-testskill/)：仅在明确需要外部进程、登录或跨 runtime 行为时，由 Codex 通过本机缓存配置启动 Claude Code 或 OpenCode 测试一个 Skill；不再配置或启动 Codex target。
- [codex-subagent-workflow](./codex-only/codex-subagent-workflow/)：在当前 Codex 会话内用原生 subagents 编排生产任务；优先采用可信项目 `.codex/config.toml` 的标准 `[agents]` 角色，未配置角色时才从任务描述自动拆分，并由主 agent 集成验收。

## 社区来源

本节记录外部下载 Skill 的来源与用途，仅供仓库维护和 Codex 发现；网站构建明确排除
整个 `community/` 目录。

- [find-skill-skillhub-1.0.2](./community/find-skill-skillhub-1.0.2/)：在 SkillHub 按关键词和分类发现、筛选并推荐 skills。
- [mainpdf](./community/mainpdf/)：编辑、转换、OCR、拆分、合并并提取 PDF 的文字、表格和图片。
- [mermaid-diagram-1.0.0](./community/mermaid-diagram-1.0.0/)：把需求或文字描述转换为 Mermaid 流程图、架构图、时序图或思维导图。
