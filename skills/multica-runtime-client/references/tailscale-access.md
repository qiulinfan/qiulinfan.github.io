# Tailscale access

## 模式

- `same-tailnet`：成员使用自己的 Tailscale 账号加入服务器所在 tailnet；不要共享账号。
- `shared-machine`：owner 只把 Multica server 机器共享给该成员；客户端使用服务器完整
  `hostname.tailnet.ts.net` 名称。

两种模式都只解决网络访问。Multica `ALLOWED_EMAILS`、账号注册和 workspace membership 是
独立许可，不能互相替代。

## Agent 检查顺序

1. 确认 Tailscale 已安装且 `BackendState=Running`。
2. 确认 handoff 中的 Server URL 是无凭据 `.ts.net` HTTPS origin。
3. 请求 `<server>/api/config`；DNS、ACL、邀请或机器共享未就绪时停止在此阶段。
4. 写入 `TAILSCALE_ACCESS_STATUS=reachable` 后才能启动 Multica 身份流程。

不得扫描 LAN、猜测 tailnet、使用另一机器的 loopback、自动创建公开入口或改用 Funnel。

## 人工断点

返回结构化结果：

```json
{"status":"manual_action_required","phase":"tailscale-access-required","action":"accept_tailnet_invite","background_work":false,"resume_hint":"继续连接客户端"}
```

共享邀请链接具有访问能力，不写入 cache、handoff receipt、日志或对话。
