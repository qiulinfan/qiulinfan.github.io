---
name: multica-client-setup
description: Set up a macOS, Windows/WSL, or native Linux device as a Multica client from zero details, only a Server URL, or a complete owner handoff. Obtain owner-chosen workspace and Tailscale access details, install and configure the Multica CLI, diagnose VPN/proxy conflicts, persist and verify supported split routing, authenticate, start and verify local runtimes, create workspace agents, smoke-test, and optionally configure authorized autostart. Use for first-time onboarding, Web UI reachability, admission failures, installation or configuration recovery, upgrades, and revocation. Do not use for ordinary post-setup agent, issue, task, or runtime operations; use multica-runtime-client instead. Never inspect provider CLIs, deploy a Server, or change admission policy.
---

# Multica client setup

Join and configure this device only. Do not deploy the Multica Server stack or run ordinary
post-setup work; hand that off to `multica-runtime-client` after completion.

## Boundaries

- Execute and verify from natural-language requests; do not hand commands to the user.
- Match user-facing language to the user. Preserve commands, identifiers, keys, action codes, and
  raw errors.
- Use each person's own Tailscale and Multica identities. Never accept owner credentials.
- Never inspect, select, install, sign in to, or verify provider CLIs. Multica runtime state is the
  only execution-plane evidence.
- Register Windows-native runtimes for Windows and WSL; POSIX scripts must fail closed in WSL.
- Require explicit authorization before installing autostart.
- Detect VPN, TUN, PAC, and system-proxy state before browser flows. With another network client
  active, require persistent split routing and successful private-direct plus public-proxy probes.
  Never disable the user's VPN globally.
- Cache no credentials. Live state overrides cached state.

## Staged inputs

Read the profile cache, apply current-request overrides, then classify the entry state as no details,
a Server URL/partial handoff, or a complete owner handoff. Never demand all fields at once.

The member decides their own `IdentityEmail` and later sharing/autostart preferences. Detect the
device name, current Tailscale identity when available, and default daemon concurrency to `10`.
Treat this as a daemon-wide capacity shared by every workspace and runtime registered to that local
daemon, not as an agent-only setting. If the Tailscale account email differs from `IdentityEmail`,
include both in the owner request. The owner
alone chooses the workspace and
`TAILSCALE_ACCESS_MODE=same-tailnet|shared-machine`, then supplies them through a credential-free
handoff. Ignore cached `PROVIDER` and remove it on the next write. Never cache invitation/share links.

## Workflow

### 0. Obtain owner admission

Run this stage even when the user provides nothing. Immediately explain that joining requires the
owner's private Server handoff and the member's own Multica email. If `IdentityEmail` is missing,
show the owner-request outline, ask for the email, and return `manual_action_required` with
`phase=member-identity-required` and `action=provide_member_email`.

Once the email is known, output a filled, copyable message in the user's language. Include the
member's Multica email, their different Tailscale email if applicable, and any known Server URL. Ask
the owner to use `multica-selfhost-server` to:

1. add the exact member email to the Server allowlist;
2. choose and invite the member to a workspace;
3. choose and issue either tailnet membership or a machine share;
4. return a credential-free handoff with Server URL, chosen workspace, access mode, both invitation
   states, member email, and the instance verification code.

If the Server URL is unknown, explicitly tell the member to request it. Do not ask the member to
choose or guess the workspace or access mode. Tailscale invitations/share links must go directly to
the member through Tailscale; never ask the member to paste them into chat.

List only missing owner actions when a partial handoff exists. Until the handoff and owner actions
are complete, return `manual_action_required` with
`phase=owner-handoff-required`, `action=request_owner_handoff`, `background_work=false`, and
`resume_hint=rerun_client_setup`. Preserve valid partial inputs for the next invocation.

### 1. Admit the private path

Run `check-windows-tailscale-access.ps1` on Windows or
`check-unix-tailscale-access.sh` on macOS/native Linux. Require connected Tailscale, the handoff
Server URL, and reachable `/api/config`. If access is absent, guide the member to install/sign in to
Tailscale or accept the owner-issued invitation/share, then return `manual_action_required`; do not
call it a Multica 403.

Then classify VPN/proxy ownership and mode before changing it. On macOS,
`prepare-macos-vpn-routing.sh` is the complete static adapter for Clash Verge system-proxy mode; it
persists direct routing in the active profile's Rules Enhancement, applies an immediate macOS proxy
bypass, and verifies the generated rules plus both paths. When the profile must be reloaded, stop at
the returned manual restart action; the adapter must never quit or relaunch the network client. Do
not treat it as a generic VPN script.

For every other client or mode, follow [VPN troubleshooting](references/vpn-troubleshooting.md):
inspect live state, consult current official documentation, configure the authoritative layer when
safe, or return an evidence-rich `manual_action_required`. Never guess config syntax or claim
persistence without revalidating relevant profile/node, reconnect, and restart events. Continue only
when the private direct probe and public proxy probe both pass while the VPN remains enabled.

Follow [Tailscale access](references/tailscale-access.md).

### 2. Authenticate and select the owner-provided workspace

Run the platform connect script. If visible browser/email action is required, open it and stop.
Require `auth status` email to equal `IdentityEmail`, then switch to the handoff workspace. Stop on
denied signup, unaccepted invitation, identity mismatch, or `workspace get` 403. Never edit remote
admission policy from this client workflow.

### 3. Start and verify runtimes

Persist the chosen daemon capacity in the Multica profile, start the daemon with the same value,
then run the platform verifier. Accept only `online` runtime IDs that correlate the target workspace
ID and local daemon ID; require at least one. Verify the live daemon launch/effective configuration
still reports the chosen capacity. Never use list order, names, provider strings, or another device's
runtime. Follow [runtime verification](references/verification.md).

### 4. Expose agents and smoke-test

When authorized, process every verified local online runtime:

1. Reuse or create its agent.
2. For every newly created Codex agent, pass this exact logical `--custom-args` JSON array:
   `["-c", "sandbox_mode=\"danger-full-access\"", "-c", "approval_policy=\"never\""]`.
   Multica tasks use isolated Codex homes, so never rely on the user's global Codex configuration
   or sandbox marker. Do not apply these Codex-only arguments to other providers.
3. Set `permission_mode=public_to` for the workspace, then read the agent back and verify its runtime,
   permission targets, requested model and thinking level, and—for Codex—the exact custom arguments.
4. Submit one zero-tool issue whose only allowed reply is `MULTICA_SMOKE_OK:<random-nonce>`.
5. Wait at most 90 seconds; require `completed` and an exact reply. Do not duplicate the issue.

For formal cross-member readiness, require another workspace member to trigger one smoke task.

### 5. Autostart and receipt

Install the platform autostart only when authorized. It may restore existing authentication, never
accept invitations or register accounts. Inspect the installed task, unit, or launch item and require
an existing starter path plus the same chosen daemon capacity; a successful registration command is
not enough. Return server, workspace, identity email, access mode, daemon ID, runtime IDs, agent IDs,
smoke task ID, daemon capacity, and recovery mechanism—never tokens. Hand ordinary agent, issue,
task, and post-setup runtime operations to `multica-runtime-client`.

## Completion

Report joined only when:

- the owner handoff confirms allowlist, workspace invitation, and Tailscale access actions;
- Tailscale and the VPN coexistence gate pass;
- identity and handoff workspace match;
- the verifier returns a local online runtime;
- each intended runtime has a workspace agent and exact smoke success;
- the live daemon and persisted profile agree on the chosen concurrency;
- any required cross-member smoke and authorized autostart checks pass, including the installed
  starter path and concurrency argument.

Provider state is never an input or completion condition.

## Entry points and protocol

- Windows/WSL: `connect-windows-runtime-client.ps1`, `start-windows-runtime-client.ps1`,
  `install-windows-autostart.ps1`.
- macOS Clash Verge reference: `prepare-macos-vpn-routing.sh`; all clients use
  `connect-runtime-client.sh`,
  `start-runtime-client.sh`, `install-macos-autostart.sh`.
- Linux: the Unix connect/start scripts and `install-linux-autostart.sh`.

Inspect installed CLI `--help` before choosing arguments. Scripts return `ready`,
`manual_action_required`, or failure; do not infer state from prose.

For upgrades or revocation, follow [client lifecycle](references/lifecycle.md). Troubleshoot only the
first failing stage: owner handoff -> Tailscale -> VPN/proxy -> identity -> workspace -> daemon ->
verifier -> agent access -> smoke.
