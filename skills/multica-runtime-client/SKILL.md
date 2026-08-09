---
name: multica-runtime-client
description: Join macOS, Windows/WSL, or native Linux devices to a Multica workspace over private Tailscale. Use for initial or later runtime devices, Web UI access, VPN/proxy conflicts, identity or membership failures, offline runtimes, smoke tests, lifecycle work, and explicitly authorized autostart. Preflight VPN coexistence before browser flows; support persistent macOS Clash Verge split routing. Never inspect or authenticate provider CLIs, deploy a Server, or change admission policy.
---

# Multica runtime client

Join and manage this device only. Do not deploy the Multica Server stack.

## Boundaries

- Execute and verify from natural-language requests; do not hand commands to the user.
- Match user-facing language to the user. Preserve commands, identifiers, keys, action codes, and
  raw errors.
- Use each person's own Tailscale and Multica identities. Never accept owner credentials.
- Never inspect, select, install, sign in to, or verify provider CLIs. Multica runtime state is the
  only execution-plane evidence.
- Register Windows-native runtimes for Windows and WSL; POSIX scripts must fail closed in WSL.
- Require explicit authorization before installing autostart.
- Detect VPN, TUN, PAC, and system-proxy state before any browser flow. With another network client
  active, require persistent split routing and successful private-direct plus public-proxy probes.
  Never disable the user's VPN globally.
- Cache no credentials. Live state overrides cached state.

## Inputs

Read the platform profile cache first, then apply current-request overrides. Require:

- `.ts.net` HTTPS `ServerUrl`, workspace, and the user's `IdentityEmail`;
- `TAILSCALE_ACCESS_MODE=same-tailnet|shared-machine`;
- an auto-detected device name and concurrency, default `1`;
- whether to expose all local online runtimes and enable autostart.

Ignore cached `PROVIDER` and remove it on the next write.

## Workflow

### 1. Admit the private path

Run `check-windows-tailscale-access.ps1` on Windows or
`check-unix-tailscale-access.sh` on macOS/native Linux. Require connected Tailscale, a valid Server
URL, and reachable `/api/config`. If access is absent, return `manual_action_required` for the
invitation or machine share; do not call it a Multica 403.

Then inspect VPN/proxy state. On macOS run `prepare-macos-vpn-routing.sh`; it handles Clash Verge
system-proxy mode. Unknown clients, TUN mode, PAC-only routing, or unsafe updates require
`manual_action_required`. Windows/Linux need equivalent persistent exclusions. Continue only when
the private direct probe and public proxy probe both pass while the VPN remains enabled.

Follow [Tailscale access](references/tailscale-access.md).

### 2. Authenticate and select the workspace

Run the platform connect script. If visible browser/email action is required, open it and stop.
Require `auth status` email to equal `IdentityEmail`, then switch to the target workspace. Stop on
denied signup, unaccepted invitation, identity mismatch, or `workspace get` 403. Never edit remote
admission policy from this client workflow.

### 3. Start and verify runtimes

Start the daemon, then run the platform verifier. Accept only `online` runtime IDs that correlate
the target workspace ID and local daemon ID; require at least one. Never use list order, names,
provider strings, or another device's runtime. Follow [runtime verification](references/verification.md).

### 4. Expose agents and smoke-test

When authorized, process every verified local online runtime:

1. Reuse or create its agent.
2. Set `permission_mode=public_to` for the workspace.
3. Submit one zero-tool issue whose only allowed reply is `MULTICA_SMOKE_OK:<random-nonce>`.
4. Wait at most 90 seconds; require `completed` and an exact reply. Do not duplicate the issue.

For formal cross-member readiness, require another workspace member to trigger one smoke task.

### 5. Autostart and receipt

Install the platform autostart only when authorized. It may restore existing authentication, never
accept invitations or register accounts. Return server, workspace, identity email, access mode,
daemon ID, runtime IDs, agent IDs, smoke task ID, and recovery mechanism—never tokens.

## Completion

Report joined only when:

- Tailscale and the VPN coexistence gate pass;
- identity and target workspace match;
- the verifier returns a local online runtime;
- each intended runtime has a workspace agent and exact smoke success;
- any required cross-member smoke and authorized autostart checks pass.

Provider state is never an input or completion condition.

## Entry points and protocol

- Windows/WSL: `connect-windows-runtime-client.ps1`, `start-windows-runtime-client.ps1`,
  `install-windows-autostart.ps1`.
- macOS: `prepare-macos-vpn-routing.sh`, `connect-runtime-client.sh`,
  `start-runtime-client.sh`, `install-macos-autostart.sh`.
- Linux: the Unix connect/start scripts and `install-linux-autostart.sh`.

Inspect installed CLI `--help` before choosing arguments. Scripts return `ready`,
`manual_action_required`, or failure; do not infer state from prose.

For upgrades or revocation, follow [client lifecycle](references/lifecycle.md). Troubleshoot only the
first failing stage: Tailscale -> VPN/proxy -> identity -> workspace -> daemon -> verifier -> agent
access -> smoke.
