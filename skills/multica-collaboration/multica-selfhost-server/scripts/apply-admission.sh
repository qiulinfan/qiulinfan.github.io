#!/bin/sh
# Apply cached signup and workspace-creation policy to a Multica server checkout.

set -eu

profile=${1:-home}
server_repo=${2:-}
recreate=${3:-false}
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cache_path=$(/bin/sh "$script_dir/profile-cache.sh" path "$profile")
test -f "$cache_path" || { echo "No cached server profile exists for '$profile'." >&2; exit 3; }

cache_value() {
  key=$1
  line=$(grep -m 1 "^$key=" "$cache_path" || true)
  printf '%s\n' "${line#*=}"
}

allowed_emails=$(cache_value ALLOWED_EMAILS)
owner_email=$(cache_value OWNER_EMAIL)
allow_signup=$(cache_value ALLOW_SIGNUP)
disable_workspace_creation=$(cache_value DISABLE_WORKSPACE_CREATION)
[ -n "$allowed_emails" ] || { echo "Cached ALLOWED_EMAILS is required." >&2; exit 3; }
[ -n "$allow_signup" ] || allow_signup=true
[ -n "$disable_workspace_creation" ] || disable_workspace_creation=false
if [ -n "$owner_email" ]; then
  case ",$allowed_emails," in *",$owner_email,"*) ;; *) echo "OWNER_EMAIL must also appear in ALLOWED_EMAILS." >&2; exit 3 ;; esac
fi
if [ -z "$server_repo" ]; then server_repo=$(cache_value SERVER_REPO); fi
test -f "$server_repo/docker-compose.selfhost.yml" || { echo "Invalid server checkout: $server_repo" >&2; exit 3; }
env_file="$server_repo/.env"
test -f "$env_file" || { echo "Multica .env not found: $env_file" >&2; exit 3; }

set_env_value() {
  key=$1; value=$2; tmp="$env_file.tmp.$$"
  awk -v key="$key" -v value="$value" '
    BEGIN { found=0 }
    index($0, key "=") == 1 && found == 0 { print key "=" value; found=1; next }
    { print }
    END { if (!found) print key "=" value }
  ' "$env_file" >"$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$env_file"
}

set_env_value ALLOW_SIGNUP "$allow_signup"
set_env_value ALLOWED_EMAILS "$allowed_emails"
set_env_value DISABLE_WORKSPACE_CREATION "$disable_workspace_creation"

case "$recreate" in
  true|--recreate)
    docker compose -f "$server_repo/docker-compose.selfhost.yml" up -d
    recreated=true
    ;;
  false|'') recreated=false ;;
  *) echo "Third argument must be true, false, or --recreate." >&2; exit 2 ;;
esac

printf 'PROFILE=%s\nALLOWED_EMAIL_COUNT=%s\nALLOW_SIGNUP=%s\nDISABLE_WORKSPACE_CREATION=%s\nRECREATED=%s\n' \
  "$profile" "$(printf '%s' "$allowed_emails" | awk -F, '{print NF}')" "$allow_signup" \
  "$disable_workspace_creation" "$recreated"
