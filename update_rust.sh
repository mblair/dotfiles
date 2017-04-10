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

#TODO: unify these
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

#TODO: rg --version works now
for _pkg in loc ripgrep; do
	_cmd=$_pkg
	if [[ $_pkg == "ripgrep" ]]; then
		_cmd="rg"
	fi
	if ! command -v ${_cmd}; then
		cargo install ${_pkg} || true # ripgrep's binary is rg
		continue
	else
		_installed_ver=$(find "$HOME"/.cargo/registry/src -type d -name "${_pkg}-*" | tail -1 | perl -pe "s/^.*${_pkg}-(.*)/\${1}/")
		_latest_ver=$(cargo search ${_pkg} 2>/dev/null | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
		if [[ $_installed_ver < $_latest_ver ]]; then
			cargo uninstall ${_pkg}
			cargo install ${_pkg}
		fi
	fi
done
