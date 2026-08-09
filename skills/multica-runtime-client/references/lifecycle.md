# Client lifecycle

## Upgrade

升级前记录 Multica CLI 版本、daemon ID、runtime IDs、agents 和自启动项。只使用明确 release；
升级后重启 daemon，运行 verifier 和 zero-tool smoke。失败时保留旧证据并停止，不重复创建 agents。

## Revoke

默认只输出计划。用户确认 apply 后按顺序：

1. 禁用并停止本机自启动；
2. 停止 daemon；
3. 禁用或删除绑定本机 runtimes 的 agents；
4. 由 owner/admin 删除 runtimes 和 workspace membership；
5. 从 server allowlist 移除准确邮箱；
6. 撤销 Tailscale tailnet membership 或 machine share；
7. 清理本机无凭据 profile cache。

远程对象、账号和访问撤销必须逐项回执；机器 offline 不等于访问已撤销。
