#!/bin/sh
# Restore an encrypted Multica environment into an empty Docker target and leave it stopped.

set -eu

server_repo=${1:-}
profile=${2:-home}
archive_path=${3:-}
age_identity_file=${4:-}
confirmation=${5:-}
case "$profile" in ''|*[!A-Za-z0-9._-]*) echo "Invalid profile: $profile" >&2; exit 2 ;; esac
[ "$confirmation" = RESTORE_EMPTY_TARGET ] || { echo "Pass RESTORE_EMPTY_TARGET only after explicit recovery authorization." >&2; exit 2; }
test -f "$server_repo/docker-compose.selfhost.yml" || { echo "Invalid server checkout: $server_repo" >&2; exit 3; }
test -f "$archive_path" || { echo "Environment archive not found: $archive_path" >&2; exit 3; }
test -f "$age_identity_file" || { echo "Age identity file not found." >&2; exit 3; }
for command_name in age cmp docker git tar sed awk find; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "$command_name is required." >&2; exit 4; }
done
docker info >/dev/null 2>&1 || { echo "Docker engine is not running." >&2; exit 4; }

server_repo=$(CDPATH= cd "$server_repo" && pwd)
archive_path=$(CDPATH= cd "$(dirname "$archive_path")" && pwd)/$(basename "$archive_path")
age_identity_file=$(CDPATH= cd "$(dirname "$age_identity_file")" && pwd)/$(basename "$age_identity_file")
compose_file="$server_repo/docker-compose.selfhost.yml"
gateway_container="multica-$profile-gateway"
test ! -e "$server_repo/.env" || { echo "Refusing to overwrite an existing Multica .env." >&2; exit 5; }
[ -z "$(docker compose -f "$compose_file" ps -aq)" ] || { echo "Restore target already has Compose containers." >&2; exit 5; }
docker inspect "$gateway_container" >/dev/null 2>&1 && { echo "Restore target already has a gateway container." >&2; exit 5; }
for volume in multica_pgdata multica_backend_uploads; do
  docker volume inspect "$volume" >/dev/null 2>&1 && { echo "Restore target volume already exists: $volume" >&2; exit 5; }
done

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cache_path=$(/bin/sh "$script_dir/profile-cache.sh" path "$profile")
test -f "$cache_path" || { echo "Complete Tailscale readiness for the target profile before restore." >&2; exit 5; }
phase=$(grep -m 1 '^ONBOARDING_PHASE=' "$cache_path" | sed 's/^[^=]*=//' || true)
case "$phase" in tailscale-ready|server-ready|owner-registration-required|cluster-finalizing|complete) ;;
  *) echo "Target profile has not passed the Tailscale readiness gate." >&2; exit 5 ;;
esac

stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/multica-restore.XXXXXX")
mutation_started=false
state_dir="$HOME/.multica/selfhost-server/$profile"
mkdir -p "$state_dir"
hash_command=sha256sum
command -v sha256sum >/dev/null 2>&1 || hash_command='shasum -a 256'
archive_sha=$($hash_command "$archive_path" | awk '{print $1}')
cleanup() {
  result=$?
  trap - EXIT HUP INT TERM
  docker compose -f "$compose_file" stop >/dev/null 2>&1 || true
  if [ "$result" -ne 0 ] && [ "$mutation_started" = true ]; then
    failed_path="$state_dir/restore-failed.json"
    failed_tmp="$failed_path.tmp.$$"
    cat >"$failed_tmp" <<EOF
{
  "schema_version": 1,
  "status": "partial_restore_stopped",
  "profile": "$profile",
  "archive_sha256": "$archive_sha",
  "requires_manual_review": true,
  "automatic_cleanup_performed": false
}
EOF
    chmod 600 "$failed_tmp"
    mv "$failed_tmp" "$failed_path"
  fi
  if [ -d "$stage_dir" ]; then find "$stage_dir" -depth -mindepth 1 -delete 2>/dev/null || true; rmdir "$stage_dir" 2>/dev/null || true; fi
  exit "$result"
}
trap cleanup EXIT HUP INT TERM
umask 077

decrypted_tar="$stage_dir/environment.tar"
payload_dir="$stage_dir/payload"
mkdir -p "$payload_dir"
age --decrypt -i "$age_identity_file" -o "$decrypted_tar" "$archive_path"
tar -tf "$decrypted_tar" | awk '
  /^\// || /^\.\.\// || /\/\.\.\// || /\\/ { bad=1 }
  END { exit bad ? 1 : 0 }
' || { echo "Archive contains unsafe paths." >&2; exit 6; }
tar -tvf "$decrypted_tar" | awk '$1 ~ /^[lh]/ { bad=1 } END { exit bad ? 1 : 0 }' || {
  echo "Archive contains links; restore refused." >&2; exit 6;
}
tar -C "$payload_dir" -xf "$decrypted_tar"

for required_file in manifest.json SHA256SUMS database.dump backend_uploads.tar.gz server.env; do
  test -f "$payload_dir/$required_file" || { echo "Archive is missing $required_file." >&2; exit 6; }
done
grep -q '"archive_type": "multica-server-environment-v1"' "$payload_dir/manifest.json" || {
  echo "Unsupported environment archive type." >&2; exit 6;
}
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$payload_dir" && sha256sum -c SHA256SUMS >/dev/null)
else
  (cd "$payload_dir" && shasum -a 256 -c SHA256SUMS >/dev/null)
fi
source_commit=$(sed -n 's/^[[:space:]]*"source_commit"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' "$payload_dir/manifest.json" | head -n 1)
target_commit=$(git -C "$server_repo" rev-parse HEAD)
[ -n "$source_commit" ] && [ "$target_commit" = "$source_commit" ] || {
  echo "Target checkout must match the exported source commit." >&2; exit 6;
}
target_origin=$(git -C "$server_repo" remote get-url origin)
case "$target_origin" in https://github.com/multica-ai/multica.git|git@github.com:multica-ai/multica.git) ;;
  *) echo "Unexpected Multica origin: $target_origin" >&2; exit 6 ;;
esac
cmp -s "$payload_dir/docker-compose.selfhost.yml" "$compose_file" || {
  echo "Target Compose file does not match the exported environment." >&2; exit 6;
}

env_tmp="$server_repo/.env.restore.$$"
cp "$payload_dir/server.env" "$env_tmp"
chmod 600 "$env_tmp"
mv "$env_tmp" "$server_repo/.env"
mutation_started=true

docker compose -f "$compose_file" up -d postgres >/dev/null
postgres_container=$(docker compose -f "$compose_file" ps -q postgres)
case "$postgres_container" in ''|*[!a-f0-9]*) echo "Could not resolve restored postgres container." >&2; exit 7 ;; esac
attempt=0
while [ "$attempt" -lt 120 ]; do
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$postgres_container" 2>/dev/null || true)
  [ "$health" = healthy ] && break
  attempt=$((attempt + 1)); sleep 1
done
[ "${health:-}" = healthy ] || { echo "Restored PostgreSQL did not become healthy." >&2; exit 7; }
docker cp "$payload_dir/database.dump" "$postgres_container:/tmp/multica-restore.dump"
docker exec "$postgres_container" sh -eu -c \
  'pg_restore -U "${POSTGRES_USER:-multica}" -d "${POSTGRES_DB:-multica}" --clean --if-exists --no-owner --no-privileges /tmp/multica-restore.dump; rm -f /tmp/multica-restore.dump'

docker compose -f "$compose_file" create --no-deps backend >/dev/null
backend_container=$(docker compose -f "$compose_file" ps -aq backend)
case "$backend_container" in ''|*[!a-f0-9]*) echo "Could not resolve restored backend container." >&2; exit 7 ;; esac
mkdir -p "$stage_dir/uploads"
tar -C "$stage_dir/uploads" -xzf "$payload_dir/backend_uploads.tar.gz"
docker cp "$stage_dir/uploads/." "$backend_container:/app/data/uploads/"
docker compose -f "$compose_file" stop >/dev/null
[ -z "$(docker compose -f "$compose_file" ps -q)" ] || { echo "Restored server did not remain stopped." >&2; exit 7; }

set -- "SERVER_REPO=$server_repo" "ONBOARDING_PHASE=cluster-finalizing"
if [ -f "$payload_dir/profile.env" ]; then
  for key in OWNER_EMAIL ALLOWED_EMAILS INVITED_EMAILS ACCEPTED_EMAILS ALLOW_SIGNUP DISABLE_WORKSPACE_CREATION WORKSPACE_NAME WORKSPACE_SLUG ISSUE_PREFIX MAX_CONCURRENT_TASKS WORKSPACE_AGENT_ACCESS_APPROVED; do
    entry=$(grep -m 1 "^$key=" "$payload_dir/profile.env" || true)
    test -z "$entry" || set -- "$@" "$entry"
  done
fi
/bin/sh "$script_dir/profile-cache.sh" set "$profile" "$@" >/dev/null

receipt_path="$state_dir/restore.json"
receipt_tmp="$receipt_path.tmp.$$"
restored_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
cat >"$receipt_tmp" <<EOF
{
  "schema_version": 1,
  "status": "restored_stopped",
  "archive_type": "multica-server-environment-v1",
  "profile": "$(json_escape "$profile")",
  "archive_sha256": "$archive_sha",
  "target_repo": "$(json_escape "$server_repo")",
  "database_restored": true,
  "uploads_restored": true,
  "environment_restored": true,
  "requires_start_and_smoke_validation": true,
  "restored_at": "$restored_at"
}
EOF
chmod 600 "$receipt_tmp"
mv "$receipt_tmp" "$receipt_path"
mutation_started=false
cat "$receipt_path"
