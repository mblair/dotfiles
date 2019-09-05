#!/usr/bin/env bash

set -xueo pipefail

export PATH="$PATH:$HOME/.cargo/bin"

if command -v apt-get; then
	apt-get -y install build-essential ruby
fi

_HERE=$(dirname "$0")
source "${_HERE}/vcs.bash"

curl https://sh.rustup.rs -sSf | sh -s -- --no-modify-path -y --default-toolchain nightly

rustup default nightly
rustup update
rustup toolchain install stable
for _component in rls-preview rust-analysis rust-src rustfmt; do
	rustup component add ${_component} || true # sometimes rls fails to build and isn't available
done

if [[ ! -d $HOME/external_src ]]; then
	mkdir -p "$HOME/external_src"
fi

for _pkg in racer watchexec cargo-watch rg mdbook fd bat hexyl ffsend shellharden lsd tokei; do
	_crate=$_pkg
	if [[ $_pkg == "rg" ]]; then
		_crate="ripgrep"
	elif [[ $_pkg == "fd" ]]; then
		_crate="fd-find"
	fi
	${_pkg} --version || {
		cargo install ${_crate}
		continue
	}
	_installed_version=$(${_pkg} --version | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	_latest_version=$(cargo search ${_crate} | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	if [[ $_installed_version < $_latest_version ]]; then
		cargo uninstall "${_crate}"
		cargo install "${_crate}"
	fi
done

cargo +nightly install nu --features rawkey,clipboard || true

#if which docker; then
#	docker pull rust
#	docker pull rustlang/rust:nightly
#fi
