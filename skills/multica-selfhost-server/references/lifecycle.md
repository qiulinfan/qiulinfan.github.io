# Server lifecycle

## Backup

备份前记录 Multica commit/release、Compose image digests、schema/version 与 profile。暂停写入或使用
一致性机制生成 PostgreSQL dump；把 `.env` 单独加密到仓库外目标，不在日志显示内容。记录 hash、
时间、版本和保留策略。未完成一次隔离 restore drill 的备份不能标为 verified。

## Upgrade

默认只升级到明确 release/commit 和固定 image digest，不跟随未审查的 `main` 或浮动 tag。顺序：

1. 健康检查和 verified backup；
2. 记录旧 revision/digests；
3. pull 明确版本并审查 migration；
4. recreate stack；
5. 验证 database、backend、gateway、private URL；
6. 运行 runtime verifier 与 smoke；
7. 任一失败就停止，按旧 revision/digests 恢复并重新验证。

## Revoke and uninstall

默认输出 plan。确认 apply 后先撤销 client agents/runtimes/membership/allowlist/Tailscale access，再
停止 runtime 与 server 自启动。保留 verified backup 后才能删除 containers；删除 PostgreSQL
volume 需要独立的逐字确认。输出每个远程和本地对象的撤销回执。
