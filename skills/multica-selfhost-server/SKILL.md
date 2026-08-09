---
name: multica-selfhost-server
description: 根据自然语言自动识别 Windows + WSL、macOS 或原生 Linux，以可恢复状态机部署、启动、升级、备份、发布、检查与撤销唯一 Multica self-host 控制面；管理 PostgreSQL、backend、frontend、loopback-only gateway、Tailscale Serve、精确邮箱准入、共享 workspace、无凭据 client handoff、server 自启动，并组合 multica-runtime-client 完成宿主机首 runtimes、workspace agents 与有界 smoke。适用于可信朋友团队建立唯一私网 Server，或排查准入、CORS、WebSocket、升级和恢复问题；后续设备只使用 multica-runtime-client。Multica 自动发现全部 providers，本 Skill 不询问、登录或直接验证任何 provider CLI。
---

# Multica self-host server

建立可信朋友团队唯一控制面，并委派 `multica-runtime-client` 管理所有执行节点。让用户只处理
Tailscale、Multica 身份和系统授权等不可代办交互；不要部署第二套 server。

## 不可违反的规则

- 每次先读 cache 与真实只读状态，只执行当前 phase；不要重做已完成对象。
- 在 Docker 安装、clone、pull 或 Compose 启动前必须通过 Tailscale readiness gate；所有
  Windows server 路径都遵守同一 gate，未通过时 fail closed。
- 打开 Tailscale 或 owner WebUI 后立即结束本轮，不轮询、不后台等待。
- 不询问 provider，不运行 provider CLI，不触发 provider OAuth。Multica daemon 自动发现全部
  providers，首节点完成证据只来自 Multica runtime 状态与 smoke。
- 不共享 PAT、验证码、cookie、JWT、数据库密码、Tailscale share link、SSH key 或系统账号。
- 不用 Funnel，不开放公网入口；backend/frontend/gateway 只能绑定 loopback，PostgreSQL 不得
  host-publish。检测到 `0.0.0.0`、`::` 或数据库 host binding 时停止。
- 自启动、升级、恢复、远程撤销和数据删除必须有明确授权；删除数据卷需要单独确认。

## cache 与阶段

使用 `profile-cache.ps1|sh` 管理 `.cache/<profile>/profile.env`。只保存 owner/成员邮箱、
workspace、topology、server checkout、私网 URL、设备/runtime 名、邀请状态和明确授权。
旧 `PROVIDER` 字段读取时忽略并在下一次写入清理。

| `ONBOARDING_PHASE` | 下一步 |
|---|---|
| `tailscale-action-required` | 只重查 Tailscale，未就绪就停止 |
| `tailscale-ready` | 安装/启动唯一 server |
| `server-ready` | 打开 owner WebUI |
| `owner-registration-required` | 验证 owner/workspace |
| `cluster-finalizing` | 邀请、首 runtimes、agents、smoke、自启动 |
| `complete` | 健康检查或明确变更 |

所有人工断点返回 `manual_action_required`、phase、唯一 action、`background_work=false` 和
`resume_hint`；不要从日志自由文本猜阶段。

## 部署状态机

### 1. Tailscale readiness

安装或复用 Tailscale，然后运行 `check-windows-tailscale-readiness.ps1` 或
`check-unix-tailscale-readiness.sh`。要求本机 Connected、MagicDNS、HTTPS Certificates 和
受控 `.ts.net` 名称已就绪；否则只提示用户完成这一个阶段并再次调用。

### 2. 启动唯一 server

readiness 成功后才安装 Docker、取得经过确认的 Multica checkout、生成 `.env` 并应用 admission
cache。Windows 使用 WSL2 Ubuntu Docker，runtime 留在 Windows 宿主；macOS/Linux 使用本机
Docker。平台入口和 loopback 验证见 [references/platforms.md](references/platforms.md)。

启动 PostgreSQL、backend、frontend 和 Caddy gateway，配置同源 Tailscale Serve；验证数据库、
backend ready、gateway `/api/config` 与私网 `/api/config`。成功后更新：

```text
~/.multica/selfhost-server/<profile>/state.json
~/.multica/selfhost-server/<profile>/connection.json
```

### 3. owner 与 workspace

若 owner/workspace 尚不存在，从 `connection.json` 打开外部 WebUI，写入
`owner-registration-required` 并停止。用户用精确 owner 邮箱注册/登录并创建唯一 workspace；
再次调用后验证身份和 workspace，写入 `DISABLE_WORKSPACE_CREATION=true` 并 recreate。

`ALLOWED_EMAILS` 是 server 注册许可，workspace invitation 是第二层许可。预期成员尚未注册时
保持 `ALLOW_SIGNUP=true`；全部注册并接受后，或 owner 明确要求时，才关闭 signup。

### 4. 成员 handoff

对每位成员选择：

- `same-tailnet`：使用各自 Tailscale 账号加入同一 tailnet；
- `shared-machine`：只共享 Multica server 机器。

发出 Tailscale access 与 workspace invitation 后，运行 `write-client-handoff.ps1|sh` 生成无凭据
receipt，包含 Server URL、workspace、成员邮箱和两层邀请状态。不要把 share/invite secret 写入
receipt。客户端以该 receipt 调用 `multica-runtime-client`。

### 5. 宿主机首 runtimes

组合 `multica-runtime-client`，让宿主机使用自己的 Multica 身份。Windows + WSL 注册 Windows
原生 runtime；macOS/Linux 注册同平台 runtime。Multica 自动发现全部 providers；不要选择、
登录或验证 provider CLI。

对 Multica verifier 返回的每个本机 online runtime 复用或创建 workspace agent，并运行 90 秒
zero-tool smoke。另一成员加入后再触发一次跨成员 smoke。

### 6. 自启动与完成

只安装用户已授权的 server/runtime 恢复项。完成必须同时证明：

1. server 四层健康，内部端口没有非 loopback/database host binding；
2. 私网 URL 可达，owner/workspace 有效；
3. 宿主机 daemon 与目标 workspace 下至少一个 Multica-detected runtime online；
4. 要共享的每个本机 runtime 有 workspace agent，zero-tool smoke 完成；
5. 所有获授权恢复项通过重启验证；
6. handoff receipts 不含凭据。

provider 登录、类型和版本不属于输入、人工断点或完成条件。

## 升级、备份、恢复与撤销

description 中的升级和备份必须按 [references/lifecycle.md](references/lifecycle.md) 执行：升级前
固定版本并备份，升级后验证 migration、健康与 smoke，失败时停止并回滚；备份必须包含一致性
PostgreSQL dump、加密 `.env` 和恢复演练。撤销默认先 plan，远程删除和数据卷删除分别确认。

## 排障顺序

固定为：当前 phase → Tailscale → port bindings → Docker/Compose → database → backend → gateway
→ private URL → owner/workspace → 委派 runtime-client。每次只处理第一个失败点。

无 SMTP 时不要让验证码出现在命令输出、cache 或对话；若当前工具无法直接把日志值安全填入
可见 UI，就停止并要求配置可用邮件通道，不读取验证码。
