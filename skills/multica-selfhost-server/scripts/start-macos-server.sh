#!/bin/sh
# Select the macOS wrapper for the shared Docker-backed Unix server starter.

set -eu

[ "$(uname -s)" = Darwin ] || { echo "This starter is only for macOS." >&2; exit 3; }
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec /bin/sh "$script_dir/start-unix-server.sh" macos "$@"
