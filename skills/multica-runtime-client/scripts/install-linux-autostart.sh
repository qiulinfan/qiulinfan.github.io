#!/bin/sh
# Install a per-user systemd service for an authenticated native-Linux runtime client.

set -eu

dry_run=false
if [ "${1:-}" = --dry-run ]; then dry_run=true; shift; fi
server_url=${1:-}
profile=${2:-remote}
device_name=${3:-}
runtime_name=${4:-}
max_concurrent_tasks=${5:-1}
app_url=${6:-$server_url}
agent_timeout=${7:-0s}
workspace=${8:-}

[ "$(uname -s)" = Linux ] || { echo "This installer is only for native Linux." >&2; exit 3; }
if { [ -n "${WSL_INTEROP:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; } && [ "$dry_run" != true ]; then
  echo "WSL detected. Use the Windows scheduled-task installer for the Windows runtime." >&2
  exit 3
fi
case "$server_url" in http://*|https://*) ;; *) echo "Server URL must be absolute http(s)." >&2; exit 2 ;; esac
case "$app_url" in http://*|https://*) ;; *) echo "App URL must be absolute http(s)." >&2; exit 2 ;; esac
case "$profile" in *[!A-Za-z0-9._-]*|'') echo "Invalid Multica profile: $profile" >&2; exit 2 ;; esac
[ -n "$workspace" ] || { echo "Workspace is required." >&2; exit 2; }
case "$max_concurrent_tasks" in ''|*[!0-9]*) echo "Invalid task limit." >&2; exit 2 ;; esac
if [ "$max_concurrent_tasks" -lt 1 ] || [ "$max_concurrent_tasks" -gt 50 ]; then echo "Task limit must be between 1 and 50." >&2; exit 2; fi
case "$agent_timeout" in
  0|0s) ;;
  *ms) timeout_value=${agent_timeout%ms}; case "$timeout_value" in ''|*[!0-9]*) echo "Invalid agent timeout." >&2; exit 2 ;; esac ;;
  *s|*m|*h) timeout_value=${agent_timeout%?}; case "$timeout_value" in ''|*[!0-9]*) echo "Invalid agent timeout." >&2; exit 2 ;; esac ;;
  *) echo "Invalid agent timeout." >&2; exit 2 ;;
esac
if [ -z "$device_name" ]; then device_name=$(hostname); fi
if [ -z "$runtime_name" ]; then runtime_name="$device_name runtime"; fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
starter="$script_dir/start-runtime-client.sh"
test -f "$starter" || { echo "Starter not found: $starter" >&2; exit 3; }

systemd_quote() {
  value=$1
  newline='
'
  carriage=$(printf '\r')
  case "$value" in *"$newline"*|*"$carriage"*) echo "systemd argument cannot contain newlines." >&2; exit 2 ;; esac
  escaped=$(printf '%s' "$value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/%/%%/g')
  printf '"%s"' "$escaped"
}

unit_name="multica-runtime-client-$profile.service"
render_unit() {
  cat <<EOF
[Unit]
Description=Multica runtime client ($profile)
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=$(systemd_quote /bin/sh) $(systemd_quote "$starter") $(systemd_quote "$server_url") $(systemd_quote "$profile") $(systemd_quote "$device_name") $(systemd_quote "$runtime_name") $(systemd_quote "$max_concurrent_tasks") $(systemd_quote "$app_url") $(systemd_quote 120) $(systemd_quote "$agent_timeout") $(systemd_quote "$workspace")
RemainAfterExit=yes
Restart=on-failure
RestartSec=30
TimeoutStartSec=180

[Install]
WantedBy=default.target
EOF
}

if [ "$dry_run" = true ]; then render_unit; exit 0; fi
command -v systemctl >/dev/null 2>&1 || { echo "systemd is required for Linux autostart." >&2; exit 4; }
systemctl --user show-environment >/dev/null 2>&1 || {
  echo "The systemd user manager is unavailable; log into a normal user session first." >&2; exit 4;
}

unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
unit_path="$unit_dir/$unit_name"
mkdir -p "$unit_dir"
tmp="$unit_dir/tmp-$$-$unit_name"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
render_unit >"$tmp"
chmod 600 "$tmp"
if command -v systemd-analyze >/dev/null 2>&1; then systemd-analyze --user verify "$tmp"; fi
mv -f "$tmp" "$unit_path"
trap - EXIT HUP INT TERM

systemctl --user daemon-reload
systemctl --user enable "$unit_name" >/dev/null
systemctl --user restart "$unit_name"
systemctl --user is-active --quiet "$unit_name" || { echo "Linux runtime service did not become active." >&2; exit 5; }
/bin/sh "$script_dir/profile-cache.sh" set "$profile" \
  "PLATFORM=linux" "DEVICE_NAME=$device_name" "RUNTIME_NAME=$runtime_name" \
  "AUTOSTART_APPROVED=true" >/dev/null
echo "systemd user service installed: $unit_path"
