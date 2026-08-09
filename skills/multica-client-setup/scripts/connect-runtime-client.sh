#!/bin/sh
# One-time interactive macOS/Linux onboarding using one server URL by default.

set -eu

usage() {
  echo "Usage: $0 --server-url URL [--app-url URL] [--workspace REF] [--profile NAME]" >&2
  echo "          [--callback-host HOST]" >&2
  echo "          [--identity-email EMAIL] [--tailscale-access-mode same-tailnet|shared-machine]" >&2
  echo "          [--device-name NAME] [--runtime-name NAME] [--max-concurrent-tasks N]" >&2
}

server_url=
app_url=
profile=remote
workspace=
callback_host=127.0.0.1
identity_email=
tailscale_access_mode=same-tailnet
device_name=
runtime_name=
max_concurrent_tasks=1
agent_timeout=0s

while [ "$#" -gt 0 ]; do
  case "$1" in
    --server-url) server_url=${2:-}; shift 2 ;;
    --app-url) app_url=${2:-}; shift 2 ;;
    --workspace) workspace=${2:-}; shift 2 ;;
    --profile) profile=${2:-}; shift 2 ;;
    --callback-host) callback_host=${2:-}; shift 2 ;;
    --identity-email) identity_email=${2:-}; shift 2 ;;
    --tailscale-access-mode) tailscale_access_mode=${2:-}; shift 2 ;;
    --device-name) device_name=${2:-}; shift 2 ;;
    --runtime-name) runtime_name=${2:-}; shift 2 ;;
    --max-concurrent-tasks) max_concurrent_tasks=${2:-}; shift 2 ;;
    --agent-timeout) agent_timeout=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

kernel=$(uname -s)
case "$kernel" in
  Darwin) platform=macos ;;
  Linux)
    if [ -n "${WSL_INTEROP:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; then
      echo "WSL detected. Register the Windows-native runtime with connect-windows-runtime-client.ps1." >&2
      exit 6
    fi
    platform=linux
    ;;
  *) echo "Unsupported operating system: $kernel" >&2; exit 3 ;;
esac

case "$server_url" in http://*|https://*) ;; *) echo "--server-url is required and must be http(s)." >&2; exit 2 ;; esac
if [ -z "$app_url" ]; then app_url=$server_url; fi
case "$app_url" in http://*|https://*) ;; *) echo "--app-url must be http(s)." >&2; exit 2 ;; esac
case "$profile" in *[!A-Za-z0-9._-]*|'') echo "Invalid profile: $profile" >&2; exit 2 ;; esac
[ -n "$workspace" ] || { echo "--workspace is required." >&2; exit 2; }
case "$workspace" in *[!A-Za-z0-9._-]*) echo "Invalid workspace reference." >&2; exit 2 ;; esac
case "$tailscale_access_mode" in same-tailnet|shared-machine) ;; *) echo "Invalid Tailscale access mode." >&2; exit 2 ;; esac
if [ -z "$callback_host" ]; then echo "Callback host cannot be empty." >&2; exit 2; fi
if [ -z "$device_name" ]; then
  if [ "$platform" = macos ] && command -v scutil >/dev/null 2>&1; then
    device_name=$(scutil --get ComputerName 2>/dev/null || hostname)
  else
    device_name=$(hostname)
  fi
fi
if [ -z "$runtime_name" ]; then runtime_name="$device_name runtime"; fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cache_entries="SERVER_URL=$server_url
APP_URL=$app_url
WORKSPACE=$workspace
INVITATION_STATUS=unknown
PLATFORM=$platform
DEVICE_NAME=$device_name
RUNTIME_NAME=$runtime_name
TAILSCALE_ACCESS_MODE=$tailscale_access_mode
TAILSCALE_ACCESS_STATUS=unknown
MAX_CONCURRENT_TASKS=$max_concurrent_tasks
AGENT_TIMEOUT=$agent_timeout"
set --
old_ifs=$IFS
IFS='
'
for cache_entry in $cache_entries; do set -- "$@" "$cache_entry"; done
IFS=$old_ifs
if [ -n "$identity_email" ]; then set -- "$@" "IDENTITY_EMAIL=$identity_email"; fi
/bin/sh "$script_dir/profile-cache.sh" set "$profile" "$@" >/dev/null

/bin/sh "$script_dir/check-unix-tailscale-access.sh" \
  "$server_url" "$profile" "$tailscale_access_mode"
if [ "$platform" = macos ]; then
  /bin/sh "$script_dir/prepare-macos-vpn-routing.sh" "$server_url" "$profile"
fi

PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.multica/bin:$HOME/.volta/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

if ! command -v multica >/dev/null 2>&1; then
  case "$platform" in
    macos)
      command -v brew >/dev/null 2>&1 || { echo "Homebrew is required on macOS." >&2; exit 3; }
      brew tap multica-ai/tap
      brew install multica-ai/tap/multica
      ;;
    linux)
      command -v curl >/dev/null 2>&1 || { echo "curl is required on Linux." >&2; exit 3; }
      command -v bash >/dev/null 2>&1 || { echo "bash is required by the installer." >&2; exit 3; }
      installer=$(mktemp)
      trap 'rm -f "$installer"' EXIT HUP INT TERM
      curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh -o "$installer"
      bash "$installer"
      rm -f "$installer"
      trap - EXIT HUP INT TERM
      ;;
  esac
fi
command -v multica >/dev/null 2>&1 || { echo "Multica CLI is not on PATH." >&2; exit 3; }

multica config set server_url "$server_url" --profile "$profile" >/dev/null
multica config set app_url "$app_url" --profile "$profile" >/dev/null
auth_status=$(multica auth status --profile "$profile" 2>&1 || true)
if printf '%s\n' "$auth_status" | grep -qi 'Not authenticated'; then
  echo "Starting interactive self-host login..."
  multica setup self-host \
    --server-url "$server_url" --app-url "$app_url" \
    --callback-host "$callback_host" --profile "$profile"
  auth_status=$(multica auth status --profile "$profile" 2>&1 || true)
fi
if [ -n "$identity_email" ]; then
  authenticated_email=$(printf '%s\n' "$auth_status" | sed -n 's/^[[:space:]]*User:[^(]*(\([^()[:space:]]*@[^()[:space:]]*\))[[:space:]]*$/\1/p' | head -n 1)
  [ -n "$authenticated_email" ] || { echo "Could not parse the authenticated Multica email." >&2; exit 4; }
  expected_lower=$(printf '%s' "$identity_email" | tr '[:upper:]' '[:lower:]')
  actual_lower=$(printf '%s' "$authenticated_email" | tr '[:upper:]' '[:lower:]')
  [ "$actual_lower" = "$expected_lower" ] || { echo "Authenticated Multica email does not match --identity-email." >&2; exit 4; }
fi

if [ -n "$workspace" ]; then
  echo "Verifying membership and selecting workspace '$workspace'..."
  multica workspace switch "$workspace" --profile "$profile"
  /bin/sh "$script_dir/profile-cache.sh" set "$profile" "INVITATION_STATUS=accepted" >/dev/null
fi

/bin/sh "$script_dir/start-runtime-client.sh" \
  "$server_url" "$profile" "$device_name" "$runtime_name" \
  "$max_concurrent_tasks" "$app_url" 120 "$agent_timeout" "$workspace"

printf '{"schema_version":1,"status":"ready","phase":"runtime-client-ready","server_url":"%s","workspace":"%s","identity_email":"%s","tailscale_access_mode":"%s"}\n' \
  "${server_url%/}" "$workspace" "$identity_email" "$tailscale_access_mode"
