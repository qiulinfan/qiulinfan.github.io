#!/bin/sh
# Start a macOS/Linux Multica runtime client against an existing server.

set -eu

kernel=$(uname -s)
case "$kernel" in
  Darwin) ;;
  Linux)
    if [ -n "${WSL_INTEROP:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; then
      echo "WSL detected. Start the Windows-native runtime instead." >&2
      exit 6
    fi
    ;;
  *) echo "Unsupported operating system: $kernel" >&2; exit 3 ;;
esac

server_url=${1:-}
profile=${2:-remote}
device_name=${3:-}
runtime_name=${4:-}
max_concurrent_tasks=${5:-10}
app_url=${6:-$server_url}
timeout_seconds=${7:-120}
agent_timeout=${8:-0s}
workspace=${9:-}

PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.multica/bin:$HOME/.volta/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

case "$server_url" in http://*|https://*) ;; *) echo "Server URL must be absolute http(s)." >&2; exit 2 ;; esac
case "$app_url" in http://*|https://*) ;; *) echo "App URL must be absolute http(s)." >&2; exit 2 ;; esac
case "$profile" in *[!A-Za-z0-9._-]*|'') echo "Invalid Multica profile: $profile" >&2; exit 2 ;; esac
[ -n "$workspace" ] || { echo "Workspace is required." >&2; exit 2; }
case "$max_concurrent_tasks" in ''|*[!0-9]*) echo "Invalid task limit." >&2; exit 2 ;; esac
case "$timeout_seconds" in ''|*[!0-9]*) echo "Invalid timeout." >&2; exit 2 ;; esac
if [ "$max_concurrent_tasks" -lt 1 ] || [ "$max_concurrent_tasks" -gt 50 ]; then
  echo "Task limit must be between 1 and 50." >&2; exit 2
fi
if [ "$timeout_seconds" -lt 10 ] || [ "$timeout_seconds" -gt 600 ]; then
  echo "Timeout must be between 10 and 600 seconds." >&2; exit 2
fi
case "$agent_timeout" in
  0|0s) ;;
  *[smh])
    timeout_value=${agent_timeout%?}
    case "$timeout_value" in ''|*[!0-9]*) echo "Invalid agent timeout: $agent_timeout" >&2; exit 2 ;; esac
    ;;
  *) echo "Invalid agent timeout: $agent_timeout" >&2; exit 2 ;;
esac
if [ -z "$device_name" ]; then
  if command -v scutil >/dev/null 2>&1; then device_name=$(scutil --get ComputerName 2>/dev/null || hostname)
  else device_name=$(hostname); fi
fi
if [ -z "$runtime_name" ]; then runtime_name="$device_name runtime"; fi
if ! command -v multica >/dev/null 2>&1; then
  echo "Multica CLI is not installed. Run connect-runtime-client.sh first." >&2; exit 3
fi

multica config set server_url "$server_url" --profile "$profile" >/dev/null
multica config set app_url "$app_url" --profile "$profile" >/dev/null
multica config set max_concurrent_tasks "$max_concurrent_tasks" --profile "$profile" >/dev/null

authenticated=false
attempt=0
while [ "$attempt" -lt "$timeout_seconds" ]; do
  if multica auth status --profile "$profile" >/dev/null 2>&1; then authenticated=true; break; fi
  attempt=$((attempt + 1)); sleep 1
done
if [ "$authenticated" != true ]; then
  echo "Profile '$profile' is not authenticated or the server is unavailable." >&2
  echo "Run connect-runtime-client.sh interactively; background startup cannot complete OAuth." >&2
  exit 4
fi

if [ -n "$workspace" ]; then
  multica workspace switch "$workspace" --profile "$profile" >/dev/null
fi

if multica daemon status --profile "$profile" >/dev/null 2>&1; then
  multica daemon stop --profile "$profile" >/dev/null 2>&1 || true
fi
multica daemon start --profile "$profile" \
  --device-name "$device_name" \
  --runtime-name "$runtime_name" \
  --max-concurrent-tasks "$max_concurrent_tasks" \
  --agent-timeout "$agent_timeout"

daemon_ready=false
attempt=0
while [ "$attempt" -lt "$timeout_seconds" ]; do
  if [ -n "$workspace" ] && /bin/sh "$(dirname "$0")/verify-runtime-client.sh" "$workspace" "$profile" >/dev/null 2>&1; then
    daemon_ready=true; break
  fi
  attempt=$((attempt + 1)); sleep 1
done
if [ "$daemon_ready" != true ]; then
  echo "Multica did not report an online local runtime in the target workspace." >&2
  exit 5
fi

/bin/sh "$(dirname "$0")/verify-runtime-client.sh" "$workspace" "$profile"
if [ -n "$workspace" ]; then
  echo "Runtime client is online in workspace '$workspace': $device_name / $runtime_name"
else
  echo "Runtime client is online: $device_name / $runtime_name"
fi
