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
    SERVER_URL|APP_URL|WORKSPACE|IDENTITY_EMAIL|INVITATION_STATUS|PLATFORM|DEVICE_NAME|RUNTIME_NAME|MAX_CONCURRENT_TASKS|TAILSCALE_ACCESS_MODE|TAILSCALE_ACCESS_STATUS|AGENT_TIMEOUT|WORKSPACE_AGENT_ACCESS_APPROVED|AUTOSTART_APPROVED) return 0 ;;
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
    IDENTITY_EMAIL)
      printf '%s\n' "$value" | awk '/^[^[:space:]@,]+@[^[:space:]@,]+\.[^[:space:]@,]+$/ {ok=1} END {exit(ok ? 0 : 1)}' || {
        echo "Invalid IDENTITY_EMAIL." >&2; return 1;
      } ;;
    SERVER_URL|APP_URL)
      case "$value" in http://*|https://*) ;; *) echo "$key must be absolute http(s)." >&2; return 1 ;; esac
      authority=${value#*://}; authority=${authority%%/*}
      case "$authority" in *@*) echo "$key cannot embed credentials." >&2; return 1 ;; esac ;;
    INVITATION_STATUS)
      case "$value" in unknown|pending|accepted) ;; *) echo "Invalid INVITATION_STATUS." >&2; return 1 ;; esac ;;
    PLATFORM)
      case "$value" in windows|macos|linux) ;; *) echo "Invalid PLATFORM." >&2; return 1 ;; esac ;;
    TAILSCALE_ACCESS_MODE)
      case "$value" in same-tailnet|shared-machine) ;; *) echo "Invalid TAILSCALE_ACCESS_MODE." >&2; return 1 ;; esac ;;
    TAILSCALE_ACCESS_STATUS)
      case "$value" in unknown|pending|accepted|reachable) ;; *) echo "Invalid TAILSCALE_ACCESS_STATUS." >&2; return 1 ;; esac ;;
    WORKSPACE_AGENT_ACCESS_APPROVED|AUTOSTART_APPROVED)
      case "$value" in true|false) ;; *) echo "$key must be true or false." >&2; return 1 ;; esac ;;
    MAX_CONCURRENT_TASKS)
      case "$value" in ''|*[!0-9]*) echo "Invalid MAX_CONCURRENT_TASKS." >&2; return 1 ;; esac
      [ "$value" -ge 1 ] && [ "$value" -le 50 ] || { echo "Invalid MAX_CONCURRENT_TASKS." >&2; return 1; } ;;
    AGENT_TIMEOUT)
      case "$value" in
        0|0s) ;;
        *ms) timeout_value=${value%ms}; case "$timeout_value" in ''|*[!0-9]*) echo "Invalid AGENT_TIMEOUT." >&2; return 1 ;; esac ;;
        *s|*m|*h) timeout_value=${value%?}; case "$timeout_value" in ''|*[!0-9]*) echo "Invalid AGENT_TIMEOUT." >&2; return 1 ;; esac ;;
        *) echo "Invalid AGENT_TIMEOUT." >&2; return 1 ;;
      esac ;;
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
