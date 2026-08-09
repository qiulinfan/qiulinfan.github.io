#!/bin/sh
# Correlate the selected workspace, local daemon, and Multica-detected online runtimes.

set -eu

workspace=${1:-}
profile=${2:-remote}
[ -n "$workspace" ] || { echo "Workspace is required." >&2; exit 2; }
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
multica_bin=${MULTICA_BIN:-multica}
if [ -x "$multica_bin" ]; then :
elif command -v "$multica_bin" >/dev/null 2>&1; then multica_bin=$(command -v "$multica_bin")
else echo "Multica CLI is unavailable." >&2; exit 3; fi

workspace_json=$("$multica_bin" workspace get "$workspace" --profile "$profile" --output json)
workspace_id=$(printf '%s\n' "$workspace_json" | sed -n 's/^[[:space:]]*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
workspace_slug=$(printf '%s\n' "$workspace_json" | sed -n 's/^[[:space:]]*"slug"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$workspace_id" ] || { echo "Could not resolve target workspace." >&2; exit 4; }

daemon_json=$("$multica_bin" daemon status --profile "$profile" --output json)
daemon_status=$(printf '%s\n' "$daemon_json" | sed -n 's/^[[:space:]]*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
daemon_id=$(printf '%s\n' "$daemon_json" | sed -n 's/^[[:space:]]*"daemon_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
[ "$daemon_status" = running ] && [ -n "$daemon_id" ] || { echo "The local daemon is not running." >&2; exit 5; }

runtime_ids=$(printf '%s\n' "$daemon_json" | awk -v wanted="$workspace_id" '
  /^[[:space:]]*"id"[[:space:]]*:/ {
    value=$0; sub(/^[^"]*"id"[[:space:]]*:[[:space:]]*"/, "", value); sub(/".*/, "", value)
    in_workspace=(value == wanted); in_runtimes=0; next
  }
  in_workspace && /"runtimes"[[:space:]]*:[[:space:]]*\[/ { in_runtimes=1; next }
  in_workspace && in_runtimes && /"[0-9a-fA-F-]+"/ {
    value=$0; sub(/^[^"]*"/, "", value); sub(/".*/, "", value); print value; next
  }
  in_workspace && in_runtimes && /\]/ { exit }
')
[ -n "$runtime_ids" ] || { echo "The local daemon has no runtimes in the target workspace." >&2; exit 6; }

runtime_json=$("$multica_bin" runtime list --profile "$profile" --output json)
runtime_ids_csv=$(printf '%s\n' "$runtime_ids" | paste -sd, -)
online_ids=$(printf '%s\n' "$runtime_json" | awk -v daemon="$daemon_id" -v workspace="$workspace_id" -v allowed="$runtime_ids_csv" '
  BEGIN { n=split(allowed, ids, ","); for(i=1;i<=n;i++) okid[ids[i]]=1 }
  /^  \{/ { id=""; daemon_id=""; workspace_id=""; status=""; next }
  /^    "id"[[:space:]]*:/ { value=$0; sub(/^[^"]*"id"[[:space:]]*:[[:space:]]*"/, "", value); sub(/".*/, "", value); id=value; next }
  /^    "daemon_id"[[:space:]]*:/ { value=$0; sub(/^[^"]*"daemon_id"[[:space:]]*:[[:space:]]*"/, "", value); sub(/".*/, "", value); daemon_id=value; next }
  /^    "workspace_id"[[:space:]]*:/ { value=$0; sub(/^[^"]*"workspace_id"[[:space:]]*:[[:space:]]*"/, "", value); sub(/".*/, "", value); workspace_id=value; next }
  /^    "status"[[:space:]]*:/ { value=$0; sub(/^[^"]*"status"[[:space:]]*:[[:space:]]*"/, "", value); sub(/".*/, "", value); status=value; next }
  /^  \}/ { if(okid[id] && daemon_id==daemon && workspace_id==workspace && status=="online") print id }
')
[ -n "$online_ids" ] || { echo "No Multica-detected local runtime is online in the target workspace." >&2; exit 7; }
runtime_count=$(printf '%s\n' "$online_ids" | awk 'NF { n++ } END { print n+0 }')
runtime_json_array=$(printf '%s\n' "$online_ids" | awk 'BEGIN{printf "["} NF{if(n++)printf ","; printf "\"%s\"",$0} END{printf "]"}')
printf '{"schema_version":1,"status":"ready","workspace_id":"%s","workspace_slug":"%s","daemon_id":"%s","runtime_ids":%s,"runtime_count":%s}\n' \
  "$workspace_id" "$workspace_slug" "$daemon_id" "$runtime_json_array" "$runtime_count"
