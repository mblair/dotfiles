#!/usr/bin/env bash

set -xueo pipefail

if ! rustup update; then
	echo "rustup update failed; retrying."
	if rustup toolchain list | grep -q '^nightly-'; then
		echo "Reinstalling nightly toolchain (recover from partial install / conflicts)."
		rustup toolchain uninstall nightly 2>/dev/null || true
		rustup toolchain install nightly
	fi
	rustup update
fi

cargo install cargo-edit

upgrade_cargo_project() {
	local _project_path=$1
	local _cargo_manifest
	local _cargo_toml_before
	local _cargo_toml_after

	[[ -d "${_project_path}" ]] || return 0

	echo "${_project_path}"
	cd "${_project_path}"

	if [[ -f Cargo.toml ]]; then
		_cargo_manifest=Cargo.toml
	elif [[ -f cargo.toml ]]; then
		_cargo_manifest=cargo.toml
	else
		return 0
	fi

	cargo clean
	cargo update || true
	_cargo_toml_before=$(shasum -a 256 "${_cargo_manifest}" | awk '{print $1}')
	cargo upgrade --incompatible
	_cargo_toml_after=$(shasum -a 256 "${_cargo_manifest}" | awk '{print $1}')
	if [[ "${_cargo_toml_before}" != "${_cargo_toml_after}" ]]; then
		cargo check || true
	fi
	cargo clean
}

_rust_experiments_dir="${HOME}/matthewblair87@gmail.com - Google Drive/My Drive/experiments/rust"
if [[ -d "${_rust_experiments_dir}" ]]; then
	for _project_path in "${_rust_experiments_dir}"/*; do
		if [[ -d "${_project_path}" ]]; then
			upgrade_cargo_project "${_project_path}"
		fi
	done
fi

upgrade_cargo_project "${HOME}/my_src/mattyb.rs"
