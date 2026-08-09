#!/bin/sh
# Shared macOS/native-Linux Docker-backed Multica self-host server starter.

set -eu

platform=${1:-}
case "$platform" in macos|linux) shift ;; *) echo "First argument must be macos or linux." >&2; exit 2 ;; esac
multica_repo=${1:-"$HOME/multica"}
profile=${2:-home}
published_url=${3:-}
timeout_seconds=${4:-120}
gateway_port=${5:-8787}

kernel=$(uname -s)
case "$platform:$kernel" in
  macos:Darwin) topology=macos-docker-server; cache_topology=macos; log_dir="$HOME/Library/Logs/Multica" ;;
  linux:Linux)
    if [ -n "${WSL_INTEROP:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; then
      echo "WSL is not a native-Linux server host; use the Windows + WSL path." >&2; exit 3
    fi
    topology=linux-docker-server; cache_topology=linux; log_dir="$HOME/.local/state/Multica"
    ;;
  *) echo "Platform '$platform' does not match kernel '$kernel'." >&2; exit 3 ;;
esac

PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.docker/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
umask 077

case "$profile" in *[!A-Za-z0-9._-]*|'') echo "Invalid profile: $profile" >&2; exit 2 ;; esac
case "$published_url" in ''|http://*|https://*) ;; *) echo "Published URL must be http(s)." >&2; exit 2 ;; esac
case "$timeout_seconds" in ''|*[!0-9]*) echo "Invalid timeout." >&2; exit 2 ;; esac
case "$gateway_port" in ''|*[!0-9]*) echo "Invalid gateway port." >&2; exit 2 ;; esac
if [ "$timeout_seconds" -lt 10 ] || [ "$timeout_seconds" -gt 600 ]; then echo "Timeout must be between 10 and 600 seconds." >&2; exit 2; fi
if [ "$gateway_port" -lt 1 ] || [ "$gateway_port" -gt 65535 ]; then echo "Invalid gateway port." >&2; exit 2; fi
test -f "$multica_repo/docker-compose.selfhost.yml" || { echo "Server checkout not found: $multica_repo" >&2; exit 3; }
command -v docker >/dev/null 2>&1 || { echo "Docker CLI is not installed." >&2; exit 4; }
command -v curl >/dev/null 2>&1 || { echo "curl is required for health checks." >&2; exit 4; }
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
caddyfile="$script_dir/../assets/Caddyfile.gateway"
test -f "$caddyfile" || { echo "Gateway config not found: $caddyfile" >&2; exit 3; }
gateway_url="http://127.0.0.1:$gateway_port"
if [ -n "$published_url" ]; then effective_origin=${published_url%/}; else effective_origin=$gateway_url; fi

state_file="$HOME/.multica/selfhost-server/$profile/state.json"
if [ ! -f "$state_file" ]; then
  cache_path=$(/bin/sh "$script_dir/profile-cache.sh" path "$profile")
  onboarding_phase=$(grep -m 1 '^ONBOARDING_PHASE=' "$cache_path" 2>/dev/null || true)
  onboarding_phase=${onboarding_phase#*=}
  case "$onboarding_phase" in
    tailscale-ready|server-ready|owner-registration-required|cluster-finalizing|complete) ;;
    *) echo "Tailscale readiness must be completed before initial server startup." >&2; exit 3 ;;
  esac
fi

set_env_value() {
  key=$1; value=$2; env_file="$multica_repo/.env"; tmp="$env_file.tmp.$$"
  test -f "$env_file" || { echo "Multica .env not found: $env_file" >&2; exit 3; }
  awk -v key="$key" -v value="$value" '
    BEGIN { found=0 }
    index($0, key "=") == 1 && found == 0 { print key "=" value; found=1; next }
    { print }
    END { if (!found) print key "=" value }
  ' "$env_file" >"$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$env_file"
}

if [ ! -f "$multica_repo/.env" ]; then
  test -f "$multica_repo/.env.example" || { echo "Multica .env.example not found." >&2; exit 3; }
  cp "$multica_repo/.env.example" "$multica_repo/.env"
  if command -v openssl >/dev/null 2>&1; then jwt=$(openssl rand -hex 32)
  else jwt=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n'); fi
  [ ${#jwt} -eq 64 ] || { echo "Could not generate JWT_SECRET." >&2; exit 3; }
  set_env_value JWT_SECRET "$jwt"
fi
chmod 600 "$multica_repo/.env"
/bin/sh "$script_dir/profile-cache.sh" set "$profile" \
  "TOPOLOGY=$cache_topology" "SERVER_REPO=$multica_repo" "GATEWAY_PORT=$gateway_port" \
  "PUBLISHED_URL=$published_url" >/dev/null
/bin/sh "$script_dir/apply-admission.sh" "$profile" "$multica_repo" false >/dev/null

compose_host_port() {
  bindings=$(docker compose -f "$multica_repo/docker-compose.selfhost.yml" port "$1" "$2" 2>/dev/null) || bindings=
  [ -n "$bindings" ] || return 1
  printf '%s\n' "$bindings" | while IFS= read -r binding; do
    case "$binding" in 127.0.0.1:*|'[::1]':*) ;; *) echo "Unsafe host binding for $1/$2: $binding" >&2; exit 9 ;; esac
  done || exit $?
  published=$(printf '%s\n' "$bindings" | tail -n 1)
  published=${published##*:}; published=$(printf '%s' "$published" | tr -d '\r')
  case "$published" in ''|0|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$published"
}

assert_not_published() {
  bindings=$(docker compose -f "$multica_repo/docker-compose.selfhost.yml" port "$1" "$2" 2>/dev/null || true)
  [ -z "$bindings" ] || { echo "$1/$2 must not be published on the host." >&2; exit 9; }
}

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

start_gateway() {
  backend_container=$(docker compose -f "$multica_repo/docker-compose.selfhost.yml" ps -q backend)
  case "$backend_container" in ''|*[!a-f0-9]*) echo "Could not resolve backend container." >&2; exit 7 ;; esac
  network_names=$(docker inspect --format '{{range $name, $network := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$backend_container" | sed '/^[[:space:]]*$/d')
  network_count=$(printf '%s\n' "$network_names" | awk 'NF { count++ } END { print count + 0 }')
  [ "$network_count" -eq 1 ] || { echo "Expected one backend network, found $network_count." >&2; exit 7; }
  network_name=$network_names
  case "$network_name" in *[!A-Za-z0-9_.-]*) echo "Unsafe backend network name." >&2; exit 7 ;; esac
  gateway_container="multica-$profile-gateway"
  if docker inspect "$gateway_container" >/dev/null 2>&1; then docker rm -f "$gateway_container" >/dev/null; fi
  docker run -d --name "$gateway_container" --restart unless-stopped \
    --network "$network_name" \
    -p "127.0.0.1:$gateway_port:$gateway_port" \
    -e "MULTICA_GATEWAY_PORT=$gateway_port" \
    -v "$caddyfile:/etc/caddy/Caddyfile:ro" \
    caddy:2-alpine >/dev/null
}

write_state() {
  backend_port=$1; frontend_port=$2; database_host_port=$3
  state_dir="$HOME/.multica/selfhost-server/$profile"
  mkdir -p "$state_dir"
  local_backend_url="http://127.0.0.1:$backend_port"
  local_frontend_url="http://127.0.0.1:$frontend_port"
  connection_server_url=$effective_origin; connection_app_url=$effective_origin; same_origin=true
  if [ -n "$published_url" ]; then access_scope=published-private; else access_scope=local-only; fi
  if [ -n "$database_host_port" ]; then db_published=true; db_port=$database_host_port
  else db_published=false; db_port=null; fi
  updated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  state_tmp="$state_dir/state.json.tmp.$$"
  receipt_tmp="$state_dir/connection.json.tmp.$$"
  cat >"$state_tmp" <<EOF
{
  "schema_version": 1,
  "profile": "$(json_escape "$profile")",
  "topology": "$topology",
  "backend": {"url": "$local_backend_url", "host_port": $backend_port, "container_port": 8080},
  "frontend": {"url": "$local_frontend_url", "host_port": $frontend_port, "container_port": 3000},
  "gateway": {"url": "$gateway_url", "host_port": $gateway_port, "container_image": "caddy:2-alpine"},
  "database": {"engine": "postgresql", "container_host": "postgres", "container_port": 5432, "host_published": $db_published, "host_port": $db_port},
  "server_repo": "$(json_escape "$multica_repo")",
  "published_url": "$(json_escape "$published_url")",
  "identity_model": "individual-members",
  "admission_policy": "server-env-and-workspace-invite",
  "updated_at": "$updated_at"
}
EOF
  cat >"$receipt_tmp" <<EOF
{
  "schema_version": 1,
  "profile": "$(json_escape "$profile")",
  "server_url": "$(json_escape "$connection_server_url")",
  "app_url": "$(json_escape "$connection_app_url")",
  "same_origin": $same_origin,
  "access_scope": "$access_scope",
  "identity_model": "individual-members",
  "admission_policy": "server-env-and-workspace-invite",
  "server_device": "$(json_escape "$(hostname)")",
  "updated_at": "$updated_at"
}
EOF
  chmod 600 "$state_tmp" "$receipt_tmp"
  mv -f "$state_tmp" "$state_dir/state.json"
  mv -f "$receipt_tmp" "$state_dir/connection.json"
  cat "$state_dir/connection.json"
}

mkdir -p "$log_dir"
exec >>"$log_dir/selfhost-server-$profile.log" 2>&1
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Starting Multica self-host server on $platform..."

if ! docker info >/dev/null 2>&1 && [ "$platform" = macos ] && [ -d /Applications/Docker.app ]; then
  /usr/bin/open -g -a Docker
fi
attempt=0
while [ "$attempt" -lt "$timeout_seconds" ]; do
  docker info >/dev/null 2>&1 && break
  attempt=$((attempt + 1)); sleep 1
done
docker info >/dev/null 2>&1 || { echo "Docker did not become ready." >&2; exit 5; }
set_env_value FRONTEND_ORIGIN "$effective_origin"
set_env_value MULTICA_APP_URL "$effective_origin"
set_env_value CORS_ALLOWED_ORIGINS "$effective_origin"
set_env_value COOKIE_DOMAIN ""
set_env_value NEXT_PUBLIC_API_URL ""
set_env_value NEXT_PUBLIC_WS_URL ""
docker compose -f "$multica_repo/docker-compose.selfhost.yml" up -d

backend_port=$(compose_host_port backend 8080)
frontend_port=$(compose_host_port frontend 3000)
assert_not_published postgres 5432
database_host_port=
start_gateway
ready_url="http://127.0.0.1:$backend_port/readyz"
attempt=0
while [ "$attempt" -lt "$timeout_seconds" ]; do
  curl -fsS "$ready_url" >/dev/null 2>&1 && break
  attempt=$((attempt + 1)); sleep 1
done
curl -fsS "$ready_url" >/dev/null 2>&1 || { echo "Backend did not become ready." >&2; exit 6; }
attempt=0
while [ "$attempt" -lt "$timeout_seconds" ]; do
  curl -fsS "$gateway_url/api/config" >/dev/null 2>&1 && break
  attempt=$((attempt + 1)); sleep 1
done
curl -fsS "$gateway_url/api/config" >/dev/null 2>&1 || { echo "Gateway did not become ready." >&2; exit 7; }
write_state "$backend_port" "$frontend_port" "$database_host_port"
echo "Multica self-host server is ready."
