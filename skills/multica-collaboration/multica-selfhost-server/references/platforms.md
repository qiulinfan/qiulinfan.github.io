# Platform deployment

## Windows with WSL

Run the Server only in a WSL2 Ubuntu Docker Engine and run host runtimes only on Windows. Use this
order: Tailscale readiness -> `bootstrap-windows-wsl-server.ps1` ->
`start-windows-wsl-server.ps1` -> `publish-windows-tailscale.ps1`. Retain the native Windows Docker
controller only as a compatibility recovery entry point. It must read the same readiness phase and
must not clone, install, or start an unauthorized new server.

Run stop/export/restore through `invoke-windows-wsl-environment.ps1`; it translates only explicit
Windows paths and forwards arguments to the shared Unix lifecycle scripts inside the selected WSL
distribution. Environment export/restore is not supported by the native-Windows compatibility
controller.

## macOS

Use `start-macos-server.sh` and `publish-unix-tailscale.sh`, then use a LaunchAgent only after
authorization. When Docker Desktop first requires visible system interaction, stop and ask the user
to invoke the Skill again afterward.

Use `stop-unix-server.sh`, `export-unix-server-environment.sh`, and
`restore-unix-server-environment.sh` for cold stop/migration. Require `age` to be installed before
export or restore; do not install it or create identity material automatically.

## Native Linux

Use `start-linux-server.sh` and `publish-unix-tailscale.sh`, then use a systemd user service only
after authorization. Do not enable linger automatically. Make WSL detection fail closed.

Use the same three Unix lifecycle scripts. They operate on the native Docker Engine and leave the
restored stack stopped until `start-linux-server.sh` and `publish-unix-tailscale.sh` revalidate it.

## Port invariant

Resolve each Compose service container and inspect its published bindings with `docker port`.
Every backend/frontend binding must be `127.0.0.1` or `::1`; PostgreSQL must return no host binding.
Bind the Caddy gateway itself only to loopback and publish it with Tailscale Serve HTTPS. Do not
write successful state or a receipt when this invariant fails.

## Private-instance authentication

Every platform starter sets `APP_ENV=development` and `MULTICA_DEV_VERIFICATION_CODE=114514` before
starting Compose. Treat `114514` as public instance configuration, include it in client handoffs,
and do not configure SMTP or read generated verification codes from logs. Exact-email admission and
workspace membership remain separate authorization checks.
