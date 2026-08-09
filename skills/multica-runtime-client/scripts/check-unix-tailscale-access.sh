#!/bin/sh
# Verify that this macOS/native-Linux device can reach a private Multica server through Tailscale.

set -eu

server_url=${1:-}
profile=${2:-remote}
access_mode=${3:-same-tailnet}
timeout_seconds=${4:-5}
case "$server_url" in https://*) ;; *) echo "Server URL must be a Tailscale HTTPS origin." >&2; exit 2 ;; esac
server_url=${server_url%/}
server_host=${server_url#https://}
case "$server_host" in *'/'*|*':'*|*'@'*|*[?#]*|'') echo "Server URL must be a credential-free HTTPS origin on port 443." >&2; exit 2 ;; esac
case "$server_host" in *.ts.net) ;; *) echo "Server URL host must end in .ts.net." >&2; exit 2 ;; esac
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
case "$access_mode" in same-tailnet|shared-machine) ;; *) echo "Invalid Tailscale access mode." >&2; exit 2 ;; esac
case "$timeout_seconds" in ''|*[!0-9]*) echo "Invalid timeout." >&2; exit 2 ;; esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cache_script="$script_dir/profile-cache.sh"

manual() {
  reason=$1
  /bin/sh "$cache_script" set "$profile" \
    "TAILSCALE_ACCESS_MODE=$access_mode" "TAILSCALE_ACCESS_STATUS=pending" >/dev/null
  if [ "$access_mode" = same-tailnet ]; then action=accept_tailnet_invite; else action=accept_machine_share; fi
  printf '{"schema_version":1,"status":"manual_action_required","phase":"tailscale-access-required","action":"%s","reason":"%s","background_work":false,"resume_hint":"继续连接客户端"}\n' \
    "$action" "$reason"
  exit 7
}

command -v tailscale >/dev/null 2>&1 || manual tailscale_not_installed
status_json=$(tailscale status --json 2>/dev/null || true)
printf '%s\n' "$status_json" | grep -q '"BackendState"[[:space:]]*:[[:space:]]*"Running"' || manual tailscale_not_connected
command -v curl >/dev/null 2>&1 || { echo "curl is required." >&2; exit 3; }
curl -fsS --max-time "$timeout_seconds" "${server_url%/}/api/config" >/dev/null 2>&1 || \
  manual server_not_reachable_or_acl_denied

/bin/sh "$cache_script" set "$profile" \
  "TAILSCALE_ACCESS_MODE=$access_mode" "TAILSCALE_ACCESS_STATUS=reachable" >/dev/null
printf '{"schema_version":1,"status":"ready","phase":"tailscale-access-ready","access_mode":"%s","server_url":"%s"}\n' \
  "$access_mode" "${server_url%/}"
