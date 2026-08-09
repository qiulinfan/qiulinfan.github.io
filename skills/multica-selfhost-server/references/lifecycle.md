# Server lifecycle

## Backup

Before a backup, record the Multica commit or release, Compose image digests, schema/version, and
profile. Pause writes or use a consistency mechanism to create the PostgreSQL dump. Encrypt `.env`
separately to a destination outside the repository without printing its contents. Record the hash,
time, version, and retention policy. Do not mark a backup verified until an isolated restore drill
succeeds.

## Upgrade

Upgrade only to an explicit release or commit and pinned image digests by default. Do not follow an
unreviewed `main` branch or floating tag. Proceed in order:

1. run health checks and create a verified backup;
2. record the old revision and digests;
3. pull the explicit version and review migrations;
4. recreate the stack;
5. verify the database, backend, gateway, and private URL;
6. run the runtime verifier and smoke task;
7. stop on any failure, restore the old revision/digests, and verify again.

## Revoke and uninstall

Produce a plan by default. After apply is confirmed, revoke client agents, runtimes, membership,
allowlist entries, and Tailscale access before stopping runtime and server autostart. Delete
containers only after retaining a verified backup. Require a separate exact confirmation before
deleting the PostgreSQL volume. Return a revocation receipt for every remote and local object.
