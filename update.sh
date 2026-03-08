#!/usr/bin/env bash

set -xueo pipefail

_HERE=$(dirname "$0")

source "${_HERE}/vcs.bash"

RECURSE=false

delete_descript_jest_cache_dirs() {
	while IFS= read -r -d '' _status_entry; do
		_path=${_status_entry:3}
		if [[ "${_path}" == .jest-cache/ || "${_path}" == */.jest-cache/ ]]; then
			echo "Removing untracked ${_path}"
			rm -rf -- "${_path}"
		fi
	done < <(git status --porcelain=v1 -z --untracked-files=normal)
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	-p | --prefix)
		PREFIX="$2"
		shift 2
		;;
	--prefix=*)
		PREFIX="$(echo "$1" | cut -c"10-")"
		shift
		;;
	-r | --recurse)
		RECURSE=true
		shift
		;;
	*) break ;;
	esac
done

_outer_dir=~/"$PREFIX"_src

if [[ -d ${_outer_dir} ]]; then
	cd "${_outer_dir}"
	for _inner_path in "${_outer_dir}"/*; do
		if [[ -d "${_inner_path}" ]]; then
			echo "${_inner_path}"
			cd "${_inner_path}"
			if [[ "${PREFIX}" == descript && -d .git ]]; then
				delete_descript_jest_cache_dirs
			fi
			git_update || true
			if [[ "${RECURSE}" == true && ! -d .git ]]; then
				for _nested_path in "${_inner_path}"/*; do
					if [[ -d "${_nested_path}" ]]; then
						echo "${_nested_path}"
						cd "${_nested_path}"
						if [[ "${PREFIX}" == descript && -d .git ]]; then
							delete_descript_jest_cache_dirs
						fi
						git_update || true
					fi
				done
			fi
		fi
	done
fi

cd "${_HERE}"
