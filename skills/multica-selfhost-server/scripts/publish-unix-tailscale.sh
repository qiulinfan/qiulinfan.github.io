#!/bin/sh
# Publish an already-started macOS/native-Linux gateway with a bounded Tailscale Serve check.

set -eu

platform=${1:-}
server_repo=${2:-"$HOME/multica"}
profile=${3:-home}
gateway_port=${4:-8787}
install_autostart=${5:-false}
timeout_seconds=${6:-30}
case "$platform" in macos|linux) ;; *) echo "First argument must be macos or linux." >&2; exit 2 ;; esac
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
case "$gateway_port:$timeout_seconds" in *[!0-9:]*) echo "Invalid port or timeout." >&2; exit 2 ;; esac
[ "$gateway_port" -ge 1 ] && [ "$gateway_port" -le 65535 ] || { echo "Invalid gateway port." >&2; exit 2; }
[ "$timeout_seconds" -ge 5 ] && [ "$timeout_seconds" -le 120 ] || { echo "Timeout must be 5-120 seconds." >&2; exit 2; }
case "$install_autostart" in true|false) ;; *) echo "Autostart flag must be true or false." >&2; exit 2 ;; esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
readiness=$(/bin/sh "$script_dir/check-unix-tailscale-readiness.sh" "$profile" "$gateway_port" 5)
if ! printf '%s\n' "$readiness" | grep -q '"status":"ready"'; then
  printf '%s\n' "$readiness"
  exit 0
fi
published_url=$(printf '%s\n' "$readiness" | sed -n 's/.*"published_url":"\([^"]*\)".*/\1/p')
case "$published_url" in https://*.ts.net) ;; *) echo "Tailscale readiness returned an unsafe URL." >&2; exit 3 ;; esac

gateway_url="http://127.0.0.1:$gateway_port"
curl -fsS "$gateway_url/api/config" >/dev/null 2>&1 || {
  echo "The local Multica gateway is unavailable at $gateway_url." >&2; exit 4;
}
/bin/sh "$script_dir/start-$platform-server.sh" "$server_repo" "$profile" "$published_url" 120 "$gateway_port"

if [ "$install_autostart" = true ]; then
  /bin/sh "$script_dir/install-$platform-server-autostart.sh" \
    "$server_repo" "$profile" "$published_url" "$gateway_port"
fi

elapsed=0
while [ "$elapsed" -lt "$timeout_seconds" ]; do
  curl -fsS "$published_url/api/config" >/dev/null 2>&1 && break
  elapsed=$((elapsed + 1)); sleep 1
done
curl -fsS "$published_url/api/config" >/dev/null 2>&1 || {
  echo "Tailscale Serve was configured, but $published_url is not reachable." >&2; exit 5;
}
/bin/sh "$script_dir/profile-cache.sh" set "$profile" "ONBOARDING_PHASE=server-ready" >/dev/null
cat "$HOME/.multica/selfhost-server/$profile/connection.json"
