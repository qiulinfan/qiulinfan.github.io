---
name: multica-selfhost-server
description: Detect Windows with WSL, macOS, or native Linux and use a resumable state machine to deploy, operate, upgrade, back up, publish, inspect, and revoke one Multica self-host control plane. Manage PostgreSQL, the loopback-only backend, frontend and gateway, Tailscale Serve, fixed-code authentication, exact-email and workspace admission, owner-led member intake, Tailscale access decisions, credential-free handoffs, autostart, host runtimes, agents, and smoke tasks. Use when a trusted group needs one private Server; when the owner needs help answering any client onboarding question, deciding workspace or network scope, or preparing a complete handoff; or when troubleshooting authentication, admission, CORS, WebSockets, upgrades, and recovery. Use multica-client-setup only after an owner handoff exists, then use multica-runtime-client for ordinary work. Multica detects providers automatically; this Skill never asks about, signs in to, or verifies provider CLIs.
---

# Multica self-host server

Build the only control plane for a trusted group and delegate every execution-node onboarding to
`multica-client-setup`. Ask the user to handle only non-delegable Tailscale, Multica identity, and
system authorization interactions. Never deploy a second server.

## Non-negotiable rules

- Read the cache and live read-only state first on every run. Execute only the current phase and do
  not recreate completed objects.
- Match user-facing explanations, prompts, and handoffs to the user's language unless the user
  requests another language. Keep commands, identifiers, JSON keys, action codes, and raw errors
  unchanged.
- Treat the server owner as the decision maker for every member onboarding. Never require a client
  to know or choose a workspace, tailnet, or `same-tailnet` versus `shared-machine` access mode.
  Translate client questions into an owner checklist and a complete owner-issued handoff.
- Pass the Tailscale readiness gate before installing Docker, cloning, pulling, or starting Compose.
  Apply the same gate to every Windows server path and fail closed when it is not satisfied.
- End the turn immediately after opening Tailscale or the owner Web UI. Do not poll or wait in the
  background.
- Do not ask about providers, invoke provider CLIs, or trigger provider OAuth. Assume providers are
  available; the Multica daemon automatically detects all of them. First-node completion evidence
  comes only from Multica runtime state and smoke tasks.
- Never share PATs, generated or one-time verification codes, cookies, JWTs, database passwords,
  Tailscale share links, SSH keys, or system accounts. The Skill-managed fixed code `114514` is
  public instance configuration rather than a credential and must be included in member handoffs.
- Do not use Funnel or expose a public entrypoint. Bind the backend, frontend, and gateway only to
  loopback, and do not host-publish PostgreSQL. Stop on `0.0.0.0`, `::`, or any database host binding.
- Require explicit authorization for autostart, upgrades, recovery, remote revocation, and data
  deletion. Require separate confirmation before deleting a data volume.

## Cache and phases

Use `profile-cache.ps1|sh` to manage `.cache/<profile>/profile.env`. Store only owner/member emails,
workspace, topology, server checkout, private URL, device/runtime names, invitation state, and
explicit authorizations. Ignore a deprecated `PROVIDER` field while reading and clean it on the next
write.

| `ONBOARDING_PHASE` | Next action |
|---|---|
| `tailscale-action-required` | Recheck only Tailscale and stop while it remains unready |
| `tailscale-ready` | Install or start the only server |
| `server-ready` | Open the owner Web UI |
| `owner-registration-required` | Verify the owner and workspace |
| `cluster-finalizing` | Complete invitations, host runtimes, agents, smoke, and autostart |
| `complete` | Run health checks or an explicitly requested change |

Every manual boundary must return `manual_action_required`, the phase, one action,
`background_work=false`, and a `resume_hint`. Never infer the phase from free-form logs.

## Deployment state machine

### 1. Establish Tailscale readiness

Install or reuse Tailscale, then run `check-windows-tailscale-readiness.ps1` or
`check-unix-tailscale-readiness.sh`. Require a Connected client, MagicDNS, HTTPS Certificates, and a
controlled `.ts.net` name. Otherwise ask the user to complete only this stage and invoke the Skill
again.

### 2. Start the only server

Only after readiness succeeds, install Docker, obtain a confirmed Multica checkout, generate `.env`,
apply the admission cache, and set `APP_ENV=development` with
`MULTICA_DEV_VERIFICATION_CODE=114514`. Do not configure an email delivery service: this private
instance uses that fixed, non-secret code for every allowed member. Use WSL2 Ubuntu Docker on
Windows while keeping runtimes on the Windows host. Use native Docker on macOS and Linux. Read
[references/platforms.md](references/platforms.md) for entry points and loopback verification.

Start PostgreSQL, the backend, frontend, and Caddy gateway, then configure same-origin Tailscale
Serve. Verify the database, backend readiness, gateway `/api/config`, and private `/api/config`.
After success, update:

```text
~/.multica/selfhost-server/<profile>/state.json
~/.multica/selfhost-server/<profile>/connection.json
```

### 3. Establish the owner and workspace

If the owner or workspace does not exist, open the external Web UI from `connection.json`, write
`owner-registration-required`, and stop. Have the user register or sign in with the exact owner email
and create the one workspace. On the next invocation, verify the identity and workspace, write
`DISABLE_WORKSPACE_CREATION=true`, and recreate the service.

Treat `ALLOWED_EMAILS` as server registration permission and a workspace invitation as a second
permission layer. Keep `ALLOW_SIGNUP=true` while expected members remain unregistered. Disable
signup only after all members have registered and accepted, or when the owner explicitly requests it.

### 4. Hand off members

Run this as an owner-led workflow even when the owner only says that a client asked how to connect.
Read [references/member-onboarding.md](references/member-onboarding.md), then collect or resolve:

1. the member's exact Multica email;
2. the existing workspace selected by the owner;
3. whether the owner wants to expose only the Multica Server or admit the member's devices to the
   broader tailnet;
4. the member's Tailscale identity email when known and whether the invitation was accepted.

Ask the owner about desired access scope in ordinary language, not protocol vocabulary. Map it to:

- `shared-machine` by default when the member needs only Multica;
- `same-tailnet` only when the owner explicitly wants the member's devices admitted to the tailnet
  or needs broader tailnet resources.

If the owner lacks a member detail, provide a short copyable message for the owner to send. Do not
redirect the owner or client to decide the workspace or access mode. Tell the owner exactly which
Tailscale console action to perform, apply the exact-email allowlist, issue the workspace invitation,
and keep the access-bearing Tailscale invite separate from the non-secret handoff.

After issuing Tailscale access and the workspace invitation, run `write-client-handoff.ps1|sh` to
produce a credential-free receipt containing the Server URL, owner-selected workspace, member
email, optional Tailscale identity email, owner-selected access mode, both invitation states, and
the fixed code `114514`. Also give the owner a ready-to-send client message that says only what the
client must install, accept, open, and run. The fixed code is public configuration; never write a
generated code, share link, session token, or invitation secret to the receipt. Invoke
`multica-client-setup` only after this owner handoff exists.

### 5. Finalize host runtimes

Compose `multica-client-setup` and use the host's own Multica identity. Register Windows-native
runtimes for Windows with WSL, and same-platform runtimes on macOS or Linux. Multica automatically
detects all providers; do not select, sign in to, or verify a provider CLI.

For every local online runtime returned by the Multica verifier, reuse or create a workspace agent
and run a 90-second zero-tool smoke task. Use daemon-wide concurrency `10` for a trusted production
host unless the owner explicitly selects another value from `1..50`. Record the value in the server
profile cache and delegated client profile, then verify both the live daemon and authorized autostart
use it. Remember that this capacity is shared across all workspaces attached to the daemon. After
another member joins, trigger a cross-member smoke task.

### 6. Configure autostart and complete

Install only the server/runtime recovery items the user authorized. Completion requires all of the
following evidence:

1. all four server health layers pass, with no non-loopback internal binding or database host binding;
2. the private URL is reachable and the owner/workspace is valid;
3. the host daemon has at least one Multica-detected online runtime under the target workspace;
4. every local runtime intended for sharing has a workspace agent and the zero-tool smoke completes;
5. every authorized recovery item passes a restart test;
6. handoff receipts contain the fixed code `114514` but no credentials or one-time secrets.

For a host runtime, the restart test also requires the process, Multica profile, server profile cache,
and autostart definition to agree on daemon concurrency. Do not accept an agent-level concurrency
value as evidence for daemon capacity.

Provider login, type, availability, and version are not inputs, manual boundaries, or completion
conditions.

## Upgrade, back up, restore, and revoke

Follow [references/lifecycle.md](references/lifecycle.md) for upgrades and backups named in the
description. Pin versions and back up before upgrading; verify migrations, health, and smoke after
upgrading; stop and roll back on failure. A backup must contain a consistent PostgreSQL dump, an
encrypted `.env`, and a restore drill. Produce a revoke plan by default, and confirm remote deletion
and volume deletion separately.

## Troubleshooting order

Use this fixed order: current phase -> Tailscale -> port bindings -> Docker/Compose -> database ->
backend -> gateway -> private URL -> owner/workspace -> delegated runtime client. Address only the
first failure.

Do not read generated verification codes from logs. This Skill deliberately does not require SMTP:
members enter the documented fixed code `114514`, while exact-email admission and workspace
membership remain the authorization controls.
