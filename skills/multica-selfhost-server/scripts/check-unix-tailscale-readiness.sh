#!/bin/sh
# Check Tailscale login and HTTPS Serve consent without waiting on an interactive CLI flow.

set -eu

profile=${1:-home}
gateway_port=${2:-8787}
probe_timeout=${3:-5}
tailscale_bin=${TAILSCALE_BIN:-tailscale}
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
case "$gateway_port" in ''|*[!0-9]*) echo "Invalid gateway port." >&2; exit 2 ;; esac
case "$probe_timeout" in ''|*[!0-9]*) echo "Invalid probe timeout." >&2; exit 2 ;; esac
[ "$gateway_port" -ge 1 ] && [ "$gateway_port" -le 65535 ] || { echo "Invalid gateway port." >&2; exit 2; }
[ "$probe_timeout" -ge 2 ] && [ "$probe_timeout" -le 15 ] || { echo "Probe timeout must be 2-15 seconds." >&2; exit 2; }

kernel=$(uname -s)
case "$kernel" in
  Darwin) ;;
  Linux)
    if [ -n "${WSL_INTEROP:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; then
      echo "WSL must use the Windows Tailscale readiness script." >&2
      exit 3
    fi
    ;;
  *) echo "This readiness check supports macOS or native Linux." >&2; exit 3 ;;
esac

if [ -x "$tailscale_bin" ]; then :
elif command -v "$tailscale_bin" >/dev/null 2>&1; then tailscale_bin=$(command -v "$tailscale_bin")
elif [ "$tailscale_bin" = tailscale ] && [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
  tailscale_bin=/Applications/Tailscale.app/Contents/MacOS/Tailscale
else echo "Tailscale is not installed. Install it automatically, then rerun this check." >&2; exit 4
fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cache_script="$script_dir/profile-cache.sh"
gateway_url="http://127.0.0.1:$gateway_port"

wait_bounded() {
  wait_pid=$1
  wait_seconds=$2
  wait_count=0
  wait_limit=$((wait_seconds * 5))
  while [ "$wait_count" -lt "$wait_limit" ]; do
    process_state=$(ps -o stat= -p "$wait_pid" 2>/dev/null | tr -d '[:space:]' || true)
    case "$process_state" in
      ''|Z*)
        if wait "$wait_pid"; then return 0
        else wait_status=$?; return "$wait_status"
        fi
        ;;
    esac
    sleep 0.2
    wait_count=$((wait_count + 1))
  done
  kill "$wait_pid" 2>/dev/null || true
  wait "$wait_pid" 2>/dev/null || true
  return 124
}

write_manual() {
  /bin/sh "$cache_script" set "$profile" \
    "ONBOARDING_PHASE=tailscale-action-required" "TAILSCALE_SERVE_APPROVED=false" >/dev/null
  printf '%s\n' '{"schema_version":1,"status":"manual_action_required","action":"tailscale_login_and_https","phase":"tailscale-action-required","manual_url":"https://login.tailscale.com/admin/dns","instructions":["打开 Tailscale 客户端，用自己的账号登录，并确认本机显示 Connected。","在已登录的外部浏览器打开 Tailscale DNS 页面，启用 MagicDNS 和 HTTPS Certificates。","完成后再次调用 $multica-selfhost-server，并说“继续部署”。"]}'
}

umask 077
status_file=$(mktemp "${TMPDIR:-/tmp}/multica-tailscale-status.XXXXXX")
trap 'rm -f "$status_file"' EXIT HUP INT TERM
"$tailscale_bin" status --json >"$status_file" 2>/dev/null &
status_pid=$!
status_code=0
wait_bounded "$status_pid" "$probe_timeout" || status_code=$?
status_json=$(cat "$status_file")
rm -f "$status_file"
trap - EXIT HUP INT TERM
if [ "$status_code" -ne 0 ]; then write_manual; exit 0; fi
backend_state=$(printf '%s\n' "$status_json" | sed -n 's/^[[:space:]]*"BackendState"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
dns_name=$(printf '%s\n' "$status_json" | sed -n 's/^[[:space:]]*"DNSName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
dns_name=${dns_name%.}
case "$dns_name" in *[!A-Za-z0-9.-]*|'') dns_name= ;; esac
case "$dns_name" in *.ts.net) ;; *) dns_name= ;; esac
if [ "$backend_state" != Running ] || [ -z "$dns_name" ]; then write_manual; exit 0; fi

"$tailscale_bin" serve --bg --yes "$gateway_url" >/dev/null 2>&1 &
serve_pid=$!
serve_code=0
wait_bounded "$serve_pid" "$probe_timeout" || serve_code=$?
if [ "$serve_code" -ne 0 ]; then write_manual; exit 0; fi

published_url="https://$dns_name"
/bin/sh "$cache_script" set "$profile" \
  "PUBLISHED_URL=$published_url" "TAILSCALE_SERVE_APPROVED=true" \
  "ONBOARDING_PHASE=tailscale-ready" >/dev/null
printf '{"schema_version":1,"status":"ready","action":"continue_deployment","phase":"tailscale-ready","published_url":"%s","gateway_url":"%s"}\n' \
  "$published_url" "$gateway_url"
