#!/bin/sh
# Install a per-user systemd service for the native-Linux self-host server.

set -eu

dry_run=false
if [ "${1:-}" = --dry-run ]; then dry_run=true; shift; fi
multica_repo=${1:-"$HOME/multica"}
profile=${2:-home}
published_url=${3:-}
gateway_port=${4:-8787}

[ "$(uname -s)" = Linux ] || { echo "This installer is only for native Linux." >&2; exit 3; }
if { [ -n "${WSL_INTEROP:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; } && [ "$dry_run" != true ]; then
  echo "WSL detected. Use the Windows scheduled-task installer." >&2
  exit 3
fi
case "$profile" in *[!A-Za-z0-9._-]*|'') echo "Invalid profile: $profile" >&2; exit 2 ;; esac
case "$published_url" in ''|http://*|https://*) ;; *) echo "Published URL must be http(s)." >&2; exit 2 ;; esac
case "$gateway_port" in ''|*[!0-9]*) echo "Invalid gateway port." >&2; exit 2 ;; esac
if [ "$gateway_port" -lt 1 ] || [ "$gateway_port" -gt 65535 ]; then echo "Invalid gateway port." >&2; exit 2; fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
starter="$script_dir/start-linux-server.sh"
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

unit_name="multica-selfhost-server-$profile.service"
render_unit() {
  cat <<EOF
[Unit]
Description=Multica self-host server ($profile)
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=$(systemd_quote /bin/sh) $(systemd_quote "$starter") $(systemd_quote "$multica_repo") $(systemd_quote "$profile") $(systemd_quote "$published_url") $(systemd_quote 120) $(systemd_quote "$gateway_port")
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
systemctl --user is-active --quiet "$unit_name" || { echo "Linux server service did not become active." >&2; exit 5; }
/bin/sh "$script_dir/profile-cache.sh" set "$profile" \
  "TOPOLOGY=linux" "SERVER_REPO=$multica_repo" "GATEWAY_PORT=$gateway_port" \
  "PUBLISHED_URL=$published_url" "SERVER_AUTOSTART_APPROVED=true" >/dev/null
echo "systemd user service installed: $unit_path"
