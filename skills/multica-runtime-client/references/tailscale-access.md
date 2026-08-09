# Tailscale access

## Modes

- `same-tailnet`: have the member join the server's tailnet with their own Tailscale account. Never
  share an account.
- `shared-machine`: have the owner share only the Multica server machine with that member. Use the
  server's full `hostname.tailnet.ts.net` name from the client.

Both modes provide network access only. Multica `ALLOWED_EMAILS`, account registration, and
workspace membership are independent permissions and cannot replace one another.

## Agent check order

1. Confirm that Tailscale is installed and `BackendState=Running`.
2. Confirm that the handoff Server URL is a credential-free `.ts.net` HTTPS origin.
3. Request `<server>/api/config`; stop at this stage if DNS, ACLs, the invitation, or machine sharing
   is not ready.
4. Start the Multica identity flow only after writing `TAILSCALE_ACCESS_STATUS=reachable`.

Do not scan the LAN, guess the tailnet, use another machine's loopback address, create a public
entrypoint automatically, or fall back to Funnel.

## Manual boundary

Return a structured result such as:

```json
{"status":"manual_action_required","phase":"tailscale-access-required","action":"accept_tailnet_invite","background_work":false,"resume_hint":"rerun_runtime_client"}
```

Treat share invitation links as access-bearing secrets. Never write them to the cache, handoff
receipt, logs, or conversation.
