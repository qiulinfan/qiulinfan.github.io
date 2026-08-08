#!/bin/sh
# Install a per-user LaunchAgent for the macOS self-host server only.

set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
starter="$script_dir/start-macos-server.sh"
multica_repo=${1:-"$HOME/multica"}
profile=${2:-local}
published_url=${3:-}
gateway_port=${4:-8787}
case "$profile" in *[!A-Za-z0-9._-]*|'') echo "Invalid profile: $profile" >&2; exit 2 ;; esac
test -f "$starter" || { echo "Starter not found: $starter" >&2; exit 3; }

/bin/sh "$starter" "$multica_repo" "$profile" "$published_url" 120 "$gateway_port"

label="dev.multica.selfhost-server.$profile"
agent_dir="$HOME/Library/LaunchAgents"
log_dir="$HOME/Library/Logs/Multica"
plist="$agent_dir/$label.plist"
mkdir -p "$agent_dir" "$log_dir"
xml_escape() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }

cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array>
    <string>/bin/sh</string><string>$(xml_escape "$starter")</string>
    <string>$(xml_escape "$multica_repo")</string><string>$(xml_escape "$profile")</string>
    <string>$(xml_escape "$published_url")</string>
    <string>120</string><string>$(xml_escape "$gateway_port")</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$(xml_escape "$log_dir/launchd-server-$profile.log")</string>
  <key>StandardErrorPath</key><string>$(xml_escape "$log_dir/launchd-server-$profile.err.log")</string>
</dict></plist>
EOF
chmod 600 "$plist"
plutil -lint "$plist"
uid=$(id -u)
launchctl bootout "gui/$uid" "$plist" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$uid" "$plist"
launchctl enable "gui/$uid/$label"
launchctl kickstart -k "gui/$uid/$label"
echo "LaunchAgent installed: $plist"
