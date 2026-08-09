# Client lifecycle

## Upgrade

Record the CLI version, daemon ID, runtime IDs, agents, and autostart items. Upgrade only to an
explicit release, restart the daemon, then rerun verifier and smoke. On failure, preserve prior
evidence and stop; do not duplicate agents.

## Revoke

Plan only until the user confirms apply. Then:

1. disable local autostart;
2. stop the daemon;
3. disable/delete local-runtime agents;
4. have an owner/admin remove runtimes and workspace membership;
5. remove the exact email from the Server allowlist;
6. revoke tailnet membership or machine sharing;
7. clear the credential-free profile cache.

Return a receipt for each revocation. An offline machine is not proof of revoked access.
