#!/bin/sh
# Open the first-owner Web UI on macOS/native Linux and return at the identity boundary.

set -eu

app_url=${1:-}
owner_email=${2:-}
profile=${3:-home}
no_open=${4:-false}
newline='
'
carriage=$(printf '\r')
case "$app_url" in *"$newline"*|*"$carriage"*) echo "App URL cannot contain control characters." >&2; exit 2 ;; esac
case "$app_url" in http://*|https://*) ;; *) echo "App URL must be absolute http(s)." >&2; exit 2 ;; esac
case "$app_url" in *'@'*) echo "App URL cannot embed credentials." >&2; exit 2 ;; esac
printf '%s\n' "$owner_email" | awk '/^[^[:space:]@,]+@[^[:space:]@,]+\.[^[:space:]@,]+$/ {ok=1} END {exit(ok ? 0 : 1)}' || {
  echo "Invalid owner email." >&2; exit 2;
}
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
case "$no_open" in true|false) ;; *) echo "Fourth argument must be true or false." >&2; exit 2 ;; esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
/bin/sh "$script_dir/profile-cache.sh" set "$profile" \
  "OWNER_EMAIL=$owner_email" "ONBOARDING_PHASE=owner-registration-required" >/dev/null
cache_path=$(/bin/sh "$script_dir/profile-cache.sh" path "$profile")
workspace=$(grep -m 1 '^WORKSPACE_SLUG=' "$cache_path" 2>/dev/null || true)
workspace=${workspace#*=}
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

if [ "$no_open" = false ]; then
  case "$(uname -s)" in
    Darwin) /usr/bin/open "$app_url" ;;
    Linux)
      if [ -n "${WSL_INTEROP:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; then
        echo "WSL must use the Windows owner-registration opener." >&2; exit 3
      fi
      command -v xdg-open >/dev/null 2>&1 || { echo "xdg-open is required." >&2; exit 4; }
      xdg-open "$app_url" >/dev/null 2>&1
      ;;
    *) echo "Unsupported platform." >&2; exit 3 ;;
  esac
fi
printf '{"schema_version":1,"status":"manual_action_required","action":"owner_registration","phase":"owner-registration-required","app_url":"%s","owner_email":"%s","workspace":"%s","instructions":["在已打开的 WebUI 中使用 owner 邮箱完成注册或登录，并创建缓存中的 workspace。","只需亲自完成浏览器、邮箱或 OAuth 身份验证；不要执行命令。","进入 workspace 后再次调用 $multica-selfhost-server，并说“继续完成首个 runtime”。"]}\n' \
  "$(json_escape "${app_url%/}")" "$(json_escape "$owner_email")" "$(json_escape "$workspace")"
