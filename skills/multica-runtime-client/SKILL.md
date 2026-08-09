---
name: multica-runtime-client
description: Detect Windows, macOS, native Linux, or WSL from natural-language requests and join the current device to a licensed Multica member and workspace over private Tailscale access. Manage a credential-free profile cache, independent Multica authentication, the daemon, every local runtime automatically detected by Multica, workspace agents, bounded smoke tasks, and explicitly authorized login autostart. Use for the server host's first runtimes, a friend's second or later device, opening the Web UI, operating workspace objects, or troubleshooting Tailscale access, signup, invitations, 403 responses, offline runtimes, and cross-device paths. Never request, install, select, sign in to, or directly verify a provider CLI; provider handling is not a workflow step, and Multica runtime state is the only execution-plane evidence. Do not deploy another Server; use multica-selfhost-server for the control plane and admission policy.
---

# Multica runtime client

Manage only this device's Tailscale network admission, Multica identity, and execution nodes. Use
the same flow for the server host's first runtime and every later device. Do not deploy Docker,
PostgreSQL, a backend, a frontend, or Caddy.

## Non-negotiable boundaries

- Treat natural language as the only user input surface. Detect, execute, and verify directly; do
  not hand commands back to the user.
- Match user-facing explanations, prompts, and handoffs to the user's language unless the user
  requests another language. Keep commands, identifiers, JSON keys, action codes, and raw errors
  unchanged.
- Register Windows-native runtimes for both Windows and WSL. Make POSIX scripts fail closed in WSL.
- Require each person to use their own Tailscale and Multica identities. Never accept an owner's
  PAT, verification code, or cookie.
- Do not ask about providers, inspect provider CLIs, or trigger provider OAuth. Assume providers are
  available; Multica automatically detects all local providers. Use only the local runtime IDs and
  `online` states returned by the Multica daemon and runtime APIs.
- Configure a persistent daemon, Scheduled Task, LaunchAgent, or systemd user service only after
  explicit user authorization.
- Store only non-credential fields in the cache. Prefer live Tailscale, authentication, workspace,
  daemon, and runtime state over cached values.

## Inputs and cache

Start every run with `scripts/profile-cache.ps1 show` or `scripts/profile-cache.sh show`, then
override cached values with explicit values from the current request. Require:

- the Tailscale HTTPS `ServerUrl`, target workspace, and the user's own `IdentityEmail`;
- `TAILSCALE_ACCESS_MODE=same-tailnet|shared-machine`;
- an automatically detected device/runtime name, with concurrency defaulting to `1`;
- whether to expose every local online runtime to the workspace and whether to enable login
  autostart.

Treat `PROVIDER` in an old cache as deprecated: ignore it while reading and remove it on the next
write. Never add a provider field.

## Join state machine

### 1. Admit Tailscale access

Before any Multica sign-in or daemon start, run:

- Windows: `check-windows-tailscale-access.ps1`;
- macOS or native Linux: `check-unix-tailscale-access.sh`.

Require a connected Tailscale client, a `.ts.net` HTTPS Server URL, and a reachable `/api/config`.
If access is not ready, return uniform `manual_action_required` JSON and ask the user only to accept
the tailnet invitation or server machine share before invoking the Skill again. Do not misdiagnose a
network denial as a Multica 403.

Read [references/tailscale-access.md](references/tailscale-access.md) for the complete admission and
sharing boundary.

### 2. Establish an independent Multica identity and membership

Run the platform-specific connect script. If browser or email authentication requires manual
interaction, open the visible flow and stop. After authentication, compare the email from
`auth status` with `IdentityEmail`, then run `workspace switch <target>`. Stop immediately if signup
is denied, an invitation is unaccepted, the email differs, or `workspace get` returns 403. A client
must not change the remote allowlist or fabricate membership.

### 3. Verify the daemon and runtimes

After starting the daemon, run `verify-runtime-client.ps1` or `verify-runtime-client.sh`. The verifier
must:

1. resolve the workspace reference to its canonical workspace ID;
2. obtain the local daemon ID and its local runtime IDs for that workspace;
3. intersect them with `runtime list` entries having the same `daemon_id`, `workspace_id`, runtime ID,
   and `status=online`;
4. return at least one local online runtime automatically detected by Multica.

Never take the first item from a global list or substitute a runtime from another workspace or
device. Read [references/verification.md](references/verification.md) for the evidence contract.

### 4. Create workspace agents and run smoke tasks

When the user has authorized workspace exposure, handle every local online runtime returned by the
verifier:

- reuse or create an agent bound to that runtime;
- set `permission_mode=public_to` with the workspace as target; never retain the private default;
- generate a random nonce and run a zero-tool issue that may return only
  `MULTICA_SMOKE_OK:<nonce>`;
- wait at most 90 seconds, require a `completed` task and an exact message match, and do not create a
  duplicate issue.

Before declaring cross-member sharing ready, have another workspace member trigger one smoke task
to prove cross-member invocation access.

### 5. Configure autostart and deliver evidence

Run the corresponding installer only after explicit authorization. Autostart may restore completed
Tailscale and Multica authentication, but must not accept invitations or register accounts. Deliver
structured evidence containing the server/workspace, identity email, daemon ID, runtime IDs, agent
IDs, smoke task ID, Tailscale access mode, and recovery mechanism. Never deliver a token.

## Completion conditions

Report that the device joined only when all applicable conditions hold:

1. Tailscale access is `reachable`.
2. The `auth status` email matches the requested identity and the server is correct.
3. `workspace get <target>` succeeds and the default workspace has switched.
4. The verifier returns at least one local online runtime under the correct daemon and workspace.
5. Every local runtime intended for sharing has an explicit workspace agent.
6. The zero-tool smoke completes; when formal cross-member sharing is required, the other-member
   smoke also completes.
7. Every authorized autostart item is verified.

Provider login, type, availability, and version are not inputs, pause points, or completion
conditions.

## Platform entry points

- Windows/WSL: `connect-windows-runtime-client.ps1`, `start-windows-runtime-client.ps1`, and
  `install-windows-autostart.ps1`.
- macOS: `connect-runtime-client.sh`, `start-runtime-client.sh`, and
  `install-macos-autostart.sh`.
- Native Linux: the same connect/start scripts and `install-linux-autostart.sh`.

Inspect the installed CLI's `--help` before choosing actual arguments. Treat `ready`,
`manual_action_required`, and a failing exit code as the script protocol; never infer the phase from
free-form text.

## Revoke, upgrade, and troubleshoot

Generate a revoke plan first. After confirmation, stop autostart and the daemon, disable agents,
remove runtimes and membership, revoke Tailscale access, and finally clean the credential-free
cache. Before an upgrade, record the CLI version; afterward, rerun the verifier and smoke task. Read
[references/lifecycle.md](references/lifecycle.md) for the complete procedures.

Troubleshoot in this fixed order: Tailscale reachability -> Multica identity -> workspace membership
-> daemon -> verifier -> agent access -> smoke. Address only the first failing stage.
