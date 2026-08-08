---
name: multica-selfhost-server
description: 在 Windows + WSL 或 macOS 上安装、启动、升级、发布、检查与调试 Multica self-host 控制面，并把服务器宿主机引导为共享集群的第一个已认证 runtime。管理 PostgreSQL、backend、Web frontend、Docker/Compose、同源网关、Tailscale 私网 HTTPS、登录与注册许可、共享 workspace、连接回执、备份和重启恢复；随后组合使用 multica-runtime-client 安装本机 CLI/daemon/provider runtime、创建全 workspace 可调用的 agent 并完成端到端验证。适用于在相互完全信任的朋友团队中建立唯一 Multica Server、首个执行节点和 invite-only agents 计算资源共享集群，以及排查 server、首节点、认证、邀请、CORS/WebSocket 或外部访问问题。后续机器只使用 multica-runtime-client，不部署第二套 server。
---

# Multica self-host server

把本 Skill 作为可信朋友团队的集群引导入口。建立一个控制面、一个共享 workspace 和至少
一个可执行 agent；服务器宿主机必须是第一个 runtime，后续机器再加入同一 workspace。

## 信任与身份模型

- 把“完全信任”解释为：成员有意允许共享 workspace 中的其他成员调度其公开给 workspace
  的 agents，并接受这些任务在对应 runtime 的本地权限边界内执行。
- 仍让每个人使用自己的 Multica 账号、PAT、daemon token 和 provider 登录。不要共享
  Multica PAT、验证码、provider API key、SSH key、浏览器 cookie 或操作系统账号。
- 同时满足 server 注册许可、workspace 邀请/成员资格和本机身份认证，才允许客户端加入。
  知道 Server URL 本身不构成许可。
- 只用于明确互信的小团队和受控私网；不要把此模型当作不互信多租户隔离或公开算力池。
- agent 任务拥有启动 daemon 的操作系统用户权限。选择专用用户、VM 或受限工作目录，
  不要把“朋友互信”误写成无限的主机权限。

## 完成条件

只有以下条件全部成立，才报告初始集群已建立：

1. PostgreSQL、backend、frontend 与 gateway 健康，私网地址从目标客户端可达。
2. 初始 owner 用自己的身份登录并创建或选择唯一共享 workspace。
3. 服务器宿主机上的 provider CLI 已登录；`multica-runtime-client` 已让本机 daemon 和至少
   一个 provider runtime 在该 workspace 中 `online`。
4. 至少一个 agent 绑定本机 runtime，并显式允许整个 workspace 调用。
5. 一个无破坏性的 smoke task 在该 agent 上完成；不能只验证 daemon `online`。
6. 交付不含凭据的 Server URL、workspace slug、邀请状态、首 runtime/agent ID 和恢复方式。

## 职责边界

- 本 Skill 管理 server、私网入口、账号注册许可、首个 workspace 和完整集群验收。
- 把宿主机 CLI、daemon、provider runtime、agent 绑定与自启动委派给
  `multica-runtime-client`；不要复制它的实现或在 Docker 容器内运行 provider。
- Windows + WSL 拓扑中，把 server 放在 Ubuntu WSL2 的 Docker Engine 内，把第一个
  runtime 放在 Windows 宿主机。不要把 WSL server 容器冒充 runtime。
- macOS 拓扑中，让 Docker server 和第一个 runtime 位于同一台 Mac，但保持两个独立
  进程与恢复项。
- 后续 Windows、macOS 或 Linux 机器只使用 `multica-runtime-client`，不克隆 server、
  不启动数据库，也不创建第二控制面。
- 持久 daemon、LaunchAgent、Scheduled Task、Tailscale Serve 和公开入口都需要用户明确
  确认。删除数据卷、固定验证码和公网入口始终单独确认。

## 先固定输入

在写操作前确认或从现有状态解析：

- 拓扑：`windows-wsl` 或 `macos`；原生 Windows Docker 只作为现有兼容部署维护。
- server checkout、profile、gateway 端口与可恢复的私网 HTTPS 地址。
- 初始 owner 邮箱、共享 workspace name/slug/issue prefix。
- 首个 runtime 的 provider、设备名、runtime 名和最大并发数。
- 允许注册的朋友邮箱；未提供时只允许初始 owner，稍后逐人添加。
- 是否现在配置 server 与 runtime 的登录自启动。

不要自动扫描局域网、猜邮箱、从日志提取或传播 token，也不要用同一个共享账号代替成员
邀请。已有 server 或 workspace 时先检查并复用，不重复创建。

## 连接契约

默认建立 `127.0.0.1:8787` 的 Caddy 同源 gateway；客户端只需一个 `ServerUrl`，并把
`AppUrl` 默认为同一地址。远程使用时把它发布为例如
`https://home-pc.example.ts.net`。gateway 把 `/ws`、`/api`、`/auth`、`/uploads` 和健康
检查转到 backend，其余请求转到 frontend。让 `FRONTEND_ORIGIN`、`MULTICA_APP_URL`、
`CORS_ALLOWED_ORIGINS` 和实际访问 URL 一致，保持 `COOKIE_DOMAIN` 为空。

每次成功启动写入：

```text
~/.multica/selfhost-server/<profile>/state.json
~/.multica/selfhost-server/<profile>/connection.json
```

`connection.json` 只保存地址、访问范围、server 设备和更新时间，不保存验证码、PAT、JWT、
数据库密码、邀请链接或 Tailscale 凭据。`local-only` 的 loopback 地址不能交给远程机器；
给成员的 handoff 另附 workspace slug 和其专属邀请状态。

## 阶段 1：启动唯一控制面

### Windows + WSL

在 Ubuntu WSL2 内运行 Docker Engine 与 server：

```powershell
$ServerSkill = "$HOME\.codex\skills\multica-selfhost-server"
& (Join-Path $ServerSkill "scripts\bootstrap-windows-wsl-server.ps1") `
  -WslDistro Ubuntu-26.04 -Profile home
```

脚本只启动控制面。单次恢复：

```powershell
& (Join-Path $ServerSkill "scripts\start-windows-wsl-server.ps1") `
  -WslDistro Ubuntu-26.04 `
  -LinuxRepo /home/<wsl-user>/multica `
  -Profile home
```

### macOS

先准备官方 Multica checkout 与可用的 Docker Desktop，再运行：

```sh
SERVER_SKILL="$HOME/.codex/skills/multica-selfhost-server"
/bin/sh "$SERVER_SKILL/scripts/start-macos-server.sh" "$HOME/multica" home
```

### 端口与健康检查

- backend 容器端口 `8080`，frontend 容器端口 `3000`。
- gateway 默认 `127.0.0.1:8787`。
- PostgreSQL 只在 Compose 网络使用 `postgres:5432`，默认不发布宿主端口。
- 冲突时修改 checkout `.env`，启动后以 `docker compose port` 和 `state.json` 为准。

检查 Compose、PostgreSQL health、backend `/readyz` 与 gateway `/api/config`。修改 `.env`
后运行 `docker compose ... up -d` 重新创建容器；不要只用 `restart`。

## 阶段 2：建立 owner、共享 workspace 与注册许可

首次登录前在 server checkout 的 `.env` 设置明确的注册许可：

```dotenv
ALLOW_SIGNUP=false
ALLOWED_EMAILS=owner@example.com,friend1@example.com
DISABLE_WORKSPACE_CREATION=false
```

`ALLOWED_EMAILS` 是 server 层账号注册许可；workspace invitation 是第二层许可。邀请不会
绕过 signup allowlist。应用配置后，优先让初始 owner 在 Web 中完成邮箱或 Google 身份
认证并创建共享 workspace。若 owner 的 CLI profile 已经认证，也可用 CLI 创建；随后选择
该 workspace：

```sh
multica workspace list --profile home --output json
multica workspace create --profile home \
  --name "Friends Compute" --slug friends-compute --issue-prefix FRC --output json
multica workspace switch friends-compute --profile home
```

未认证的 CLI 不得直接执行上述命令；先在 Web 创建，再由阶段 3 的 client 登录流程执行
`workspace switch`。若 workspace 已存在，只执行 `list/get/switch`。创建后把
`DISABLE_WORKSPACE_CREATION=true`，再次 `docker compose ... up -d`，让新成员只能加入这个
共享 workspace。保留精确邮箱 allowlist；不要开放匿名注册或共享 owner 账号。

## 阶段 3：把服务器宿主机注册为第一个 runtime

先在宿主机安装并登录至少一个 provider CLI，再显式组合
`multica-runtime-client`。Windows + WSL 使用 Windows 原生脚本：

```powershell
$RuntimeSkill = "$HOME\.codex\skills\multica-runtime-client"
$Connection = Get-Content "$HOME\.multica\selfhost-server\home\connection.json" -Raw |
  ConvertFrom-Json
& (Join-Path $RuntimeSkill "scripts\connect-windows-runtime-client.ps1") `
  -ServerUrl $Connection.server_url `
  -AppUrl $Connection.app_url `
  -Workspace friends-compute `
  -Profile home `
  -DeviceName $env:COMPUTERNAME `
  -RuntimeName "$env:COMPUTERNAME Codex"
```

macOS 使用同一台机器上的 client Skill：

```sh
RUNTIME_SKILL="$HOME/.codex/skills/multica-runtime-client"
/bin/sh "$RUNTIME_SKILL/scripts/connect-runtime-client.sh" \
  --server-url "http://127.0.0.1:8787" \
  --workspace friends-compute \
  --profile home \
  --runtime-name "$(hostname) Codex"
```

按 `daemon status` 返回的 daemon/workspace/runtime IDs 识别本机 runtime，不取全局列表的
第一项。为选定 provider runtime 创建 workspace 可调用 agent：

```sh
multica agent create --profile home \
  --name "Server Codex" \
  --description "Trusted team agent on the server host" \
  --runtime-id <local-runtime-id> \
  --permission-mode public_to \
  --public-to-workspace \
  --max-concurrent-tasks 1 \
  --output json
```

再创建一个只读或临时目录内的无破坏性 issue，分派给该 agent，并用 `issue runs` 与
`run-messages` 确认实际任务完成。provider 未登录、任务只排队或 runtime 不属于目标
workspace 时，不得报告完成。

## 阶段 4：许可朋友机器加入

对每位朋友按顺序执行：

1. 把其准确邮箱加入 server 的 `ALLOWED_EMAILS`，应用 `.env` 变更。
2. 由 owner/admin 发送目标 workspace 邀请：

   ```sh
   multica workspace member invite friend@example.com friends-compute \
     --role member --profile home --output json
   ```

3. 让朋友通过专属邀请完成注册、登录与接受；不要传递 owner 的 token。
4. 只交付私网 Server URL、workspace slug 和邀请渠道，让对方使用
   `multica-runtime-client`。
5. 对方 runtime 上线后创建 `public_to + workspace` agent，并运行跨机器 smoke task。

只有 owner/admin 需要邀请权限；普通 member 已能使用明确开放给整个 workspace 的 agents。
撤销成员时同时移除 workspace membership、其 allowlist 邮箱和不再使用的 runtime/agent，
必要时轮换受影响的外部凭据。

## 私网发布

推荐 Tailscale + Caddy。让 Tailscale Serve 把本机 gateway 发布为 tailnet 内 HTTPS；不要
使用 Funnel，也不要直接暴露 3000、8080、8787 或 5432。Windows + WSL：

```powershell
& (Join-Path $ServerSkill "scripts\publish-windows-tailscale.ps1") `
  -WslDistro Ubuntu-26.04 `
  -LinuxRepo /home/<wsl-user>/multica `
  -Profile home
```

取得 HTTPS URL 后重新生成 `connection.json`，并从每台目标客户端验证 `/readyz`、
`/api/config` 与 `/ws`。不要把 `127.0.0.1` 或 WSL 私有地址发给朋友设备。

## 持久化与恢复

只有用户确认后才分别安装两个恢复项：

- server：`install-windows-wsl-server-autostart.ps1` 或
  `install-macos-server-autostart.sh`；
- 首 runtime：`multica-runtime-client` 的 Windows 登录任务或 macOS LaunchAgent。

恢复验证必须同时看到 server 健康和首 runtime `online`。server 可用但 runtime offline，
只表示控制面恢复；runtime 在线但 provider 未登录，也不能执行任务。

## 登录与排障

- 没有 SMTP/Resend 时，从 backend 日志读取一次性验证码；固定开发验证码只允许完全本地、
  非生产测试，不能用于朋友集群。
- 登录被拒绝时依次检查 `ALLOWED_EMAILS`、`ALLOW_SIGNUP`、邀请是否接受和 workspace
  membership。daemon 注册返回 403 时，不要靠重试绕过许可。
- 检查 `auth status`、`workspace get`、`daemon status`、`runtime list`、provider CLI 登录、
  agent permission mode 与实际 smoke task。
- CORS/cookie/WebSocket 错误属于 server；runtime offline、provider 登录或 agent 绑定错误
  转到 `multica-runtime-client`。
- 任何命令参数都先以本机 `--help` 为准，并在涉及版本差异时核对官方 self-host 与 CLI
  文档。
