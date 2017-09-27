#!/usr/bin/env bash

set -xueo pipefail

_HERE=$(dirname "$0")

source "${_HERE}/vcs.bash"

_outer_dir=~/external_src
cd ${_outer_dir}
for _inner_dir in $(ls -1); do
	if [[ -d "${_outer_dir}/${_inner_dir}" ]]; then
		echo "${_outer_dir}/${_inner_dir}"
		cd "${_outer_dir}/${_inner_dir}"
		git_update
	fi
done

cd "${_HERE}"
