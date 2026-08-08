---
name: multica-runtime-client
description: 把 Windows、macOS 或 Linux 机器加入一个已有且明确许可该成员的 Multica Server 与共享 workspace，并安装、独立认证、启动、停止、命名、检查和调试 Multica CLI、daemon、provider CLI 与 runtime；创建全 workspace 可调用的 agent，运行端到端 smoke task，并在用户确认后配置 Windows 登录任务或 macOS LaunchAgent。适用于服务器宿主机注册为第一个 runtime，或朋友设备凭私网 Server URL、server signup 许可、workspace 邀请/成员资格和自己的身份认证加入第 2/3/N 个执行节点，以便互信团队调度彼此 runtime 上的 agents；也用于操作 workspace/project/resource/issue/squad/autopilot/repository/skill，或排查 signup、invite、OAuth callback、403、runtime offline、provider 未登录与跨设备本地目录问题。此 Skill 不部署 Docker、PostgreSQL、backend、frontend、Caddy 或第二套 Server；控制面与许可策略使用 multica-selfhost-server。
---

# Multica runtime client

只管理执行节点与已认证 CLI。服务器宿主机的首 runtime 和朋友机器的后续 runtime 使用
完全相同的加入流程；差别只在谁预先授予 server 与 workspace 许可。

## 加入契约

开始写操作前取得并核对：

- 一个绝对 `ServerUrl`；推荐受控私网中的同源 HTTPS，此时 `AppUrl = ServerUrl`。
- 目标共享 workspace 的 slug、ID 或无歧义短前缀。
- 当前用户自己的邮箱/身份已经被 server allowlist 许可，并已收到且接受该 workspace 邀请。
- 本机设备名、runtime 名、目标 provider 和并发限制。
- provider CLI 已安装并使用本机所有者自己的凭据登录。

地址本身不是加入凭证。不要自动扫描局域网，不从日志猜 server，不使用另一台机器的
`127.0.0.1`，也不要接受 owner 的 PAT、验证码、cookie 或 provider 凭据作为“快捷加入”。
如果 signup 被拒绝、邀请未接受或 `workspace get` 返回 403，停止客户端配置并让
server owner/admin 完成许可；客户端不得修改远程 server 的 allowlist 或伪造 membership。

只有旧式前后端双域/双端口部署才显式覆盖 `AppUrl`。Server URL 可以来自
`multica-selfhost-server` 的 `connection.json`，但 handoff 还必须单独包含 workspace slug
与该成员的邀请状态；回执永远不携带 token。

## 完成条件

只有以下条件全部成立，才报告此机器已加入集群：

1. `auth status` 显示当前用户、正确 server 和有效的独立凭据。
2. `workspace get <target>` 成功，profile 默认 workspace 已切换到目标共享 workspace。
3. daemon 运行，按 daemon/workspace/runtime IDs 识别的本机 provider runtime 为 `online`。
4. provider CLI 自己的登录检查成功；daemon `online` 不能替代 provider 认证。
5. 至少一个 agent 绑定该本机 runtime，并显式允许整个 workspace 调用。
6. 一个无破坏性的 smoke task 在该 agent 上完成，而非只进入队列。

## 信任与权限边界

- 把此集群视为明确互信的小团队：workspace 成员可以调度开放给 workspace 的 agent，任务
  在 agent 所绑定 runtime 的本地权限范围内执行。
- 不共享人类或 provider 身份。Multica PAT 属于个人；daemon token 由 daemon 自动管理并
  绑定 workspace；provider 凭据始终留在对应机器。
- `permission_mode=public_to` 加 workspace target 才表示团队可调用。新 agent 默认私有，
  不能把“其他人看得到 agent”当作“其他人能运行 agent”。
- 本 Skill 不授权 agent 随意访问整台主机、提交/push/开 PR、读取秘密或修改外部系统；
  这些仍受用户任务、目标仓库规则、runtime OS 用户与具体 agent instructions 约束。
- 持久 daemon、LaunchAgent 或 Scheduled Task 只在用户明确确认后安装。

## 加入前的 server 侧握手

让 server owner/admin 先完成：

1. 把新成员准确邮箱加入 server 的 `ALLOWED_EMAILS`，并保持私有集群
   `ALLOW_SIGNUP=false`。
2. 发送共享 workspace 邀请：

   ```sh
   multica workspace member invite friend@example.com friends-compute \
     --role member --profile home --output json
   ```

3. 让成员用自己的身份接受邀请。邀请不会绕过 signup allowlist；新账号必须同时通过两层。
4. 只传递私网 Server URL、workspace slug 与邀请渠道。

普通 `member` 足以运行对整个 workspace 开放的 agents。只有确实需要邀请、成员管理或
其他管理能力时才授予 `admin`；不要为了“完全信任”默认复制 owner 角色。

## macOS/Linux 一地址搭建

先登录要用于执行任务的 provider CLI，再运行：

```sh
SKILL="$HOME/.codex/skills/multica-runtime-client"
/bin/sh "$SKILL/scripts/connect-runtime-client.sh" \
  --server-url "https://home-pc.example.ts.net" \
  --workspace friends-compute \
  --profile home \
  --device-name "MacBook" \
  --runtime-name "MacBook Codex"
```

缺少 Multica CLI 时，macOS 使用 Homebrew，Linux 使用下载到临时文件后再执行的官方安装器。
浏览器与 CLI 同机时 callback host 默认为 `127.0.0.1`；SSH/headless 场景遵循 CLI 输出的
tunnel 或 PAT 提示，不把 token 写进命令历史。

脚本必须在登录后执行 `workspace switch` 并验证 membership。一个账号属于多个 workspace
时，不得让脚本自行选列表第一项。

## Windows 一地址搭建

在提供 provider CLI 的 Windows 宿主机运行：

```powershell
$Skill = "$HOME\.codex\skills\multica-runtime-client"
& (Join-Path $Skill "scripts\connect-windows-runtime-client.ps1") `
  -ServerUrl "https://home-pc.example.ts.net" `
  -Workspace friends-compute `
  -Profile home `
  -DeviceName "Laptop" `
  -RuntimeName "Laptop Codex"
```

Windows + WSL server 的首 runtime 也使用这条 Windows 原生命令，不在 WSL Docker 内启动
provider。server 与 client 同机但仍使用旧式双端口时，额外传
`-AppUrl http://127.0.0.1:3000`。

## 单次恢复与验证

macOS/Linux：

```sh
/bin/sh "$SKILL/scripts/start-runtime-client.sh" \
  "https://home-pc.example.ts.net" home "MacBook" "MacBook Codex" 1 \
  "https://home-pc.example.ts.net" 120 0s friends-compute

multica auth status --profile home
multica workspace get friends-compute --profile home --output json
multica daemon status --profile home --output json
multica runtime list --profile home --output json
```

Windows 使用 `scripts/start-windows-runtime-client.ps1 -Workspace friends-compute`。按
`daemon status` 返回的 daemon ID、目标 workspace 与 runtime IDs 识别本机 runtime；不要
取 `runtime list` 第一项，也不要把其它机器的 online runtime 当作本机成功。

直接运行目标 provider 的无副作用身份检查。若 provider 需要浏览器登录，在前台完成；
后台启动不得尝试 OAuth。

## 创建可共享 agent 并做 smoke task

从本机 daemon 在目标 workspace 中注册的 runtime IDs 选择正确 provider，然后运行：

```sh
multica agent create --profile home \
  --name "MacBook Codex" \
  --description "Trusted team agent on MacBook" \
  --runtime-id <local-runtime-id> \
  --permission-mode public_to \
  --public-to-workspace \
  --max-concurrent-tasks 1 \
  --output json
```

旧 CLI 若尚未支持 permission flags，先查 `agent create --help`，只在确认等价时使用
`--visibility workspace`；不要静默保留默认 private。

创建一个无破坏性的临时 issue，分派给该 agent，并确认 task `completed` 且返回预期内容：

```sh
multica issue create --profile home \
  --title "Runtime smoke test" \
  --description "Report runtime host/provider identity; do not modify files or external state." \
  --assignee-id <agent-id> --status todo --output json
multica issue runs <issue-id> --profile home --output json
multica issue run-messages <task-id> --issue <issue-id> --profile home --output json
```

正式共享前，让另一位 workspace 成员触发或分派一次 smoke task，证明 agent permission 与
跨成员调度都生效。issue、评论、状态和 autopilot 都有真实调度副作用；只读诊断优先使用
`list/get/runs`。

## 登录自启动

只在用户确认后配置。macOS：

```sh
/bin/sh "$SKILL/scripts/install-macos-autostart.sh" \
  "https://home-pc.example.ts.net" home "MacBook" "MacBook Codex" 1 \
  "https://home-pc.example.ts.net" 0s friends-compute
```

LaunchAgent 为 `dev.multica.runtime-client.<profile>`，日志位于
`~/Library/Logs/Multica/`。Windows：

```powershell
& (Join-Path $Skill "scripts\install-windows-autostart.ps1") `
  -ServerUrl "https://home-pc.example.ts.net" `
  -Workspace friends-compute `
  -Profile home `
  -DeviceName "Laptop" `
  -RuntimeName "Laptop Codex"
```

任务名默认 `Multica-RuntimeClient-<profile>`，使用当前用户交互式登录上下文且不保存 Windows
密码。自启动只恢复已经完成的认证；它不接受邀请、不完成 signup，也不替 provider 登录。

## Agent 与 workspace 对象

需要改绑时使用 `agent update <agent-id> --runtime-id <runtime-id>`。确认 agent owner 与
permission mode；只有 agent owner 能改变 invocation Access。workspace、project、resource、
issue、squad、autopilot、repository 与 workspace-hosted Skill 都通过这个已认证 profile
操作，实际参数先查 `--help`。

两台设备共同工作时优先注册 Git repository。`local_directory` 绑定具体 daemon ID，不能
跨设备解释 Windows 与 macOS 路径：

```sh
multica project resource add <project-id> --profile home \
  --type local_directory --local-path /absolute/path \
  --daemon-id <local-daemon-id> --label "local workspace" --output json
```

不要假设 runtime 共享 provider 凭据、Skills、环境变量、MCP、未提交文件或操作系统权限。

## 退出、撤销与排障

离开集群时先停止本机自启动与 daemon，再由 owner/admin 移除 membership、runtime/agent 和
server allowlist 邮箱；不要只让机器 offline 后保留长期访问。

按以下顺序排障：

1. 确认 Server URL 从本机可达，且不是另一台机器的 loopback 地址。
2. signup/登录失败时让 server owner 检查 `ALLOWED_EMAILS` 与 `ALLOW_SIGNUP`。
3. 运行 `auth status` 和 `workspace get`；403 通常表示邀请未接受或不属于目标 workspace。
4. 运行 `daemon status`，核对 OS、device、daemon ID、workspace 与 provider 路径。
5. 按 daemon/workspace IDs 查本机 runtime 是否 `online`，再直接验证 provider 登录。
6. agent 无法被朋友调用时检查 `permission_mode`、workspace target 和 agent owner。
7. 检查 macOS `~/Library/Logs/Multica/` 或 Windows `%LOCALAPPDATA%\Multica\`。
8. 本地目录错误时检查 resource 的 daemon ID；任务失败时看 `issue runs` 与
   `run-messages`。

命令参数会随 Multica 版本变化；执行前以本机 `--help` 和官方 CLI 文档为准。
