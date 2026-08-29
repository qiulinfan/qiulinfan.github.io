# Runtime verification

Multica is the only runtime authority. Never invoke provider CLIs.

Require every equality:

```text
workspace get.id
  = daemon status.workspaces[].id
  = runtime list[].workspace_id

daemon status.daemon_id
  = runtime list[].daemon_id

daemon status.workspaces[].runtimes[] contains runtime list[].id
runtime list[].status = online
```

Do not rely on list order, names, or provider strings. Success returns at least `workspace_id`,
`daemon_id`, `runtime_ids`, and `runtime_count`. Failure exits nonzero without an online-success
message.
