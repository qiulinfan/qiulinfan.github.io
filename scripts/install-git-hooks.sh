#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)

if [ -n "${QLBLOG_GIT:-}" ]; then
	git_bin=$QLBLOG_GIT
elif [ -x /opt/homebrew/bin/git ]; then
	git_bin=/opt/homebrew/bin/git
else
	git_bin=git
fi

"$git_bin" -C "$repo_root" config core.hooksPath .githooks
echo "Installed qlblog Git hooks from .githooks"
