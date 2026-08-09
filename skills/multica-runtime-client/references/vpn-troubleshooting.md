# VPN and proxy troubleshooting

Use this guide when another network client is active or the browser cannot open a reachable
Tailscale Server. A bundled script is a verified reference for its named client, not a universal VPN
configuration engine.

## Invariants

Keep the user's public VPN/proxy enabled. Require both probes:

```text
*.ts.net, 100.64.0.0/10, fd7a:115c:a1e0::/48 -> direct Tailscale -> /api/config
public identity provider                              -> existing proxy -> HTTPS success
```

Record the detected client, mode, configuration owner, persistence evidence, and both probe results.
Do not accept shell-only reachability as browser evidence.

## Diagnose before changing

1. Confirm Tailscale is online, resolve the Server hostname, and run `tailscale ping` when available.
2. Inspect OS system proxy, PAC, connected VPN services, TUN/Network Extension interfaces, routes,
   and owning processes.
3. Classify the path as `system-proxy`, `pac`, `tun`, `split-tunnel`, `managed-vpn`, or `unknown`.
4. Identify which application rewrites the setting after launch, profile/node changes, reconnect, or
   restart. Configure that owner; do not rely on a downstream temporary OS edit.
5. Back up only the exact non-secret configuration files before an authorized change.

## Mode-specific action

- **System proxy:** add the Tailscale domain and ranges to the owning client's persistent bypass.
  If the client overwrites OS settings, use its settings/API or durable rule layer, then verify the
  active OS proxy after a safe client restart.
- **PAC:** add a `DIRECT` decision for the Server hostname and Tailscale ranges in the authoritative
  PAC source. Verify the browser loads that PAC after reconnect/restart.
- **TUN or rule-based core:** prepend client-native direct rules before catch-all proxy rules. Verify
  DNS still resolves MagicDNS through the system/Tailscale resolver.
- **WireGuard/OpenVPN split tunnel:** exclude Tailscale destinations from the commercial tunnel while
  retaining their route through Tailscale. Do not replace broad `AllowedIPs` or route policy without
  understanding the existing configuration.
- **Managed enterprise VPN:** do not mutate policy. Produce an administrator request containing the
  exact domain/ranges and the two-probe acceptance test.
- **Unknown client:** report observed processes, interfaces, proxy/PAC state, and routes; ask only for
  the client name or policy owner that cannot be detected. Never guess a config path or syntax.

Consult the detected client's current official documentation before editing it. Promote a client to
automatic support only after a bundled adapter proves persistence across its relevant lifecycle
events. Otherwise use guided manual configuration.

## Support levels

- `not_required`: no competing path is active.
- `auto_managed`: a named adapter safely applies, persists, and verifies the configuration.
- `guided_manual`: the client is identified, but the user must complete a documented UI/admin step.
- `unsupported`: the owner or safe configuration mechanism is unknown.

For `guided_manual` or `unsupported`, return `manual_action_required` with
`phase=vpn-routing-required`, `action=configure_vpn_split_routing`, detected client/mode, required
direct destinations, `background_work=false`, and `resume_hint=rerun_runtime_client`. Installing a
watcher, LaunchAgent, service, scheduled task, or other persistent repair loop always requires
explicit authorization.

## Revalidation

After configuration, repeat both probes following every safe lifecycle event the client exposes:
profile/node change, reconnect, and restart. If an event cannot be exercised safely, report it as
unverified rather than claiming persistence. Troubleshoot only the first failing layer:

```text
Tailscale peer -> private TCP/HTTPS -> OS proxy/PAC -> client rules/routes -> public proxy -> browser
```
