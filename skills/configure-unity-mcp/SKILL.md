---
name: configure-unity-mcp
description: Install, configure, repair, migrate, and fully validate Codex-to-Unity Editor MCP integration on macOS, Windows, or Linux. Use when setting up Unity MCP on a new project or machine; enabling Codex to read Hierarchy and Inspector state, edit scenes and components, control Play Mode, inspect Console logs, or capture Game View; diagnosing missing Unity tools, failed MCP handshakes, package compilation errors, stale Bee/Library caches, port conflicts, multi-instance routing, or Codex configuration scope; or proving that an existing Unity MCP connection works end to end.
---

# Configure Unity MCP

Establish a reproducible Unity Editor control path:

`Codex → streamable HTTP MCP → MCP for Unity server → Unity Editor plugin`

Do not declare success after installing a package or opening a port. Complete the acceptance gates in [references/acceptance.md](references/acceptance.md).

## Select the path

1. If native Unity MCP tools are already callable, inspect the current connection before changing files.
2. If the project contains the Unity plugin but Codex lacks tools, repair configuration or restart boundaries.
3. If neither side is configured, perform a clean installation.
4. If Unity does not compile, fix package compatibility before testing MCP.
5. If moving to a different OS, read [references/platforms.md](references/platforms.md) before installing dependencies.
6. For any failure, read [references/troubleshooting.md](references/troubleshooting.md) and match the exact symptom.

## Preserve the project

- Inspect `git status`, `ProjectSettings/ProjectVersion.txt`, `Packages/manifest.json`, `Packages/packages-lock.json`, and any repository instructions first.
- Preserve unrelated user changes.
- Never delete `Assets/`, `Packages/`, or `ProjectSettings/`.
- Treat `Library/`, `Temp/`, `Logs/`, `obj/`, and `UserSettings/` as generated state.
- Before resetting generated state, close Unity and move the target to a dated backup instead of deleting it.
- Do not commit or push unless the user requests publication.
- Prefer Unity MCP operations over direct `.unity`, `.prefab`, `.asset`, or `.meta` YAML editing.
- Do not mutate a dirty scene during connection testing. Save with authorization, or use read-only tests.

## Phase 1: Inspect versions and state

Run the bundled doctor from the Unity project root:

```text
uv run <skill-dir>/scripts/unity_mcp_doctor.py --project .
```

If `uv` is unavailable, run it with Python 3.11+:

```text
python <skill-dir>/scripts/unity_mcp_doctor.py --project .
```

Record:

- host OS and architecture;
- Unity Editor version from `ProjectVersion.txt`;
- current Unity package versions;
- MCP package presence and pinned source;
- project-level and user-level Codex MCP configuration;
- whether the configured host and port are listening;
- Unity MCP launch-log evidence;
- current C# compiler errors.

Before choosing versions, verify current official sources because Unity, Codex, Python tooling, and the MCP package change over time:

- [Codex MCP configuration](https://developers.openai.com/codex/mcp/)
- [MCP for Unity repository](https://github.com/CoplayDev/unity-mcp)
- [MCP for Unity installation](https://coplaydev.github.io/unity-mcp/getting-started/install)
- [MCP for Unity tools](https://coplaydev.github.io/unity-mcp/reference/tools/)
- [uv installation](https://docs.astral.sh/uv/getting-started/installation/)
- Unity Manual and Unity Package Registry pages for the exact Editor stream.

Prefer an official release tag over an unpinned branch. Never copy the versions in a historical incident report without confirming compatibility with the target Editor.

## Phase 2: Prepare host dependencies

Install `uv`/`uvx` using the official OS-specific route in [references/platforms.md](references/platforms.md). Verify:

```text
uv --version
uvx --version
codex --version
```

Ensure the Unity Editor can open the project normally before adding MCP. If the project already fails to compile, separate those baseline failures from MCP failures.

## Phase 3: Install the Unity package

Add the official MCP for Unity package to `Packages/manifest.json`, pinned to the selected release:

```json
"com.coplaydev.unity-mcp": "https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#<verified-release-tag>"
```

Maintain valid JSON and preserve all existing dependencies. Open Unity and allow Package Manager resolution, import, compilation, and domain reload to finish.

After Unity resolves packages:

- confirm `Packages/packages-lock.json` contains `com.coplaydev.unity-mcp`;
- confirm the plugin menu/window is available;
- read the latest Unity compiler output;
- stop immediately if compiler errors remain.

When a newer Unity Editor exposes obsolete APIs in old project packages, update only the incompatible packages to versions officially compatible with that Unity stream. Treat this as a project migration and review the resulting serialized asset/settings changes.

## Phase 4: Configure Codex at project scope

Create or update `<project>/.codex/config.toml`:

```toml
[mcp_servers.unityMCP]
url = "http://127.0.0.1:8080/mcp"
enabled = true
required = false
startup_timeout_sec = 30
tool_timeout_sec = 120
```

Use the URL exposed by the Unity plugin if it differs. Include the `/mcp` path. Prefer `127.0.0.1` for a server bound explicitly to IPv4 loopback.

Verify from the project root:

```text
codex mcp list
```

Keep this server project-scoped unless the user explicitly wants Unity MCP in every project. The plugin's “Configure All Detected Clients” action may write a user-global entry; inspect the global Codex config afterward and remove an unintended duplicate only after the project config is confirmed.

Codex clients load MCP definitions at startup. After changing configuration, fully restart Codex Desktop/CLI and reopen the project. An already-running task may not hot-load the new tools.

## Phase 5: Start and persist the Unity bridge

In Unity:

1. Open `Window → MCP for Unity → Toggle MCP Window`.
2. Select local HTTP transport and verify the URL/port.
3. Start the server.
4. Accept the first-launch background-server confirmation.
5. Wait for both server listening and Unity plugin registration.
6. In `Advanced`, enable `Auto-Start Server on Editor Load`.

Restart Unity once and verify that the server and Unity session reconnect without manual clicking. Do not rely only on the preference value.

Expected launch-log evidence includes:

- HTTP server listening at the configured `/mcp` endpoint;
- WebSocket bridge accepted;
- `Plugin registered: <project>`;
- Unity-side tools registered.

## Phase 6: Inspect MCP resources before mutation

When Unity MCP tools are native in the task:

1. List MCP resources and use the exact returned URIs.
2. Read `mcpforunity://custom-tools` first.
3. Read `mcpforunity://instances`.
4. If multiple Unity sessions exist, call `set_active_instance` with the exact `Name@hash` before other tools.
5. Read `mcpforunity://editor/state`, `mcpforunity://project/info`, and the active scene.
6. Wait while Unity is compiling, updating assets, reloading domains, or changing Play Mode.

Never invent resource URIs from their display names. Resource payloads place content under `data`.

## Phase 7: Validate end to end

Run the read-only smoke test first:

```text
uv run <skill-dir>/scripts/unity_mcp_smoke_test.py
```

Then run the full test only when the active scene is clean:

```text
uv run <skill-dir>/scripts/unity_mcp_smoke_test.py --full
```

The full test must:

- enumerate tools and resources;
- read the active scene and paged Hierarchy;
- read the Main Camera component through an Inspector resource;
- require a clean, saved active scene before mutation;
- change and verify Camera FOV in Edit Mode;
- restore the original value and reopen the same scene from disk without saving test changes;
- enter Play Mode;
- capture Game View to a generated/ignored folder;
- stop Play Mode in a `finally` path;
- verify the original FOV remains after Stop;
- verify the scene is still clean;
- report Console errors without conflating unrelated service or render noise with compiler errors.

If the bundled script cannot model a project-specific setup, reproduce the same gates with native Unity MCP tools. Follow paging instructions for large hierarchies and component lists.

## Phase 8: Review generated changes

After a successful connection:

- run `git status --short`, `git diff --stat`, and `git diff --check`;
- inspect package manifest and lock changes;
- inspect Unity serialization migrations in scenes, render-pipeline assets, and `ProjectSettings`;
- confirm temporary screenshots live under an ignored directory such as `Temp/MCPValidation`;
- confirm no scene remains dirty and Play Mode is stopped;
- distinguish intentional helper-script self-cleanup from accidental deletion;
- disclose unrelated Console errors.

Do not discard Unity migration changes blindly. Confirm whether they are required by the Editor/package upgrade.

## Completion report

Report:

- Unity Editor version, MCP release, endpoint, and configuration scope;
- whether auto-start survived a Unity restart;
- tool/resource counts observed during the handshake;
- exact Hierarchy, Inspector, Play/Stop, and Game View checks performed;
- compiler status and unrelated Console noise;
- files changed and whether anything was committed or pushed;
- any single remaining user action, especially a required Codex restart.
