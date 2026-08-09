# Tailscale access

## Modes

- `same-tailnet`: the member joins with their own Tailscale account.
- `shared-machine`: the owner shares only the Server machine; use its full `.ts.net` hostname.

The owner chooses the mode; never ask the member to choose or guess it. Network admission, Multica
allowlisting, registration, and workspace membership are independent.

## Gate

1. Require installed, connected Tailscale (`BackendState=Running`).
2. Require a credential-free `.ts.net` HTTPS Server URL.
3. Request `<server>/api/config`; stop for DNS, ACL, invitation, or sharing failure.
4. Before browser/auth flows, inspect VPN, TUN, PAC, and system-proxy state. Shell reachability alone
   does not prove the browser path.
5. Record `TAILSCALE_ACCESS_STATUS=reachable` only after the VPN coexistence gate passes.

Never scan the LAN, guess the tailnet, use another machine's loopback, publish a public endpoint, or
fall back to Funnel.

## VPN coexistence

Without another network client, record `vpn-routing-not-required`. Otherwise persist routing that
sends `.ts.net` and Tailscale ranges directly while retaining the public proxy. Verify both paths:

```text
Multica / Tailscale ranges -> direct Tailscale -> /api/config
Public identity provider  -> existing proxy   -> HTTPS success
```

For macOS Clash Verge system-proxy mode, run `scripts/prepare-macos-vpn-routing.sh`. It persists the
active profile's direct Rules Enhancement and applies a matching macOS proxy bypass for immediate
effect. If the profile must be reloaded, return `action=restart_clash_verge` and wait for the member
to do it; never quit or relaunch the network client. After resume, check the generated rules and
both direct and forced-proxy paths.

For all other clients and modes, follow [VPN and proxy troubleshooting](vpn-troubleshooting.md).
Do not disable the VPN, apply guessed syntax, or confuse a one-time OS edit with persistence.

## Manual boundary

Return structured state, for example:

```json
{"status":"manual_action_required","phase":"tailscale-access-required","action":"accept_tailnet_invite","background_work":false,"resume_hint":"rerun_runtime_client"}
```

For VPN failure use `phase=vpn-routing-required` and `action=configure_vpn_split_routing`. Treat
share links as secrets; never cache, log, or include them in receipts or conversation.
