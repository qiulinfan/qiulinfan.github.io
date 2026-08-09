#!/bin/sh
# Write a non-secret client onboarding receipt for one invited member.

set -eu

member_email=${1:-}
access_mode=${2:-}
access_status=${3:-pending}
invitation_status=${4:-pending}
profile=${5:-home}
printf '%s\n' "$member_email" | awk '/^[^[:space:]@,]+@[^[:space:]@,]+\.[^[:space:]@,]+$/ {ok=1} END {exit(ok?0:1)}' || { echo "Invalid member email." >&2; exit 2; }
case "$access_mode" in same-tailnet|shared-machine) ;; *) echo "Invalid Tailscale access mode." >&2; exit 2 ;; esac
case "$access_status" in pending|accepted|reachable) ;; *) echo "Invalid Tailscale access status." >&2; exit 2 ;; esac
case "$invitation_status" in pending|accepted) ;; *) echo "Invalid Multica invitation status." >&2; exit 2 ;; esac
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile." >&2; exit 2 ;; esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cache_path=$(/bin/sh "$script_dir/profile-cache.sh" path "$profile")
cache_value() { line=$(grep -m 1 "^$1=" "$cache_path" 2>/dev/null || true); printf '%s\n' "${line#*=}"; }
server_url=$(cache_value PUBLISHED_URL)
workspace=$(cache_value WORKSPACE_SLUG)
case "$server_url" in https://*.ts.net) ;; *) echo "A published Tailscale URL is required." >&2; exit 3 ;; esac
case "$workspace" in ''|*[!A-Za-z0-9._-]*) echo "A safe workspace slug is required." >&2; exit 3 ;; esac

directory="$HOME/.multica/selfhost-server/$profile/handoffs"
mkdir -p "$directory"; chmod 700 "$directory"
safe_name=$(printf '%s' "$member_email" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/_/g')
path="$directory/$safe_name.json"
tmp="$path.tmp.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
updated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat >"$tmp" <<EOF
{"schema_version":1,"server_url":"$server_url","app_url":"$server_url","workspace":"$workspace","member_email":"$member_email","tailscale_access_mode":"$access_mode","tailscale_access_status":"$access_status","multica_invitation_status":"$invitation_status","contains_credentials":false,"updated_at":"$updated_at"}
EOF
chmod 600 "$tmp"; mv -f "$tmp" "$path"; trap - EXIT HUP INT TERM
cat "$path"
