---
name: multica-runtime-client
description: 根据自然语言自动识别 Windows、macOS、原生 Linux 或 WSL，把当前机器通过 Tailscale 私网加入一个已许可成员与 workspace 的 Multica Server；管理无凭据 profile cache、独立 Multica 认证、daemon、Multica 自动发现的全部本机 runtimes、workspace agents、smoke task 与获授权的登录自启动。适用于服务器宿主机首 runtime、朋友设备第 2/3/N 个 runtime、打开 Web UI、操作 workspace 对象，或排查 Tailscale access、signup、invite、403、runtime offline 和跨设备目录问题。绝不要求、安装、选择、登录或直接验证 provider CLI；以 Multica 返回的 runtime 状态为唯一执行面证据。此 Skill 不部署第二套 Server，控制面与准入策略使用 multica-selfhost-server。
---

# Multica runtime client

只管理当前设备的 Tailscale 网络准入、Multica 身份与执行节点。服务器宿主机首 runtime 和后续
设备使用同一流程；不要部署 Docker、PostgreSQL、backend、frontend 或 Caddy。

## 不可违反的边界

- 把自然语言作为唯一输入界面。Agent 自己探测、执行和验证，不把命令交给用户。
- Windows 和 WSL 都注册 Windows 原生 runtime；POSIX 脚本在 WSL fail closed。
- 每个人使用自己的 Tailscale 与 Multica 身份；不要接受 owner 的 PAT、验证码或 cookie。
- 不询问 provider，不检查 provider CLI，不触发 provider OAuth。Multica 自动发现本机所有
  providers；只使用 daemon 与 runtime API 返回的本机 runtime IDs 和 `online` 状态。
- 持久 daemon、Scheduled Task、LaunchAgent 或 systemd 用户服务只在用户明确授权后配置。
- cache 只保存非凭据字段；真实 Tailscale、auth、workspace、daemon 和 runtime 状态优先。

## 输入与 cache

每次先运行 `scripts/profile-cache.ps1 show` 或 `scripts/profile-cache.sh show`，再以本轮明确值
覆盖。需要：

- Tailscale HTTPS `ServerUrl`、目标 workspace 与自己的 `IdentityEmail`；
- `TAILSCALE_ACCESS_MODE=same-tailnet|shared-machine`；
- 自动探测的设备/runtime 名，并发默认 `1`；
- 是否开放全部本机 online runtimes 给 workspace，以及是否登录自启动。

旧 cache 中的 `PROVIDER` 是弃用字段：读取时忽略，下一次写入时删除。绝不新增 provider 字段。

## 加入状态机

### 1. Tailscale 网络准入

在任何 Multica 登录或 daemon 启动前运行：

- Windows：`check-windows-tailscale-access.ps1`；
- macOS/原生 Linux：`check-unix-tailscale-access.sh`。

要求 Tailscale 已连接、Server URL 为 `.ts.net` HTTPS、`/api/config` 可达。若未就绪，返回统一
`manual_action_required` JSON，只让用户接受 tailnet 邀请或服务器机器共享，然后再次调用；
不要把网络拒绝误诊为 Multica 403。

完整准入与共享边界见 [references/tailscale-access.md](references/tailscale-access.md)。

### 2. 独立 Multica 身份与 membership

运行平台对应 connect 脚本。需要人工浏览器/邮箱认证时启动可见流程并暂停；认证后必须比较
`auth status` 中的邮箱与 `IdentityEmail`，再执行 `workspace switch <target>`。signup 被拒绝、
邀请未接受、邮箱不匹配或 `workspace get` 返回 403 时立即停止；客户端不得修改远程 allowlist
或伪造 membership。

### 3. daemon 与 runtimes

启动 daemon 后运行 `verify-runtime-client.ps1` 或 `verify-runtime-client.sh`。verifier 必须：

1. 把 workspace ref 解析为规范 workspace ID；
2. 取得本机 daemon ID 与该 workspace 下的本机 runtime IDs；
3. 与 `runtime list` 的 `daemon_id`、`workspace_id`、runtime ID 和 `status=online` 求交；
4. 至少得到一个由 Multica 自动发现的本机 online runtime。

不得取全局列表第一项，不得用其他 workspace/设备的 runtime 代替。详细证据契约见
[references/verification.md](references/verification.md)。

### 4. workspace agents 与 smoke

用户已授权“开放给 workspace”时，对 verifier 返回的每个本机 online runtime：

- 复用或创建一个绑定该 runtime 的 agent；
- 使用 `permission_mode=public_to` 和 workspace target，不能保留默认 private；
- 生成随机 nonce，运行 zero-tool issue，只允许返回 `MULTICA_SMOKE_OK:<nonce>`；
- 最多等待 90 秒，要求 task `completed` 且消息精确匹配；不创建重复 issue。

正式共享前再由另一位 workspace 成员触发一次 smoke，证明跨成员 invocation access。

### 5. 自启动与回执

只在明确授权后运行对应 installer。自启动只恢复已完成的 Tailscale 与 Multica 认证，不接受
邀请、不注册账号。完成后交付结构化证据：server/workspace、identity email、daemon ID、
runtime IDs、agent IDs、smoke task ID、Tailscale access mode 和恢复方式；永不交付 token。

## 完成条件

只有以下全部成立才报告设备已加入：

1. Tailscale access 为 `reachable`；
2. `auth status` 邮箱与请求身份一致，server 正确；
3. `workspace get <target>` 成功且默认 workspace 已切换；
4. verifier 返回正确 daemon/workspace 下至少一个本机 online runtime；
5. 每个要共享的本机 runtime 都有显式 workspace agent；
6. zero-tool smoke 完成；若要求正式跨成员共享，另一成员 smoke 也完成；
7. 获授权的自启动项已验证。

provider CLI 登录、类型和版本不属于输入、暂停点或完成条件。

## 平台入口

- Windows/WSL：`connect-windows-runtime-client.ps1`、`start-windows-runtime-client.ps1`、
  `install-windows-autostart.ps1`。
- macOS：`connect-runtime-client.sh`、`start-runtime-client.sh`、
  `install-macos-autostart.sh`。
- 原生 Linux：同一 connect/start 脚本与 `install-linux-autostart.sh`。

实际 CLI 参数先查本机 `--help`。脚本输出统一使用 `ready`、`manual_action_required` 或失败退出；
不要从自由文本猜阶段。

## 撤销、升级与排障

撤销默认先生成 plan，再依次停止自启动与 daemon、禁用 agents、移除 runtimes/membership、撤销
Tailscale access，最后清理非凭据 cache。升级前记录 CLI 版本并在升级后重跑 verifier 与 smoke。
完整流程见 [references/lifecycle.md](references/lifecycle.md)。

排障顺序固定为：Tailscale reachability → Multica identity → workspace membership → daemon →
verifier → agent access → smoke。每次只处理第一个失败点。
