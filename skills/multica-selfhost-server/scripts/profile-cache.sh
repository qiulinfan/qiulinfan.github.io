#!/bin/sh
# Manage the git-ignored, non-secret local profile cache for this Skill.

set -eu

action=${1:-show}
profile=${2:-home}
if [ "$#" -ge 2 ]; then shift 2; else shift "$#"; fi
case "$action" in show|set|path) ;; *) echo "Use: $0 show|set|path PROFILE [KEY=VALUE ...]" >&2; exit 2 ;; esac
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
skill_root=$(CDPATH= cd "$script_dir/.." && pwd)
ignore_path="$skill_root/.gitignore"
test -f "$ignore_path" && grep -qx '\.cache/' "$ignore_path" || {
  echo "Refusing to write cache until $ignore_path ignores .cache/." >&2; exit 3;
}
cache_dir="$skill_root/.cache/$profile"
cache_path="$cache_dir/profile.env"

allowed_key() {
  case "$1" in
    TOPOLOGY|WSL_DISTRO|LINUX_REPO|SERVER_REPO|GATEWAY_PORT|PUBLISHED_URL|OWNER_EMAIL|ALLOWED_EMAILS|INVITED_EMAILS|ACCEPTED_EMAILS|ALLOW_SIGNUP|DISABLE_WORKSPACE_CREATION|ONBOARDING_PHASE|WORKSPACE_NAME|WORKSPACE_SLUG|ISSUE_PREFIX|DEVICE_NAME|RUNTIME_NAME|MAX_CONCURRENT_TASKS|TAILSCALE_SERVE_APPROVED|WORKSPACE_AGENT_ACCESS_APPROVED|SERVER_AUTOSTART_APPROVED|RUNTIME_AUTOSTART_APPROVED) return 0 ;;
    *) return 1 ;;
  esac
}

validate_value() {
  key=$1; value=$2
  newline='
'
  carriage=$(printf '\r')
  case "$value" in *"$newline"*|*"$carriage"*) echo "$key cannot contain newlines." >&2; return 1 ;; esac
  if printf '%s\n' "$value" | grep -Eiq '(^|[?;&[:space:]])(token|pat|password|cookie|api[_-]?key|secret)=|(sk-|ghp_|pat_)[A-Za-z0-9_-]{12,}'; then
    echo "$key looks like it contains a credential; Skill cache rejected it." >&2; return 1
  fi
  case "$key" in
    TOPOLOGY)
      case "$value" in windows-wsl|windows-native|macos|linux) ;; *) echo "Invalid TOPOLOGY." >&2; return 1 ;; esac ;;
    ONBOARDING_PHASE)
      case "$value" in tailscale-action-required|tailscale-ready|server-ready|owner-registration-required|cluster-finalizing|complete) ;;
        *) echo "Invalid ONBOARDING_PHASE." >&2; return 1 ;;
      esac ;;
    OWNER_EMAIL)
      printf '%s\n' "$value" | awk '/^[^[:space:]@,]+@[^[:space:]@,]+\.[^[:space:]@,]+$/ {ok=1} END {exit(ok ? 0 : 1)}' || {
        echo "Invalid OWNER_EMAIL." >&2; return 1;
      } ;;
    ALLOWED_EMAILS|INVITED_EMAILS|ACCEPTED_EMAILS)
      if [ "$key" != ALLOWED_EMAILS ] && [ -z "$value" ]; then return 0; fi
      printf '%s\n' "$value" | awk -F, 'NF > 0 { for (i=1;i<=NF;i++) if ($i !~ /^[^[:space:]@,]+@[^[:space:]@,]+\.[^[:space:]@,]+$/) exit 1; ok=1 } END { exit(ok ? 0 : 1) }' || {
        echo "Invalid $key." >&2; return 1;
      } ;;
    PUBLISHED_URL)
      if [ -n "$value" ]; then
        case "$value" in http://*|https://*) ;; *) echo "PUBLISHED_URL must be absolute http(s)." >&2; return 1 ;; esac
        authority=${value#*://}; authority=${authority%%/*}
        case "$authority" in *@*) echo "PUBLISHED_URL cannot embed credentials." >&2; return 1 ;; esac
      fi ;;
    ALLOW_SIGNUP|DISABLE_WORKSPACE_CREATION|TAILSCALE_SERVE_APPROVED|WORKSPACE_AGENT_ACCESS_APPROVED|SERVER_AUTOSTART_APPROVED|RUNTIME_AUTOSTART_APPROVED)
      case "$value" in true|false) ;; *) echo "$key must be true or false." >&2; return 1 ;; esac ;;
    GATEWAY_PORT)
      case "$value" in ''|*[!0-9]*) echo "Invalid GATEWAY_PORT." >&2; return 1 ;; esac
      [ "$value" -ge 1 ] && [ "$value" -le 65535 ] || { echo "Invalid GATEWAY_PORT." >&2; return 1; } ;;
    MAX_CONCURRENT_TASKS)
      case "$value" in ''|*[!0-9]*) echo "Invalid MAX_CONCURRENT_TASKS." >&2; return 1 ;; esac
      [ "$value" -ge 1 ] && [ "$value" -le 50 ] || { echo "Invalid MAX_CONCURRENT_TASKS." >&2; return 1; } ;;
  esac
}

set_line() {
  file=$1; key=$2; value=$3; next="$file.next"
  awk -v key="$key" -v value="$value" '
    BEGIN { found=0 }
    index($0, key "=") == 1 && found == 0 { print key "=" value; found=1; next }
    { print }
    END { if (!found) print key "=" value }
  ' "$file" >"$next"
  mv -f "$next" "$file"
}

case "$action" in
  path) printf '%s\n' "$cache_path" ;;
  show)
    printf 'CACHE_PATH=%s\nCACHE_EXISTS=%s\n' "$cache_path" "$(test -f "$cache_path" && echo true || echo false)"
    test ! -f "$cache_path" || grep -v '^PROVIDER=' "$cache_path"
    ;;
  set)
    [ "$#" -gt 0 ] || { echo "Pass one or more KEY=VALUE entries." >&2; exit 2; }
    mkdir -p "$cache_dir"
    chmod 700 "$cache_dir"
    tmp="$cache_path.tmp.$$"
    if [ -f "$cache_path" ]; then grep -v '^PROVIDER=' "$cache_path" >"$tmp"; else : >"$tmp"; fi
    trap 'rm -f "$tmp" "$tmp.next"' EXIT HUP INT TERM
    for entry in "$@"; do
      key=${entry%%=*}
      [ "$entry" != "$key" ] || { echo "Entry must use KEY=VALUE: $entry" >&2; exit 2; }
      key=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')
      value=${entry#*=}
      allowed_key "$key" || { echo "Cache key is not allowed: $key" >&2; exit 2; }
      validate_value "$key" "$value"
      set_line "$tmp" "$key" "$value"
    done
    set_line "$tmp" CACHE_SCHEMA_VERSION 1
    set_line "$tmp" PROFILE "$profile"
    set_line "$tmp" UPDATED_AT "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    chmod 600 "$tmp"
    mv -f "$tmp" "$cache_path"
    trap - EXIT HUP INT TERM
    "$0" show "$profile"
    ;;
esac
