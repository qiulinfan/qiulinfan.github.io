#!/bin/sh
# Select the native-Linux wrapper for the shared Docker-backed Unix server starter.

set -eu

[ "$(uname -s)" = Linux ] || { echo "This starter is only for native Linux." >&2; exit 3; }
if [ -n "${WSL_INTEROP:-}" ] || { [ -r /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; }; then
  echo "WSL detected. Use the Windows + WSL server path so the first runtime stays Windows-native." >&2
  exit 3
fi
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec /bin/sh "$script_dir/start-unix-server.sh" linux "$@"
