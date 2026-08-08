#!/bin/sh
# One-time interactive macOS/Linux onboarding using one server URL by default.

set -eu

usage() {
  echo "Usage: $0 --server-url URL [--app-url URL] [--workspace REF] [--profile NAME]" >&2
  echo "          [--callback-host HOST]" >&2
  echo "          [--device-name NAME] [--runtime-name NAME] [--max-concurrent-tasks N]" >&2
}

server_url=
app_url=
profile=remote
workspace=
callback_host=127.0.0.1
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
    --device-name) device_name=${2:-}; shift 2 ;;
    --runtime-name) runtime_name=${2:-}; shift 2 ;;
    --max-concurrent-tasks) max_concurrent_tasks=${2:-}; shift 2 ;;
    --agent-timeout) agent_timeout=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$server_url" in http://*|https://*) ;; *) echo "--server-url is required and must be http(s)." >&2; exit 2 ;; esac
if [ -z "$app_url" ]; then app_url=$server_url; fi
case "$app_url" in http://*|https://*) ;; *) echo "--app-url must be http(s)." >&2; exit 2 ;; esac
case "$profile" in *[!A-Za-z0-9._-]*|'') echo "Invalid profile: $profile" >&2; exit 2 ;; esac
if [ -z "$callback_host" ]; then echo "Callback host cannot be empty." >&2; exit 2; fi

PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.multica/bin:$HOME/.volta/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

if ! command -v multica >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null 2>&1 || { echo "Homebrew is required on macOS." >&2; exit 3; }
      brew tap multica-ai/tap
      brew install multica-ai/tap/multica
      ;;
    Linux)
      command -v curl >/dev/null 2>&1 || { echo "curl is required on Linux." >&2; exit 3; }
      command -v bash >/dev/null 2>&1 || { echo "bash is required by the installer." >&2; exit 3; }
      installer=$(mktemp)
      trap 'rm -f "$installer"' EXIT HUP INT TERM
      curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh -o "$installer"
      bash "$installer"
      rm -f "$installer"
      trap - EXIT HUP INT TERM
      ;;
    *) echo "Unsupported operating system: $(uname -s)" >&2; exit 3 ;;
  esac
fi
command -v multica >/dev/null 2>&1 || { echo "Multica CLI is not on PATH." >&2; exit 3; }

multica config set server_url "$server_url" --profile "$profile" >/dev/null
multica config set app_url "$app_url" --profile "$profile" >/dev/null
if ! multica auth status --profile "$profile" >/dev/null 2>&1; then
  echo "Starting interactive self-host login..."
  multica setup self-host \
    --server-url "$server_url" --app-url "$app_url" \
    --callback-host "$callback_host" --profile "$profile"
fi

if [ -n "$workspace" ]; then
  echo "Verifying membership and selecting workspace '$workspace'..."
  multica workspace switch "$workspace" --profile "$profile"
fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
/bin/sh "$script_dir/start-runtime-client.sh" \
  "$server_url" "$profile" "$device_name" "$runtime_name" \
  "$max_concurrent_tasks" "$app_url" 120 "$agent_timeout" "$workspace"

echo "This machine is registered as a Multica runtime client."
