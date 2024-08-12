#!/usr/bin/env bash

set -xueo pipefail

cd ~/Google\ Drive/My\ Drive/experiments/rust
_tld=$(pwd)

for _project in $(ls -1); do
	if [[ -d "${_tld}/${_project}" ]]; then
		echo "${_tld}/${_project}"
		cd "${_tld}/${_project}"
		cargo clean
		cargo update || true
	fi
done
