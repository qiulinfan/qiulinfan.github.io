# Runtime verification

Treat Multica as the only authority for runtime discovery and health. Never invoke a provider CLI.
Provider inspection, selection, sign-in, and verification are outside this workflow.

## Required correlations

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

Only a runtime satisfying every equality is a local online runtime in the target workspace. One
daemon may serve multiple workspaces, and one workspace may contain several devices, so never rely
on list order, names, or provider strings.

A successful verifier result must contain at least `workspace_id`, `daemon_id`, `runtime_ids`, and
`runtime_count`. On failure, exit nonzero and do not print a misleading online-success message.
