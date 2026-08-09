---
name: multica-selfhost-server
description: Detect Windows with WSL, macOS, or native Linux from natural-language requests and use a resumable state machine to deploy, start, upgrade, back up, publish, inspect, and revoke one Multica self-host control plane. Manage PostgreSQL, the backend, frontend, loopback-only gateway, Tailscale Serve, a fixed private-instance verification code, exact-email admission, a shared workspace, credential-free client handoffs, server autostart, and multica-runtime-client orchestration for host runtimes, workspace agents, and bounded smoke tasks. Use when a trusted group needs one private Server or when troubleshooting authentication, admission, CORS, WebSockets, upgrades, and recovery. Use multica-runtime-client alone for later devices. Multica automatically detects all providers; provider handling is not a workflow step, and this Skill never asks about, signs in to, or directly verifies a provider CLI.
---

# Multica self-host server

Build the only control plane for a trusted group and delegate every execution node to
`multica-runtime-client`. Ask the user to handle only non-delegable Tailscale, Multica identity, and
system authorization interactions. Never deploy a second server.

## Non-negotiable rules

- Read the cache and live read-only state first on every run. Execute only the current phase and do
  not recreate completed objects.
- Match user-facing explanations, prompts, and handoffs to the user's language unless the user
  requests another language. Keep commands, identifiers, JSON keys, action codes, and raw errors
  unchanged.
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

Choose one access mode for each member:

- `same-tailnet`: join the same tailnet with the member's own Tailscale account;
- `shared-machine`: share only the Multica server machine.

After issuing Tailscale access and the workspace invitation, run `write-client-handoff.ps1|sh` to
produce a credential-free receipt containing the Server URL, workspace, member email, both
invitation states, and the fixed code `114514`. The fixed code is public configuration; never write
a generated code, share link, session token, or invitation secret to the receipt. Invoke
`multica-runtime-client` on the client with that receipt.

### 5. Finalize host runtimes

Compose `multica-runtime-client` and use the host's own Multica identity. Register Windows-native
runtimes for Windows with WSL, and same-platform runtimes on macOS or Linux. Multica automatically
detects all providers; do not select, sign in to, or verify a provider CLI.

For every local online runtime returned by the Multica verifier, reuse or create a workspace agent
and run a 90-second zero-tool smoke task. After another member joins, trigger a cross-member smoke
task.

### 6. Configure autostart and complete

Install only the server/runtime recovery items the user authorized. Completion requires all of the
following evidence:

1. all four server health layers pass, with no non-loopback internal binding or database host binding;
2. the private URL is reachable and the owner/workspace is valid;
3. the host daemon has at least one Multica-detected online runtime under the target workspace;
4. every local runtime intended for sharing has a workspace agent and the zero-tool smoke completes;
5. every authorized recovery item passes a restart test;
6. handoff receipts contain the fixed code `114514` but no credentials or one-time secrets.

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
