# Client lifecycle

## Upgrade

Before upgrading, record the Multica CLI version, daemon ID, runtime IDs, agents, and autostart
items. Use only an explicit release. After upgrading, restart the daemon and run the verifier and
zero-tool smoke. If verification fails, preserve the prior evidence and stop; do not create duplicate
agents.

## Revoke

Produce only a plan by default. After the user confirms apply, proceed in order:

1. disable and stop local autostart;
2. stop the daemon;
3. disable or delete agents bound to local runtimes;
4. have an owner or administrator remove the runtimes and workspace membership;
5. remove the exact email from the server allowlist;
6. revoke the Tailscale tailnet membership or machine share;
7. clean the local credential-free profile cache.

Return a receipt for every remote object, account, and access revocation. An offline machine does not
prove that access was revoked.
