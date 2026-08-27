#!/bin/sh
# Stop a Docker-backed Multica server without removing containers, volumes, or Tailscale Serve.

set -eu

server_repo=${1:-}
profile=${2:-home}
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
test -n "$server_repo" || { echo "Server repository is required." >&2; exit 2; }
test -f "$server_repo/docker-compose.selfhost.yml" || { echo "Invalid server checkout: $server_repo" >&2; exit 3; }
command -v docker >/dev/null 2>&1 || { echo "Docker CLI is required." >&2; exit 4; }
docker info >/dev/null 2>&1 || { echo "Docker engine is not running." >&2; exit 4; }

server_repo=$(CDPATH= cd "$server_repo" && pwd)
compose_file="$server_repo/docker-compose.selfhost.yml"
gateway_container="multica-$profile-gateway"
state_dir="$HOME/.multica/selfhost-server/$profile"
receipt_path="$state_dir/stop.json"
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

if docker inspect "$gateway_container" >/dev/null 2>&1; then
  docker stop "$gateway_container" >/dev/null
fi
docker compose -f "$compose_file" stop

running=$(docker compose -f "$compose_file" ps -q)
[ -z "$running" ] || { echo "Compose services are still running after stop." >&2; exit 5; }
if docker inspect "$gateway_container" >/dev/null 2>&1; then
  gateway_running=$(docker inspect --format '{{.State.Running}}' "$gateway_container")
  [ "$gateway_running" = false ] || { echo "Gateway is still running after stop." >&2; exit 5; }
fi

mkdir -p "$state_dir"
stopped_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
receipt_tmp="$receipt_path.tmp.$$"
cat >"$receipt_tmp" <<EOF
{
  "schema_version": 1,
  "status": "stopped",
  "profile": "$(json_escape "$profile")",
  "server_repo": "$(json_escape "$server_repo")",
  "containers_preserved": true,
  "volumes_preserved": true,
  "tailscale_serve_preserved": true,
  "autostart_definition_preserved": true,
  "stopped_at": "$stopped_at"
}
EOF
chmod 600 "$receipt_tmp"
mv -f "$receipt_tmp" "$receipt_path"
cat "$receipt_path"
