#!/usr/bin/env bash

set -xueo pipefail

rustup update

cargo install cargo-edit

cd ~/matthewblair87@gmail.com\ -\ Google\ Drive/My\ Drive/experiments/rust || true
_tld=$(pwd)

for _project in $(ls -1); do
	if [[ -d "${_tld}/${_project}" ]]; then
		echo "${_tld}/${_project}"
		cd "${_tld}/${_project}"
		if [[ -f cargo.toml ]]; then
			cargo clean
			cargo update || true
			cargo upgrade --incompatible
			cargo check || true
			cargo clean
		fi

	fi
done
