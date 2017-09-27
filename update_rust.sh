#!/usr/bin/env bash

set -xueo pipefail

if command -v brew; then
	brew uninstall multirust || true
fi

_HERE=$(dirname "$0")
source "${_HERE}/vcs.bash"

rm -rf ~/.multirust
curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain nightly --no-modify-path -y -v
rustup update
for _component in rls rust-analysis rust-src; do
	rustup component add ${_component}
done

if [[ ! -d $HOME/external_src ]]; then
	mkdir -p "$HOME/external_src"
fi

cd "$HOME/external_src/"
for _repo in rust-lang/book rust-lang-nursery/rust-by-example; do
	_dir=$HOME/external_src/${_repo##*/}

	if [[ ! -d ${_dir} ]]; then
		git clone https://github.com/"${_repo}"
	else
		cd "${_dir}"
		git_update
	fi
done

#TODO: unify these somehow
for _pkg in racer rustfmt watchexec cargo-watch rg mdbook fd; do
	_crate=$_pkg
	if [[ $_pkg == "ripgrep" ]]; then
		_crate="ripgrep"
	elif [[ $_pkg == "fd" ]]; then
		_crate="fd-find"
	fi
	${_pkg} --version || {
		cargo install ${_crate}
		break
	}
	_installed_version=$(${_pkg} --version | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	_latest_version=$(cargo search ${_crate} | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	if [[ $_installed_version < $_latest_version ]]; then
		cargo uninstall "${_crate}"
		cargo install "${_crate}"
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
		if [[ ! -d "$HOME/.cargo/registry/src" ]]; then
			cargo uninstall ${_pkg}
			cargo install ${_pkg}
		else
			_installed_ver=$(find "$HOME"/.cargo/registry/src -type d -name "${_pkg}-*" | tail -1 | perl -pe "s/^.*${_pkg}-(.*)/\${1}/")
			_latest_ver=$(cargo search ${_pkg} 2>/dev/null | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
			if [[ $_installed_ver < $_latest_ver ]]; then
				cargo uninstall ${_pkg}
				cargo install ${_pkg}
			fi
		fi
	fi
done

if which docker; then
	docker pull rustlang/rust:nightly
fi
