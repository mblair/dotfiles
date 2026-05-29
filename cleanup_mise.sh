#!/usr/bin/env bash

set -euo pipefail

APPLY=false
PRUNE=false

usage() {
	echo "Usage: $0 [--apply] [--prune]"
	echo "  --apply    Remove stale go: backend installs and reshim. Without this, only dry-run."
	echo "  --prune    Also run mise prune --tools. Without this, only list prunable tools."
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--apply)
		APPLY=true
		;;
	--prune)
		PRUNE=true
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
	shift
done

if ! command -v mise >/dev/null 2>&1; then
	echo "mise is required" >&2
	exit 1
fi

MISE_DATA_DIR=${MISE_DATA_DIR:-"${HOME}/.local/share/mise"}
MISE_INSTALLS_DIR=${MISE_INSTALLS_DIR:-"${MISE_DATA_DIR}/installs"}
MISE_INSTALLS_DB="${MISE_INSTALLS_DIR}/.mise-installs.toml"

_tmp_dir=$(mktemp -d)
cleanup_tmp() {
	rm -rf "${_tmp_dir}"
}
trap cleanup_tmp EXIT

_go_registry_file="${_tmp_dir}/mise-go-registry.txt"
_requested_go_backends_file="${_tmp_dir}/requested-go-backends.txt"
_installed_go_backends_file="${_tmp_dir}/installed-go-backends.txt"
_stale_go_backends_file="${_tmp_dir}/stale-go-backends.txt"

find_installed_go_backends() {
	if [[ -f "${MISE_INSTALLS_DB}" ]]; then
		awk -F'"' '$1 ~ /^short = / && $2 ~ /^go:/ {print $2}' "${MISE_INSTALLS_DB}"
	fi

	if [[ -d "${MISE_INSTALLS_DIR}" ]]; then
		find "${MISE_INSTALLS_DIR}" -mindepth 2 -maxdepth 2 -name .mise.backend -print | while IFS= read -r _backend_file; do
			_backend=$(sed -n '1p' "${_backend_file}")
			case "${_backend}" in
			go:*) echo "${_backend}" ;;
			esac
		done
	fi
}

find_requested_go_backends() {
	mise current 2>/dev/null | awk '$1 ~ /^go:/ {print $1}' || true
}

display_path() {
	case "$1" in
	"${HOME}"/*) printf '%s/%s\n' "\$HOME" "${1#"${HOME}/"}" ;;
	*) printf '%s\n' "$1" ;;
	esac
}

remove_stale_backend_dir() {
	_tool=$1

	[[ -d "${MISE_INSTALLS_DIR}" ]] || return 0

	find "${MISE_INSTALLS_DIR}" -mindepth 2 -maxdepth 2 -name .mise.backend -print | while IFS= read -r _backend_file; do
		_backend=$(sed -n '1p' "${_backend_file}")
		[[ "${_backend}" == "${_tool}" ]] || continue

		_tool_dir=${_backend_file%/.mise.backend}
		if find "${_tool_dir}" -mindepth 1 -maxdepth 1 ! -name .mise.backend -print -quit | grep -q .; then
			echo "Leaving non-empty stale metadata dir: $(display_path "${_tool_dir}")"
			continue
		fi

		if [[ "${APPLY}" == true ]]; then
			rm -rf "${_tool_dir}"
			echo "Removed stale metadata dir: $(display_path "${_tool_dir}")"
		else
			echo "Would remove stale metadata dir: $(display_path "${_tool_dir}")"
		fi
	done
}

remove_stale_installs_db_section() {
	_tool=$1

	[[ -f "${MISE_INSTALLS_DB}" ]] || return 0
	grep -qF "short = \"${_tool}\"" "${MISE_INSTALLS_DB}" || return 0

	if [[ "${APPLY}" != true ]]; then
		echo "Would remove stale installs-db section: ${_tool}"
		return 0
	fi

	_db_tmp=$(mktemp "${MISE_INSTALLS_DB}.XXXXXX")
	awk -v tool="${_tool}" '
		function flush_section() {
			if (section_count == 0) {
				return
			}
			if (!section_matches) {
				for (i = 1; i <= section_count; i++) {
					print section[i]
				}
			}
		}
		/^\[[^]]+\]$/ {
			flush_section()
			delete section
			section_count = 1
			section[section_count] = $0
			section_matches = 0
			next
		}
		{
			section[++section_count] = $0
			if ($0 == "short = \"" tool "\"" || $0 == "full = \"" tool "\"") {
				section_matches = 1
			}
		}
		END {
			flush_section()
		}
	' "${MISE_INSTALLS_DB}" >"${_db_tmp}"
	mv "${_db_tmp}" "${MISE_INSTALLS_DB}"
	echo "Removed stale installs-db section: ${_tool}"
}

cleanup_stale_backend_metadata() {
	_tool=$1

	remove_stale_backend_dir "${_tool}"
	remove_stale_installs_db_section "${_tool}"
}

print_heading() {
	echo
	echo "=== $1 ==="
}

print_heading "Mise prunable tools"
if ! mise ls --prunable; then
	echo "Unable to list prunable tools" >&2
	exit 1
fi

print_heading "Stale installed go: backends"
mise registry --backend go | awk '{print $2}' | sort -u >"${_go_registry_file}"
find_requested_go_backends | sort -u >"${_requested_go_backends_file}"
find_installed_go_backends | sort -u >"${_installed_go_backends_file}"

while IFS= read -r _tool; do
	[[ -n "${_tool}" ]] || continue
	grep -qxF "${_tool}" "${_go_registry_file}" && continue
	grep -qxF "${_tool}" "${_requested_go_backends_file}" && continue
	echo "${_tool}"
done <"${_installed_go_backends_file}" >"${_stale_go_backends_file}"

if [[ -s "${_stale_go_backends_file}" ]]; then
	cat "${_stale_go_backends_file}"
else
	echo "none"
fi

print_heading "Actions"
if [[ "${APPLY}" != true ]]; then
	echo "Dry run. Pass --apply to remove stale go: backend installs."
fi

if [[ -s "${_stale_go_backends_file}" ]]; then
	while IFS= read -r _tool; do
		if [[ "${APPLY}" == true ]]; then
			mise uninstall --all "${_tool}" 2>&1
		else
			mise uninstall --dry-run --all "${_tool}" 2>&1
		fi
		cleanup_stale_backend_metadata "${_tool}"
	done <"${_stale_go_backends_file}"
else
	echo "No stale go: backend installs to remove."
fi

if [[ "${PRUNE}" == true ]]; then
	if [[ "${APPLY}" == true ]]; then
		mise prune --tools 2>&1
	else
		mise prune --dry-run --tools 2>&1
	fi
else
	echo "Skipping broad mise prune. Pass --prune to include unused tool-version pruning."
fi

if [[ "${APPLY}" == true ]]; then
	mise reshim 2>&1
	mise doctor 2>&1
fi
