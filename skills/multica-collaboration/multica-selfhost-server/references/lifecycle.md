# Server lifecycle

## Stop without deleting

Require explicit downtime authorization. Resolve the exact Server checkout, profile, live Compose
containers, gateway, volumes, Tailscale Serve configuration, runtime activity, and authorized
autostart definitions before changing state. Stop or drain host runtimes before the control plane so
an in-flight task is not stranded.

Use `stop-unix-server.sh SERVER_REPO PROFILE` on macOS/native Linux. For Windows+WSL, use
`invoke-windows-wsl-environment.ps1 stop`; it forwards the same operation into the WSL Docker host.
The stop operation preserves containers, `multica_pgdata`, `multica_backend_uploads`, Tailscale
Serve, profile cache, and autostart definitions. It writes `stop.json` and verifies that Compose and
gateway containers are not running. An existing LaunchAgent, systemd unit, or scheduled task may
start the Server again at its next trigger; disabling it is a separate explicitly authorized action.

## Export one encrypted server environment

Require a completed stop receipt plus matching live stopped state. Do not accept a running backend,
frontend, or gateway. Require an absolute output root outside the Server checkout and a
user-controlled `age` recipient. `age` must already be installed; do not install it, create keys, or
read an identity file during export.

Run `export-unix-server-environment.sh SERVER_REPO PROFILE OUTPUT_ROOT AGE_RECIPIENT`, or the
Windows+WSL wrapper's `export` action. The exporter temporarily starts only PostgreSQL, waits for
health, creates a custom-format logical dump, copies uploads from the stopped backend container,
records the exact Git commit and container image IDs, includes the environment and non-secret cache
evidence, calculates per-file checksums, encrypts the entire tar stream to one `.tar.age`, and stops
PostgreSQL again on both success and failure. No plaintext environment may remain in the output
root. The adjacent receipt records the encrypted archive's SHA-256 and `restore_verified=false`.

An export becomes a verified backup only after a restore into an isolated empty target passes the
ordinary start, private URL, owner/workspace, runtime, agent, and smoke checks. Retain at least one
encrypted off-host copy and keep its identity separate from the archive.

## Restore into an empty target

Recovery requires explicit authorization. Complete the target host's Tailscale readiness gate and
confirm its Multica checkout before restore. Require all of these empty-target invariants:

- no target `.env`;
- no target Compose or gateway containers;
- no `multica_pgdata` or `multica_backend_uploads` volume;
- a local `age` identity file supplied by path, never copied into cache or output;
- the old authority remains stopped.

Run `restore-unix-server-environment.sh SERVER_REPO PROFILE ARCHIVE IDENTITY_FILE
RESTORE_EMPTY_TARGET`, or the Windows+WSL wrapper's `restore -ConfirmRestore` action. Refuse unsafe
tar paths and links, verify the internal checksums before writing, restore `.env` with mode `0600`,
restore PostgreSQL logically, restore uploads into a newly created volume, merge only allowlisted
admission/workspace cache fields, write `restore.json`, set `cluster-finalizing`, and leave all
containers stopped.

Do not delete or replace a conflicting environment or volume inside restore. If the owner wants to
discard it, obtain the separate exact deletion confirmation first, perform and verify that deletion,
then invoke restore again. After a successful data restore, run the normal platform start/publish
path and the full completion checks. If any validation fails, stop the new host and keep or return to
the old stopped authority; never make both writable.

If restore fails after mutation begins, leave the partial target stopped, write
`restore-failed.json`, and perform no automatic cleanup. Inspect that receipt and live volumes first;
deleting the partial target for a retry still requires the normal separate deletion confirmation.

## Migration between hosts

Use this cold-switch order:

1. drain/stop runtimes and stop the old Server;
2. export the encrypted environment and verify its receipt/hash;
3. transfer the archive without its identity;
4. restore to the empty target and keep it stopped;
5. start/publish the target and verify owner/workspace, health, runtime, agent, and smoke;
6. update client handoffs/profiles when the private URL changes;
7. keep the old Server stopped until the new authority is accepted;
8. delete old volumes only under a later separate confirmation.

## Upgrade

Upgrade only to an explicit release or commit and pinned image digests by default. Do not follow an
unreviewed `main` branch or floating tag. Proceed in order:

1. run health checks and create a verified encrypted environment export;
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
