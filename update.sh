#!/usr/bin/env bash

set -xueo pipefail

_HERE=$(dirname "$0")

source "${_HERE}/vcs.bash"

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
	*) break ;;
	esac
done

_outer_dir=~/"$PREFIX"_src

if [[ -d ${_outer_dir} ]]; then
	cd ${_outer_dir}
	for _inner_dir in $(ls -1); do
		if [[ -d "${_outer_dir}/${_inner_dir}" ]]; then
			echo "${_outer_dir}/${_inner_dir}"
			cd "${_outer_dir}/${_inner_dir}"
			git_update
		fi
	done
fi

cd "${_HERE}"
