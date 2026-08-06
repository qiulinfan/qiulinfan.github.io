---
name: multica-local-dev
description: 在本机安装、启动、停止、检查与调试 Multica self-hosted server 和 daemon，并操作 workspace、runtime、agent、project/resource、issue、squad、autopilot、skill 与 repository。适用于本地安装或启动 Multica、切换或排查 profile、登录 runtime、查看 agent task 日志与产物、创建调度对象、连接本地目录或 Git 仓库，以及诊断 server/daemon/任务失败。profile、server、runtime 和工作流策略均取自用户要求或当前环境，不固定为某个测试配置。
---

# Multica local operations

把本 Skill 当作 Multica 本地环境与 CLI 的操作参考。只描述平台操作、可观测副作用和
故障定位；仓库权限、是否提交或 push、PR 策略、数据边界、评审标准和停止条件由用户
请求、目标项目文档与 agent instructions 决定，不在这里预设。

## 先解析目标环境

在执行写操作前，从用户要求或现有配置中确定：

- `Profile`：传给所有 `multica ... --profile <profile>` 命令；可以是任意已配置 profile。
- `ServerUrl` 与 `AppUrl`：self-host 常见值分别是
  `http://127.0.0.1:8080` 和 `http://127.0.0.1:3000`，但可覆盖。
- `MulticaRepo`：包含 `docker-compose.selfhost.yml` 的开源 Multica 仓库根目录。
- runtime：从 `multica runtime list` 的在线项中选择，并单独确认对应 provider CLI 已登录。
- workspace：从 `multica workspace list` 选择或创建。

不要把 daemon `online` 等同于 provider CLI 已认证。任务若报 `Not logged in`、401 或
provider access 错误，先完成对应 runtime 的登录，再重跑任务或改绑已认证 runtime。

## 可选 PowerShell 控制器

`scripts/mlt.ps1` 是 Windows PowerShell 辅助控制器；它不决定工作流策略。参数均可覆盖：

```powershell
$Skill = "<multica-local-dev Skill 目录>"
$Mlt = Join-Path $Skill "scripts\mlt.ps1"
$MulticaRepo = "C:\src\multica"
$Profile = "localtest"

& $Mlt status -MulticaRepo $MulticaRepo -Profile $Profile
& $Mlt up     -MulticaRepo $MulticaRepo -Profile $Profile
& $Mlt auto   -MulticaRepo $MulticaRepo -Profile $Profile
& $Mlt down   -MulticaRepo $MulticaRepo -Profile $Profile
```

可按需传 `-ServerUrl`、`-AppUrl`、`-WorkspaceName`、`-WorkspaceSlug`、
`-AutoEmail` 和 `-DevCode`。未传时脚本保留向后兼容的本地开发默认值。`down -Wipe`
会删除 Docker 数据卷并要求确认。

Windows 首次安装可运行：

```powershell
& (Join-Path $Skill "scripts\bootstrap.ps1") `
  -MulticaRepo $MulticaRepo -Clone -Up -Profile $Profile
```

bootstrap 只处理开源仓库、Multica CLI 和 Docker。Agent provider CLI（Codex、Claude、
OpenCode、OpenClaw 等）按实际选择另行安装和登录。

## 直接启动 self-hosted server

不使用辅助脚本时，在 Multica 仓库根执行：

```sh
docker compose -f docker-compose.selfhost.yml up -d
multica setup self-host \
  --profile <profile> \
  --server-url http://127.0.0.1:8080 \
  --app-url http://127.0.0.1:3000
multica daemon start --profile <profile>
```

检查：

```sh
curl -fsS http://127.0.0.1:8080/health
multica auth status --profile <profile>
multica daemon status --profile <profile>
multica workspace list --profile <profile> --output json
multica runtime list --profile <profile> --output json
```

停止 server 时，`docker compose ... down` 保留数据卷；`down -v` 删除数据卷。

## Daemon 与日志

```sh
multica daemon status  --profile <profile>
multica daemon restart --profile <profile>
multica daemon logs    --profile <profile> -n 100
multica daemon logs    --profile <profile> -f -n 100
```

默认路径通常是：

```text
~/.multica/profiles/<profile>/config.json
~/.multica/profiles/<profile>/daemon.log
~/multica_workspaces_<profile>/<workspace-id>/<task-id>/
```

路径以 `multica daemon status`、`multica issue runs` 或任务返回的 `work_dir` 为准。
PowerShell 控制器还提供 `logs`、`tasks`、`watch` 和 `debug` 命令。

## Workspace、runtime 与 agent

先列出当前状态，再使用返回的 UUID：

```sh
multica workspace list --profile <profile> --output json
multica runtime list   --profile <profile> --output json
multica agent list     --profile <profile> --output json

multica agent create --profile <profile> \
  --name "worker-name" \
  --description "What this agent operates" \
  --runtime-id <runtime-id> \
  --max-concurrent-tasks 1 \
  --output json
```

更新 runtime 或 instructions：

```sh
multica agent update <agent-id> --profile <profile> \
  --runtime-id <runtime-id> \
  --instructions "<instructions>" \
  --output json
```

## Project 与资源

Project 可以绑定 Git repository，也可以把本机目录直接作为 task 工作目录。添加
`local_directory` 前先从 daemon status/runtime 状态取得 daemon UUID：

```sh
multica project create --profile <profile> \
  --title "Project title" \
  --status in_progress \
  --output json

multica project resource add <project-id> --profile <profile> \
  --type local_directory \
  --local-path /absolute/path \
  --daemon-id <daemon-id> \
  --label "local workspace" \
  --output json

multica project resource list <project-id> --profile <profile> --output json
```

`local_directory` task 直接在该路径运行；同一 daemon 上对同一资源的写任务会受到资源
锁影响。路径中的现有 Git 状态不会被 Multica 自动 stash、commit 或恢复。

## Issue、任务与评论

```sh
multica issue create --profile <profile> \
  --title "Task title" \
  --description "Task contract" \
  --project <project-id> \
  --assignee-id <agent-or-squad-id> \
  --status todo \
  --output json

multica issue list <flags> --profile <profile> --output json
multica issue get <issue-id> --profile <profile> --output json
multica issue runs <issue-id> --profile <profile> --output json
multica issue run-messages <task-id> --issue <issue-id> --profile <profile> --output json
multica issue cancel-task <task-id> --issue <issue-id> --profile <profile> --output json
```

状态和评论有实际调度副作用：

- `backlog`：保存但不入队。
- `todo`：给当前 assignee 创建任务。
- `in_progress`：表示执行中；再次改状态前先看现有 runs，避免重复入队。
- `in_review`：普通工作流状态，具体含义由项目定义。
- `done`：结束 issue；staged child 全部完成时会唤醒父 issue 的 squad leader。
- `blocked`、`cancelled`：分别记录阻塞或取消；取消运行中 task 时优先用 `cancel-task`。
- 给已分派 issue 添加顶层评论会创建 comment task，并通常复用 provider session；不要把
  评论当作无副作用的备注。只想检查时使用 `comment list`。

```sh
multica issue comment list <issue-id> --profile <profile> --output json
multica issue comment add <issue-id> --profile <profile> \
  --content "Continue with this feedback" --output json
```

## Squad 与 staged children

Squad 只把父 issue 路由给 leader，不会自动 fan-out。leader 需要创建并分派 child：

```sh
multica squad create --profile <profile> \
  --name "Review squad" --leader <leader-agent-id> --output json

multica squad member add <squad-id> --profile <profile> \
  --member-id <worker-agent-id> --type agent --role worker --output json

multica issue create --profile <profile> \
  --title "Stage 1 implementation" \
  --parent <parent-issue-id> --stage 1 \
  --project <project-id> --assignee-id <worker-agent-id> \
  --status todo --output json
```

同一 stage 的 children 全部进入终态后，父 issue 的 leader 会收到唤醒。评审标准、修复
轮数以及父子状态如何推进由 squad instructions 定义。

## Autopilot

```sh
multica autopilot create --profile <profile> \
  --title "Supervisor" \
  --description "<run prompt>" \
  --agent <agent-id> \
  --mode run_only \
  --project <project-id> \
  --output json

multica autopilot trigger-add <autopilot-id> --profile <profile> \
  --kind schedule --cron "0 * * * *" --timezone Asia/Shanghai \
  --label "hourly" --output json

multica autopilot trigger <autopilot-id> --profile <profile> --output json
multica autopilot runs <autopilot-id> --profile <profile> --output json
```

`run_only` 直接运行 agent；`create_issue` 按模板创建 issue。使用 `autopilot get` 检查
trigger 的 `enabled`、`next_run_at` 和 timezone。

## Repository 与 Skill

远程仓库注册：

```sh
multica repo add <git-url> --description "Repository" --profile <profile>
multica repo list --profile <profile> --output json
multica repo checkout <git-url> --ref <branch-or-sha>
```

`repo checkout` 在 task workdir 中创建 Git worktree。clone、提交、push 与 PR 行为取决于
任务指令、凭据和目标仓库规则；Multica 本身不替代这些授权。

将 Skill 交给 Multica agent 时，可以使用工作区托管方式：

```sh
multica skill import --file <skill.zip> --profile <profile>
multica skill list --profile <profile> --output json
multica agent skills add <agent-id> --skill-ids <skill-id> --profile <profile>
multica agent skills list <agent-id> --profile <profile> --output json
```

也可以使用所选 provider CLI 原生支持的用户级 Skill 目录；路径和发现行为由 provider
决定，不要假定所有 runtime 都读取同一个目录。

## 快速排障顺序

1. 检查 Docker 容器与 backend `/health`。
2. 检查 `auth status`、workspace 与 daemon 状态。
3. 检查 runtime 是否 online，并直接验证 provider CLI 登录。
4. 读取 `issue runs`、`run-messages` 与 daemon logs。
5. 检查 task `work_dir`、project resource、目标分支和文件状态。
6. 根据返回的失败类型修复后，选择 rerun、评论续跑或创建新 task。

命令参数可能随 CLI 版本变化；不确定时先运行对应的 `--help`，以本机 CLI 输出为准。
