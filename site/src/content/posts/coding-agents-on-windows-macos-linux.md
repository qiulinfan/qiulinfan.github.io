---
title: 三系统 Coding Agent 安装与选择：Claude Code、Codex、OpenCode，以及 OpenClaw、Hermes 与 Multica
published: 2026-07-13
description: 在 Windows、macOS、Linux 上安装三款主流 coding agent，并厘清个人自主 Agent 和 multi-agent 协作平台的区别。
image: ""
tags: [AI, Coding Agent, CLI, Multi-Agent]
category: 工具
draft: false
lang: zh_CN
---

过去一年里，“Agent”几乎被用来描述所有带工具调用的 AI 产品。但把它们真的装到电脑上以后，会发现它们至少分成三层：

1. **Coding agent**：进入一个代码仓库，读文件、改代码、运行命令、测试和提交；
2. **Personal autonomous agent**：长期运行，有记忆、定时任务和聊天渠道，能处理编程之外的事务；
3. **Multi-agent management plane**：不亲自写代码，而是管理多个 agent 的任务、运行环境和协作关系。

这篇文章先在 Windows、macOS、Linux 上安装三款 coding agent：**Claude Code、Codex、OpenCode**；再讨论 **OpenClaw、Hermes** 为什么属于另一类产品；最后看看 **Multica** 如何把这些 agent 组织成团队。

| 层级 | 解决的问题 | 本文项目 |
| --- | --- | --- |
| L1：仅 Agent | 在当前仓库中完成一次编码任务 | Claude Code、Codex、OpenCode |
| L2：Agent + 记忆 + 调度 | 跨会话记忆、定时运行、从聊天渠道持续接活 | OpenClaw、Hermes |
| L3：分布式 Agent 调度平台 | 跨机器、跨供应商分派、观察和管理许多 agent | Multica |

L2 并不是“能力更强的 L1”，L3 也不是“更大的模型”。三个层级可以叠加：Multica 调度 Hermes，Hermes 再调用 coding subagent，是一种合理的组合；但层级越高，权限面、常驻进程和运维责任也越大。

> 本文命令核对于 **2026-07-13**。Agent CLI 更新很快，实际安装前最好再点开文末官方文档确认一次。

## 先给结论

如果只想选一个：

- 已经重度使用 Claude，希望得到完整、统一的 Claude 工具链：选 **Claude Code**；
- 已经订阅 ChatGPT，重视沙箱、审批和 OpenAI/Codex 工作流：选 **Codex**；
- 想自由切换模型供应商、查看开源实现、深度定制 TUI：选 **OpenCode**；
- 想要一个能常驻服务器、接入聊天软件、定时工作的个人助理：研究 **OpenClaw** 或 **Hermes**；
- 想同时管理许多 Claude Code、Codex、OpenCode 实例：在它们上面加一层 **Multica**。

一个重要原则是：**比较 agent 时，要把“模型能力”和“agent harness 能力”分开。** OpenCode 可以连接 Claude、OpenAI 或其他模型；同一个模型放在不同 harness 中，也会因为上下文管理、工具、权限、提示词和压缩策略而产生不同体验。

## 三系统的共同准备

### macOS

建议先装 Homebrew 和 Git。Node.js 只在选择 npm 安装方式时需要：

```bash
xcode-select --install
brew install git node
```

### Linux

以 Ubuntu/Debian 为例：

```bash
sudo apt update
sudo apt install -y git curl ca-certificates
```

如果使用 npm 安装 OpenCode 或 Codex，再安装一个仍受支持的 Node.js 版本。不要为了省事长期依赖发行版仓库里过旧的 Node/npm。

### Windows

三款工具现在都能以某种形式运行在原生 Windows 上，但如果项目本身使用 Linux 工具链，我仍建议统一放进 **WSL2**：

```powershell
wsl --install
```

重启后进入 Ubuntu，把仓库 clone 到 WSL 的 `~/code`，而不是长期放在 `/mnt/c`。这样通常能获得更好的文件系统性能、权限语义和 shell 兼容性。

原生 Windows 更适合依赖 Visual Studio、PowerShell、Windows SDK 或其他 Windows-only 工具的项目。

## L1：仅 Agent

这一层的生命周期通常从 `cd project` 开始，到一次任务或一次会话结束。它们可以有 subagent，但核心对象仍是当前代码仓库。

### Claude Code

Claude Code 是 Anthropic 的 coding agent。它提供内置文件/搜索/命令工具，并围绕 `CLAUDE.md`、Skills、MCP、Hooks、Subagents 和 Agent Teams 形成了较完整的扩展体系。

#### macOS / Linux / WSL2

Anthropic 当前推荐原生安装器：

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude --version
claude doctor
```

macOS 也可以走 Homebrew 的稳定频道：

```bash
brew install --cask claude-code
```

#### Windows 原生

PowerShell：

```powershell
irm https://claude.ai/install.ps1 | iex
claude --version
```

也可以使用 WinGet：

```powershell
winget install Anthropic.ClaudeCode
```

原生 Windows 建议安装 Git for Windows；如果没有 Git Bash，Claude Code 会回退到 PowerShell。需要沙箱化命令执行时优先选择 WSL2，因为 Anthropic 文档明确说明 native Windows 暂不支持 sandboxing。

#### 登录与启动

```bash
cd /path/to/project
claude
```

首次启动会打开登录流程。Claude Code 支持 Claude Pro、Max、Team、Enterprise、Console，也能通过 Bedrock、Vertex AI 等第三方平台接入。

#### 它的优势

- Claude 生态的一体化体验，配置和模型能力衔接自然；
- `CLAUDE.md`、Skills、Hooks、MCP、Subagents 都有成熟的一等支持；
- Subagent 能隔离上下文，Agent Teams 能让独立会话共享任务并互相通信；
- 原生安装器可以后台自动更新。

#### 需要留意

- 主要围绕 Claude 模型与 Anthropic 账户体系；
- Agent Teams 仍属于实验功能；
- 原生 Windows 与 WSL2 的沙箱能力不同；
- 不要盲目开启 `--dangerously-skip-permissions` 一类绕过保护的模式。

官方资料：[安装说明](https://code.claude.com/docs/en/installation)、[扩展体系](https://code.claude.com/docs/en/features-overview)、[Subagents](https://code.claude.com/docs/en/sub-agents)。

### Codex

Codex 是 OpenAI 的本地 coding agent CLI，同时还存在 IDE、桌面应用和云端形态。CLI 适合在仓库中执行读写文件、命令、测试、审查与自动化任务，并用 sandbox 和 approval policy 控制风险。

#### macOS / Linux

官方安装脚本：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex --version
```

macOS 也可以使用 Homebrew：

```bash
brew install --cask codex
```

或者在已经有现代 Node.js/npm 的机器上：

```bash
npm install -g @openai/codex
```

#### Windows

官方 PowerShell 安装器：

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
codex --version
```

Codex 已提供 Windows 构建，但官方系统要求文档仍把 Windows 11 + WSL2 作为标准支持路径。对跨平台工程，WSL2 通常也是更稳妥的基线。

#### 登录与启动

```bash
cd /path/to/project
codex
```

首次启动选择 **Sign in with ChatGPT**。官方建议 Plus、Pro、Business、Edu、Enterprise 用户直接使用 ChatGPT 账户；也可以另行配置 API key。

#### 它的优势

- OpenAI/Codex 模型与 ChatGPT 订阅的直接整合；
- CLI、IDE、桌面、Web/Cloud 等多种工作入口；
- 对 sandbox、网络和文件权限、命令审批有明确的控制层；
- `AGENTS.md` 可以把项目约定随仓库一起提交；
- 适合把重复流程保存成 Skills，或通过 MCP/插件连接外部系统。

#### 需要留意

- 不同 Codex surface 的能力并不完全相同，CLI、桌面和云端不能简单视为同一个 UI；
- Windows 用户要留意 native 与 WSL2 的环境边界；
- API key 计费和 ChatGPT 套餐内使用是两条不同的认证/计费路径；
- 自动批准写文件、联网和执行命令之前，先理解当前 sandbox 与 approval 设置。

官方资料：[Codex 官方仓库与安装命令](https://github.com/openai/codex)、[系统要求](https://github.com/openai/codex/blob/main/docs/install.md)、[Codex 文档](https://developers.openai.com/codex)。

### OpenCode

OpenCode 是开源、provider-neutral 的 coding agent。它既有 TUI，也提供桌面应用和 IDE 扩展。与前两者相比，它最大的差异不是“某个固定模型更强”，而是**允许你选择和组合不同模型供应商**。

#### macOS / Linux / WSL2

官方安装脚本：

```bash
curl -fsSL https://opencode.ai/install | bash
opencode --version
```

macOS/Linux 也可以用官方 tap：

```bash
brew install anomalyco/tap/opencode
```

或者 npm：

```bash
npm install -g opencode-ai
```

#### Windows

官方仍推荐 WSL2；在 WSL 中执行 Linux 安装命令即可。原生 Windows 也有多种方式：

```powershell
choco install opencode
# 或
scoop install opencode
# 或
npm install -g opencode-ai
```

#### 连接模型并初始化仓库

```bash
cd /path/to/project
opencode
```

进入 TUI 后：

```text
/connect
/init
```

`/connect` 用来登录 OpenCode Zen 或其他模型 provider；`/init` 会分析仓库并创建 `AGENTS.md`。

#### 它的优势

- 开源且 provider-neutral，可在多种商业/开源模型之间切换；
- TUI、Desktop、IDE 多种入口；
- permissions 可以按 `read`、`edit`、`bash`、`websearch`、`task`、`external_directory` 等工具细分；
- 支持 primary agent、subagent 和针对不同 agent 的模型/权限配置；
- 对希望观察、修改 agent harness 的用户更友好。

#### 需要留意

- “自由选择 provider”也意味着认证、模型能力、价格和稳定性需要自己管理；
- 不同模型对工具调用和长任务的表现差异很大；
- OpenCode 本身开源，不代表你连接的云模型或 API 免费；
- Windows 虽能原生运行，官方仍建议 WSL 获得更完整体验。

官方资料：[快速开始](https://opencode.ai/docs/)、[Windows/WSL](https://opencode.ai/docs/windows-wsl/)、[Providers](https://opencode.ai/docs/providers/)、[Agents 与权限](https://opencode.ai/docs/agents/)。

## Claude Code、Codex、OpenCode 横向比较

| 维度 | Claude Code | Codex | OpenCode |
| --- | --- | --- | --- |
| 核心定位 | Anthropic 的 coding agent | OpenAI 的 coding agent 与多 surface 工作流 | 开源、provider-neutral agent harness |
| 默认生态 | Claude / Anthropic | OpenAI / ChatGPT / Codex | OpenCode Zen 或自选 provider |
| 开源情况 | CLI 产品本身不是以完全开源 harness 为卖点 | CLI 核心仓库 Apache-2.0 | 开源 |
| 项目指令 | `CLAUDE.md` | `AGENTS.md` | `AGENTS.md` |
| 扩展 | Skills、MCP、Hooks、Plugins | Skills、MCP、Plugins、Hooks/配置 | Agents、Plugins、MCP、Commands、Skills |
| 多 Agent | Subagents；实验性 Agent Teams | Subagents/协作能力依 surface 和版本而异 | Primary agents + subagents + task 权限 |
| 权限控制 | 工具权限、Hooks、sandbox（平台有差异） | sandbox + approval policy | 每类工具 `ask/allow/deny`，支持 pattern |
| 模型自由度 | 主要是 Claude 生态 | 主要是 OpenAI/Codex 生态 | 最灵活，可接多 provider |
| Windows 建议 | Native 或 WSL2；沙箱优先 WSL2 | 标准支持路径优先 WSL2 | 官方推荐 WSL2 |
| 最适合 | 想获得完整 Claude 工作流的人 | ChatGPT/OpenAI 用户、重视受控执行的人 | 想换模型、看源码、深度定制的人 |

### 不要只看 benchmark

对日常开发更重要的往往是：

- 它是否正确理解现有仓库规则；
- 修改前是否会先读测试和相关代码；
- 长任务中能否保持计划与状态；
- 出错后是否会诊断，而不是反复试错；
- 权限边界是否符合你的风险承受能力；
- 最终 diff 是否容易审查。

最公平的比较方法，是让三者在同一个仓库完成同一组真实任务：一个小 bug、一个跨文件 feature、一次代码审查和一次测试失败诊断。记录成功率、用时、人工干预次数、最终 diff 与实际费用，而不是只比较第一轮回答有多惊艳。

## 安装只是第一天：版本更新与健康检查

Agent 拥有 shell、文件和网络权限，版本更新不是为了追新功能，而是安全维护的一部分。建议每月至少检查一次；出现磁盘、CPU、内存、登录或权限异常时，第一步先记录版本和进程，再查官方 issue，不要让 agent 在未知根因下自动“清理系统”。

### 更新命令速查

先运行版本命令，更新后再运行一次，确认实际 binary 已变化：

| 工具 | 查看版本 | 推荐更新方式 |
| --- | --- | --- |
| Claude Code | `claude --version` | 原生安装：`claude update`；Homebrew：`brew upgrade --cask claude-code`；WinGet：`winget upgrade Anthropic.ClaudeCode` |
| Codex | `codex --version` | 安装脚本：重新运行官方 installer；npm：`npm install -g @openai/codex@latest`；Homebrew：`brew upgrade --cask codex` |
| OpenCode | `opencode --version` | `opencode upgrade`；检测错误时显式指定 `--method curl/npm/pnpm/bun/brew` |
| OpenClaw | `openclaw --version` | 先 `openclaw update status` 或 `openclaw update --dry-run`，再 `openclaw update` |
| Hermes | `hermes version` | 先 `hermes update --check`，高价值配置用 `hermes update --backup` |
| Multica | `multica version` | `multica update`；自托管还要按 release notes 更新 server/container |

通过系统包管理器安装的工具，最好继续用同一个包管理器升级。混用 installer、npm、Homebrew 后，PATH 中可能同时存在多个版本；更新“成功”却仍运行旧 binary 时，检查：

```bash
which -a claude codex opencode openclaw hermes multica
```

PowerShell 使用：

```powershell
Get-Command claude,codex,opencode,openclaw,hermes,multica -All
```

### Codex SSD 写入事件：为什么必须更新

2026 年 6 月的 [openai/codex#28224](https://github.com/openai/codex/issues/28224) 报告了一个严重的 SQLite 日志写入放大问题：报告者的机器运行约 21 天后，主 SSD 累计写入约 **37 TB**。高频 TRACE、WebSocket/SSE payload 和镜像 OTel 日志持续写入：

```text
~/.codex/logs_2.sqlite
~/.codex/logs_2.sqlite-wal
~/.codex/logs_2.sqlite-shm
```

数据库保留的逻辑内容可能只有几百 MB，但“插入 → WAL → 索引 → prune/checkpoint”的循环会造成远高于文件大小的物理写入量，所以只看 `du ~/.codex` 会严重低估 SSD 压力。其他官方 issue 也记录了 streaming 时约 5 MiB/s、峰值约 16 MiB/s 的持续写入，以及数分钟内 WAL 增长到上百 MB的情况。

官方仓库记录的关键缓解是：

- Codex `0.142.0`：停止记录每个 Responses WebSocket event，并过滤 noisy targets；
- Codex `0.143.0`：停止持久化 bridged log events。

报告者称这几项改动减少了约 85% 的日志。因此本文的最低建议是：**不要继续运行低于 `0.143.0` 的 Codex；优先升级到当前 latest，并在升级后实际监控。** “减少 85%”不等于所有 SQLite/WAL 写入问题都已永久消失。

```bash
codex --version

# npm 安装
npm install -g @openai/codex@latest

# Homebrew 安装
brew upgrade --cask codex
```

检查日志文件大小：

```bash
du -h ~/.codex/logs_2.sqlite* 2>/dev/null
```

PowerShell：

```powershell
Get-ChildItem "$HOME\.codex\logs_2.sqlite*" |
  Select-Object Name,Length,LastWriteTime
```

Linux 可以在使用 Codex 时观察：

```bash
sudo iotop -oPa
```

macOS 可在 Activity Monitor 的 Disk 页面观察 Codex/Code Helper 写入，或用 `fs_usage` 做短时间诊断。重点不是某一刻 WAL 有多大，而是**空闲或普通 streaming 时是否仍持续高速写盘**。

如果暂时无法升级且明确观察到该问题，官方 issue 中的临时方案是在完全退出 Codex 后，用 SQLite trigger 阻止诊断日志插入：

```bash
sqlite3 ~/.codex/logs_2.sqlite \
  'CREATE TRIGGER IF NOT EXISTS block_log_inserts BEFORE INSERT ON logs BEGIN SELECT RAISE(IGNORE); END;'
```

恢复诊断日志：

```bash
sqlite3 ~/.codex/logs_2.sqlite \
  'DROP TRIGGER IF EXISTS block_log_inserts;'
```

这会牺牲本地诊断日志，不是正式修复。应当优先升级，并在操作数据库前完全退出 Codex、备份重要工作。更早的复现和 workaround 见 [#17320](https://github.com/openai/codex/issues/17320)，Desktop/WAL 的另一组数据见 [#24275](https://github.com/openai/codex/issues/24275)。

### 常驻 Agent 的更新更像运维

OpenClaw、Hermes 和自托管 Multica 会运行 daemon/gateway。更新前额外确认：

1. 配置、记忆、Skills、凭据和数据库有备份；
2. release notes 是否包含配置迁移；
3. 当前任务是否可以安全中断；
4. 更新后 daemon/gateway 是否已重启并报告新版本；
5. 聊天渠道、cron、webhook 与 agent runtime 是否仍健康。

OpenClaw 的 `update --dry-run` 和 Hermes 的 `update --check` 都适合先只读预检；生产环境不要默认追 `dev` 或 beta channel。

## L2：具有记忆和调度功能的 Agent

OpenClaw 和 Hermes 都可以写代码，也都能调用 subagent，但它们更接近**长期运行的个人 agent 平台**。它们不是“另两个 Claude Code”：重点从一次仓库任务转向跨会话记忆、定时运行、消息渠道和常驻 Gateway。

### OpenClaw

OpenClaw 强调 Gateway、工作区、Skills、定时/自动化和多聊天渠道。它适合运行在个人电脑或服务器上，从 Telegram、Discord、Slack 等入口接收任务。

系统要求是 Node 22.19+、23.11+ 或 24+。推荐安装方式：

```bash
# macOS / Linux / WSL2
curl -fsSL https://openclaw.ai/install.sh | bash

# Windows PowerShell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

安装器会进入 onboarding；已有 Node 环境也可以用 npm 安装。详细方式见 [OpenClaw 安装文档](https://docs.openclaw.ai/install) 和 [官方仓库](https://github.com/openclaw/openclaw)。

### Hermes Agent

Hermes 是 Nous Research 的 autonomous agent，重点是 persistent memory 和内置 learning loop：它会从经验中创建、改进 Skills，并能够跨会话积累对用户和任务的理解。官方还强调定时任务、跨聊天渠道、隔离 subagents，以及 local、Docker、SSH、Singularity、Modal 等 sandbox backend。

```bash
# Linux / macOS / WSL2 / Termux
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# Windows PowerShell
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
```

安装后可用 `hermes setup --portal` 完成模型与工具配置。官方资料：[Hermes 文档](https://hermes-agent.nousresearch.com/docs/)、[Nous Research 产品页](https://nousresearch.net/hermes-agent/)、[官方仓库](https://github.com/NousResearch/hermes-agent)。

### 两者怎么选

| 维度 | OpenClaw | Hermes |
| --- | --- | --- |
| 核心心智 | 自托管个人助理与 Gateway | 会持续学习的个人 autonomous agent |
| 突出能力 | 多渠道接入、工作区、广泛集成、daemon | 记忆、Skills 学习循环、调度、隔离执行 |
| 运行方式 | 本机/服务器常驻 Gateway | 本机、服务器、容器或云 sandbox |
| 适合 | 想快速搭一个跨渠道个人助理 | 希望 agent 长期积累习惯与可复用能力 |

它们拥有比 coding CLI 更长的生命周期和更广的权限面。不要一上来就给它邮箱、浏览器登录态、SSH key、云账号和无限 shell 权限。先用单独账号、最小权限、隔离容器和可审计日志做实验。

## L3：Agent 分布式调度平台

Multica 与上面五个项目的关系最容易被误解。它不是第六个模型，也不是又一个终端 coding agent；它是一个 **open-source managed agents platform**。这一层关心的是跨机器 runtime、任务队列、状态、路由、团队和复用，而不是某一轮对话如何生成代码。

可以把层次画成：

```text
人类 / 团队
    ↓ 创建 Issue、分派、评论、审查
Multica（任务、Squad、Runtime、状态、Autopilot、Skills）
    ↓ 调度
Claude Code / Codex / OpenCode / OpenClaw / Hermes / 其他 CLI
    ↓ 执行
本地机器 / Worktree / 云主机 / 自托管 Runtime
```

Multica daemon 会检测机器 PATH 上可用的 agent CLI。你在 board 上把 issue 分配给一个 agent 后，系统负责 enqueue、claim、start、complete/fail 等生命周期，实时展示进度；Squad 用一个稳定的团队入口把工作路由给成员，Autopilot 则用 cron、webhook 或手动触发重复任务。

### 安装

macOS/Linux：

```bash
brew install multica-ai/tap/multica
# 或
curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh | bash
```

Windows PowerShell：

```powershell
irm https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.ps1 | iex
```

然后连接 Cloud 并启动 daemon：

```bash
multica setup
```

如果要自托管完整服务，则需要 Docker，并按 [Self-hosting 文档](https://github.com/multica-ai/multica/blob/main/SELF_HOSTING.md) 部署。

Multica 的价值在 agent 数量超过一两个之后才明显：它把散落在不同终端、不同机器、不同供应商中的执行过程，变成可分派、可观察、可复用的团队工作流。官方资料：[Multica 仓库](https://github.com/multica-ai/multica)、[中文 README](https://github.com/multica-ai/multica/blob/main/README.zh-CN.md)。

## 非必要不跑命令行：让一个 Agent 安装其他 Agent

Harness 时代，一个合理的期待是：用户不必手动复制本文几十条命令。只要机器上已经有一个可用的 coding agent，就应该让它读取安装 runbook、检测环境、展示计划，然后代为执行。

但这里存在一个无法消除的 bootstrap：**如果新机器上一个 agent 都没有，第一次仍要通过图形安装器、WinGet/Homebrew，或一条官方安装命令装好 seed agent。** 之后就可以“用 agent 安装 agent”。

### 1. Clone 这份 runbook

```bash
git clone https://github.com/qiulinfan/qlblog.git
cd qlblog
```

仓库中的 [`install/agent-stack.md`](https://github.com/qiulinfan/qlblog/blob/main/install/agent-stack.md) 是给人和 agent 共同阅读的安装说明。`AGENTS.md` 与 `CLAUDE.md` 会引导 Codex、OpenCode、Claude Code 找到它。

### 2. 用你已有的 agent 打开仓库

三选一即可：

```bash
codex
# 或 claude
# 或 opencode
```

然后直接输入：

```text
请完整阅读 install/agent-stack.md。
先只读检测我的操作系统、架构、shell、WSL、包管理器、Node/npm 版本，
以及已经安装的 agent。不要立即安装。

检测后给我一个计划，列出：
1. 已安装和缺失的工具；
2. 建议使用 native Windows 还是 WSL2；
3. 每个安装动作的官方来源、是否需要管理员权限；
4. 哪些动作会安装 daemon、gateway、登录项或定时任务；
5. Codex 是否至少为 0.143.0，以及如何监控 logs_2.sqlite 的写盘。

等我确认具体产品和层级后再执行。每安装一个工具，都验证 binary 路径和版本。
```

### 3. 按层级授权，而不是说“全部装上”

推荐分三次：

```text
第一步只安装 L1：Claude Code、Codex、OpenCode。不要安装常驻服务。
```

用一段时间以后再决定：

```text
现在评估 L2。比较 OpenClaw 和 Hermes 对我的需求；只安装我选中的一个，
先不要接入聊天账号，也不要启动 daemon/gateway，直到再次得到我的确认。
```

最后才考虑调度平台：

```text
现在安装 Multica CLI，但不要运行 multica setup，也不要部署自托管服务。
先展示它将创建的配置、daemon 和网络连接，等我确认。
```

### 4. 为什么不提供“一键全自动脚本”

因为六个项目跨越三个权限层级：L1 修改代码，L2 可能常驻并连接私人渠道，L3 可能在多台机器调度它们。一个无确认的安装脚本无法理解：

- 你想用 native Windows 还是 WSL2；
- 已有工具是 npm、Homebrew 还是 installer 管理；
- 是否允许后台服务和开机启动；
- API key、ChatGPT/Claude 订阅与模型 provider 如何选择；
- Multica 用 Cloud 还是自托管；
- 哪些账号和目录允许 agent 访问。

所以这里的自动化边界是：**agent 负责检测、查官方文档、执行和验证；人负责选择层级、授权持久化和提供凭据。** 这比一条 `install-everything.sh` 慢一分钟，但安全得多，也更容易维护。

## 我的建议组合

### 个人开发者，先求稳定

先选 Claude Code 或 Codex 之一作为主力，再保留 OpenCode 用于跨 provider 实验。不要同时维护三套复杂配置。

### Windows + Linux 工具链

把仓库和三个 CLI 都放进 WSL2。Windows 浏览器仍可完成 OAuth，VS Code/Cursor 可以通过 Remote WSL 连接同一个文件系统。

### 多模型研究者

以 OpenCode 为统一界面，固定一组任务分别测试 Claude、OpenAI 和其他模型。比较时保存配置、模型版本、权限和提示词，否则结果不可复现。

### 想做 24/7 自动化

先在隔离 VPS 或容器里试 OpenClaw/Hermes，不要直接部署到存放全部私人数据的日常电脑。为每个外部服务创建最小权限凭据。

### 小团队管理多个 Agent

把 Claude Code、Codex、OpenCode 当作 worker，把 Multica 当作任务与运行时控制平面。代码 review 和最终合并仍然保留人类责任。

## 安全清单

无论选哪一个，至少做到：

1. 安装脚本来自官方 HTTPS 域名或官方 GitHub 仓库；
2. 对 `curl | bash`、`irm | iex` 有顾虑时，先下载并阅读脚本再执行；
3. 不把 API key 写进仓库、聊天记录、Notebook 输出或 core dump；
4. 默认开启审批和沙箱，从最小权限开始；
5. 给 GitHub、云平台、聊天渠道创建独立且可撤销的 token；
6. 自动化 push、发消息、发邮件、部署和删除资源前保留人工确认；
7. 定期检查 agent 创建的定时任务、daemon、Skills、MCP server 和日志；
8. 把 AI 生成的 diff 当作未经审查的外部贡献。

## 结语

Claude Code、Codex、OpenCode 解决的是“**这个仓库里的工作如何完成**”；OpenClaw、Hermes 解决的是“**这个长期在线的个人 agent 如何记忆、接收和执行任务**”；Multica 解决的是“**很多 agent 如何像团队成员一样被分派、观察和管理**”。

与其寻找一个包打天下的产品，不如先选对层级，再组合工具。对大多数开发者，最健康的起点仍然是：一个主力 coding agent、清楚的权限边界、可复现的测试，以及一个愿意认真看 diff 的人。
