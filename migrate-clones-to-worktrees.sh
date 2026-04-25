#!/usr/bin/env bash

set -euo pipefail

_HERE=$(
	cd "$(dirname "$0")"
	pwd
)

cd "${_HERE}"
exec mise run migrate-clones-to-worktrees -- "$@"
