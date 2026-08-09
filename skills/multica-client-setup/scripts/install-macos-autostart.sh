#!/bin/sh
# Install a per-user LaunchAgent for an authenticated Multica runtime client.

set -eu

[ "$(uname -s)" = Darwin ] || { echo "This installer is only for macOS." >&2; exit 3; }

server_url=${1:-}
profile=${2:-remote}
device_name=${3:-}
runtime_name=${4:-}
max_concurrent_tasks=${5:-10}
app_url=${6:-$server_url}
agent_timeout=${7:-0s}
workspace=${8:-}

case "$profile" in *[!A-Za-z0-9._-]*|'') echo "Invalid Multica profile: $profile" >&2; exit 2 ;; esac
[ -n "$workspace" ] || { echo "Workspace is required." >&2; exit 2; }
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
source_starter="$script_dir/start-runtime-client.sh"
source_verifier="$script_dir/verify-runtime-client.sh"
if [ ! -f "$source_starter" ]; then echo "Starter not found: $source_starter" >&2; exit 3; fi
if [ ! -f "$source_verifier" ]; then echo "Verifier not found: $source_verifier" >&2; exit 3; fi

/bin/sh "$source_starter" "$server_url" "$profile" "$device_name" "$runtime_name" \
  "$max_concurrent_tasks" "$app_url" 120 "$agent_timeout" "$workspace"
/bin/sh "$script_dir/profile-cache.sh" set "$profile" \
  "PLATFORM=macos" "AUTOSTART_APPROVED=true" >/dev/null

if [ -z "$device_name" ]; then device_name=$(scutil --get ComputerName 2>/dev/null || hostname); fi
if [ -z "$runtime_name" ]; then runtime_name="$device_name runtime"; fi

label="dev.multica.runtime-client.$profile"
agent_dir="$HOME/Library/LaunchAgents"
log_dir="$HOME/Library/Logs/Multica"
runtime_dir="$HOME/.multica/runtime-client/$profile"
plist="$agent_dir/$label.plist"
mkdir -p "$agent_dir" "$log_dir" "$runtime_dir"
starter="$runtime_dir/start-runtime-client.sh"
verifier="$runtime_dir/verify-runtime-client.sh"
cp "$source_starter" "$starter"
cp "$source_verifier" "$verifier"
chmod 700 "$starter" "$verifier"

xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

starter_xml=$(xml_escape "$starter")
server_xml=$(xml_escape "$server_url")
profile_xml=$(xml_escape "$profile")
device_xml=$(xml_escape "$device_name")
runtime_xml=$(xml_escape "$runtime_name")
max_xml=$(xml_escape "$max_concurrent_tasks")
app_xml=$(xml_escape "$app_url")
timeout_xml=$(xml_escape "$agent_timeout")
workspace_xml=$(xml_escape "$workspace")
stdout_xml=$(xml_escape "$log_dir/runtime-client-$profile.log")
stderr_xml=$(xml_escape "$log_dir/runtime-client-$profile.err.log")

cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array>
    <string>/bin/sh</string><string>$starter_xml</string><string>$server_xml</string>
    <string>$profile_xml</string><string>$device_xml</string><string>$runtime_xml</string>
    <string>$max_xml</string><string>$app_xml</string><string>120</string><string>$timeout_xml</string>
    <string>$workspace_xml</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$stdout_xml</string>
  <key>StandardErrorPath</key><string>$stderr_xml</string>
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
