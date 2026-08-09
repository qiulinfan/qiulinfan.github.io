# Runtime verification

把 Multica 视为 provider 发现与健康状态的唯一权威。不要调用任何 provider CLI。

## 必须关联的字段

```text
workspace get.id
    = daemon status.workspaces[].id
    = runtime list[].workspace_id

daemon status.daemon_id
    = runtime list[].daemon_id

daemon status.workspaces[].runtimes[]
    contains runtime list[].id

runtime list[].status
    = online
```

只有同时满足全部等式的 runtime 才是目标 workspace 中的本机 online runtime。一个 daemon 可以
拥有多个 workspace，一个 workspace 可以有多台设备，因此禁止依赖列表顺序、名称或 provider
字符串。

verifier 成功输出至少包含 `workspace_id`、`daemon_id`、`runtime_ids` 和 `runtime_count`；失败
必须非零退出，不得输出“online”成功文案。
