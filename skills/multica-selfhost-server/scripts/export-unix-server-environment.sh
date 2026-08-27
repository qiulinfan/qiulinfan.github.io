#!/bin/sh
# Export a stopped Multica server as one recipient-encrypted, restoreable environment archive.

set -eu

server_repo=${1:-}
profile=${2:-home}
output_root=${3:-}
age_recipient=${4:-}
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
test -n "$server_repo" || { echo "Server repository is required." >&2; exit 2; }
test -n "$output_root" || { echo "Output root is required." >&2; exit 2; }
test -n "$age_recipient" || { echo "An age recipient is required." >&2; exit 2; }
case "$output_root" in /*) ;; *) echo "Output root must be an absolute path." >&2; exit 2 ;; esac
test -f "$server_repo/docker-compose.selfhost.yml" || { echo "Invalid server checkout: $server_repo" >&2; exit 3; }
test -f "$server_repo/.env" || { echo "Multica .env is required for export." >&2; exit 3; }
for command_name in age docker git tar sed awk find; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "$command_name is required." >&2; exit 4; }
done
docker info >/dev/null 2>&1 || { echo "Docker engine is not running." >&2; exit 4; }

server_repo=$(CDPATH= cd "$server_repo" && pwd)
mkdir -p "$output_root"
output_root=$(CDPATH= cd "$output_root" && pwd)
case "$output_root/" in "$server_repo/"*) echo "Export output must be outside the server checkout." >&2; exit 3 ;; esac
compose_file="$server_repo/docker-compose.selfhost.yml"
gateway_container="multica-$profile-gateway"
stop_receipt="$HOME/.multica/selfhost-server/$profile/stop.json"
test -f "$stop_receipt" && grep -q '"status": "stopped"' "$stop_receipt" || {
  echo "A completed stop receipt is required before export." >&2; exit 5;
}

for service in backend frontend; do
  service_running=$(docker compose -f "$compose_file" ps -q "$service")
  [ -z "$service_running" ] || { echo "Stop the server before export; $service is still running." >&2; exit 5; }
done
if docker inspect "$gateway_container" >/dev/null 2>&1; then
  gateway_running=$(docker inspect --format '{{.State.Running}}' "$gateway_container")
  [ "$gateway_running" = false ] || { echo "Stop the server before export; gateway is still running." >&2; exit 5; }
fi

postgres_container=$(docker compose -f "$compose_file" ps -aq postgres)
backend_container=$(docker compose -f "$compose_file" ps -aq backend)
case "$postgres_container:$backend_container" in *[!a-f0-9:]*) echo "Could not resolve stopped server containers." >&2; exit 5 ;; esac
[ -n "$postgres_container" ] && [ -n "$backend_container" ] || { echo "Stopped postgres and backend containers are required." >&2; exit 5; }

stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/multica-export.XXXXXX")
postgres_started=false
archive_partial=
cleanup() {
  result=$?
  trap - EXIT HUP INT TERM
  if [ "$postgres_started" = true ]; then docker compose -f "$compose_file" stop postgres >/dev/null 2>&1 || true; fi
  if [ -n "$archive_partial" ] && [ -f "$archive_partial" ]; then unlink "$archive_partial" 2>/dev/null || true; fi
  if [ -d "$stage_dir" ]; then find "$stage_dir" -depth -mindepth 1 -delete 2>/dev/null || true; rmdir "$stage_dir" 2>/dev/null || true; fi
  exit "$result"
}
trap cleanup EXIT HUP INT TERM
umask 077

docker compose -f "$compose_file" up -d postgres >/dev/null
postgres_started=true
attempt=0
while [ "$attempt" -lt 120 ]; do
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$postgres_container" 2>/dev/null || true)
  [ "$health" = healthy ] && break
  attempt=$((attempt + 1)); sleep 1
done
[ "${health:-}" = healthy ] || { echo "PostgreSQL did not become healthy for export." >&2; exit 6; }

docker exec "$postgres_container" sh -eu -c \
  'exec pg_dump -U "${POSTGRES_USER:-multica}" -d "${POSTGRES_DB:-multica}" --format=custom --no-owner --no-privileges' \
  >"$stage_dir/database.dump"
test -s "$stage_dir/database.dump" || { echo "PostgreSQL dump is empty." >&2; exit 6; }

mkdir -p "$stage_dir/uploads"
docker cp "$backend_container:/app/data/uploads/." "$stage_dir/uploads"
tar -C "$stage_dir/uploads" -czf "$stage_dir/backend_uploads.tar.gz" .
cp "$server_repo/.env" "$stage_dir/server.env"
chmod 600 "$stage_dir/server.env"
cp "$compose_file" "$stage_dir/docker-compose.selfhost.yml"

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cache_path=$(/bin/sh "$script_dir/profile-cache.sh" path "$profile")
test ! -f "$cache_path" || cp "$cache_path" "$stage_dir/profile.env"
state_dir="$HOME/.multica/selfhost-server/$profile"
test ! -f "$state_dir/state.json" || cp "$state_dir/state.json" "$stage_dir/state.json"
test ! -f "$state_dir/connection.json" || cp "$state_dir/connection.json" "$stage_dir/connection.json"

commit=$(git -C "$server_repo" rev-parse HEAD)
origin=$(git -C "$server_repo" remote get-url origin)
case "$origin" in https://github.com/multica-ai/multica.git|git@github.com:multica-ai/multica.git) ;;
  *) echo "Unexpected Multica origin: $origin" >&2; exit 6 ;;
esac
created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
cat >"$stage_dir/manifest.json" <<EOF
{
  "schema_version": 1,
  "archive_type": "multica-server-environment-v1",
  "profile": "$(json_escape "$profile")",
  "source_repo": "$(json_escape "$origin")",
  "source_commit": "$(json_escape "$commit")",
  "consistent_while_application_stopped": true,
  "outer_archive_encrypted": true,
  "created_at": "$created_at"
}
EOF

for service in postgres backend frontend; do
  container=$(docker compose -f "$compose_file" ps -aq "$service")
  image_ref=$(docker inspect --format '{{.Config.Image}}' "$container")
  image_id=$(docker inspect --format '{{.Image}}' "$container")
  repo_digests=$(docker image inspect --format '{{join .RepoDigests ","}}' "$image_ref" 2>/dev/null || true)
  printf '%s|%s|%s|%s\n' "$service" "$image_ref" "$image_id" "$repo_digests"
done >"$stage_dir/images.txt"
if docker inspect "$gateway_container" >/dev/null 2>&1; then
  image_ref=$(docker inspect --format '{{.Config.Image}}' "$gateway_container")
  image_id=$(docker inspect --format '{{.Image}}' "$gateway_container")
  repo_digests=$(docker image inspect --format '{{join .RepoDigests ","}}' "$image_ref" 2>/dev/null || true)
  printf '%s|%s|%s|%s\n' gateway "$image_ref" "$image_id" "$repo_digests" >>"$stage_dir/images.txt"
fi

hash_command=sha256sum
command -v sha256sum >/dev/null 2>&1 || hash_command='shasum -a 256'
(
  cd "$stage_dir"
  for file in database.dump backend_uploads.tar.gz server.env docker-compose.selfhost.yml manifest.json images.txt profile.env state.json connection.json; do
    test ! -f "$file" || $hash_command "$file"
  done >SHA256SUMS
)

archive_path="$output_root/multica-server-$profile-$timestamp.tar.age"
archive_partial="$archive_path.partial.$$"
receipt_path="$archive_path.receipt.json"
test ! -e "$archive_path" && test ! -e "$archive_partial" || { echo "Export target already exists." >&2; exit 7; }
tar -C "$stage_dir" -cf - . | age -r "$age_recipient" -o "$archive_partial"
chmod 600 "$archive_partial"
mv "$archive_partial" "$archive_path"
archive_partial=

archive_sha=$($hash_command "$archive_path" | awk '{print $1}')
cat >"$receipt_path" <<EOF
{
  "schema_version": 1,
  "status": "exported",
  "archive_type": "multica-server-environment-v1",
  "profile": "$(json_escape "$profile")",
  "archive_path": "$(json_escape "$archive_path")",
  "archive_sha256": "$archive_sha",
  "source_commit": "$(json_escape "$commit")",
  "server_remains_stopped": true,
  "restore_verified": false,
  "created_at": "$created_at"
}
EOF
chmod 600 "$receipt_path"
cat "$receipt_path"
