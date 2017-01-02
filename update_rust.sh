#!/usr/bin/env bash

set -xueo pipefail

rustup update
rustup target add asmjs-unknown-emscripten
rustup target add wasm32-unknown-emscripten

# TODO: be smarter about this...
for _pkg in racer rustfmt; do
	_installed_version=$(${_pkg} --version | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	_latest_version=$(cargo search ${_pkg} | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	if [[ $_installed_version < $_latest_version ]]; then
		cargo uninstall "${_pkg}"
		cargo install "${_pkg}"
	fi
done
