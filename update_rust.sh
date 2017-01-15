#!/usr/bin/env bash

set -xueo pipefail

if command -v brew; then
	brew uninstall multirust || true
fi

rm -rf ~/.multirust
curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain nightly --no-modify-path -y -v
rustup update
rustup target add asmjs-unknown-emscripten
rustup target add wasm32-unknown-emscripten

for _pkg in racer rustfmt; do
	${_pkg} --version || {
		cargo install ${_pkg}
		break
	}
	_installed_version=$(${_pkg} --version | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	_latest_version=$(cargo search ${_pkg} | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	if [[ $_installed_version < $_latest_version ]]; then
		cargo uninstall "${_pkg}"
		cargo install "${_pkg}"
	fi
done

for _cmd in loc ripgrep; do
	if ! command -v ${_cmd}; then
		cargo install ${_cmd} || true # ripgrep's binary is rg
		continue
	else
		_installed_ver=$(find "$HOME"/.cargo/registry/src -type d -name "${_cmd}-*" | perl -pe "s/^.*${_cmd}-(.*)/\${1}/")
		_latest_ver=$(cargo search ${_cmd} | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
		if [[ $_installed_ver < $_latest_ver ]]; then
			cargo uninstall ${_cmd}
			cargo install ${_cmd}
		fi
	fi
done
