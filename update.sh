#!/usr/bin/env bash

set -xueo pipefail

_HERE=$(
	cd "$(dirname "$0")"
	pwd
)

# shellcheck source=./vcs.bash
source "${_HERE}/vcs.bash"

PREFIX=""
RECURSE=false
RECOVER_DIRTY=false
LAST_PATH_IS_GIT_REPO=false
UPDATED_REPOS=()
SKIPPED_IN_PROGRESS_REPOS=()
SKIPPED_UNMERGED_REPOS=()
SKIPPED_DIRTY_REPOS=()
FAILED_REPOS=()

usage() {
	echo "Usage: $0 --prefix <prefix> [--recurse|--recursive] [--recover-dirty]"
	echo "  -p, --prefix <prefix>    Repo prefix under ~/<prefix>_src"
	echo "  -r, --recurse            Recurse into nested directories when a top-level entry is not a git repo"
	echo "      --recursive          Alias for --recurse"
	echo "      --recover-dirty      For --prefix descript, run resolve-clones --mode recover on dirty clones skipped during update"
}

delete_descript_jest_cache_dirs() {
	while IFS= read -r -d '' _status_entry; do
		_path=${_status_entry:3}
		if [[ "${_path}" == .jest-cache/ || "${_path}" == */.jest-cache/ ]]; then
			echo "Removing untracked ${_path}"
			rm -rf -- "${_path}"
		fi
	done < <(git status --porcelain=v1 -z --untracked-files=normal)
}

is_git_repo() {
	git rev-parse --is-inside-work-tree &>/dev/null
}

update_repo_path() {
	_repo_path=$1
	LAST_PATH_IS_GIT_REPO=false

	echo "${_repo_path}"
	cd "${_repo_path}"
	if is_git_repo; then
		LAST_PATH_IS_GIT_REPO=true
		if [[ "${PREFIX}" == descript ]]; then
			delete_descript_jest_cache_dirs
		fi
		if git_update; then
			record_git_update_result "${_repo_path}" 0
		else
			record_git_update_result "${_repo_path}" $?
		fi
	else
		echo "Skipping non-git directory: ${_repo_path}"
	fi
}

record_git_update_result() {
	_repo_path=$1
	_status=$2

	case "${_status}" in
	0)
		UPDATED_REPOS+=("${_repo_path}")
		;;
	10)
		SKIPPED_IN_PROGRESS_REPOS+=("${_repo_path}")
		;;
	11)
		SKIPPED_UNMERGED_REPOS+=("${_repo_path}")
		;;
	12)
		SKIPPED_DIRTY_REPOS+=("${_repo_path}")
		;;
	*)
		FAILED_REPOS+=("${_repo_path} (exit ${_status})")
		;;
	esac
}

print_repo_group() {
	_label=$1
	shift
	_repos=("$@")

	echo "${_label}: ${#_repos[@]}"
	for _repo in "${_repos[@]}"; do
		echo "  ${_repo}"
	done
}

recover_dirty_descript_clones() {
	if [[ "${RECOVER_DIRTY}" != true ]]; then
		return 0
	fi

	if [[ "${PREFIX}" != descript ]]; then
		echo "--recover-dirty is only supported with --prefix descript" >&2
		return 30
	fi

	if [[ ${#SKIPPED_DIRTY_REPOS[@]} -eq 0 ]]; then
		echo "No dirty descript repos were skipped; no recovery needed."
		return 0
	fi

	if ! command -v mise &>/dev/null; then
		echo "mise is required for --recover-dirty" >&2
		return 31
	fi

	_recoverable_clone_names=()
	_skipped_nonclone_repos=()
	for _repo_path in "${SKIPPED_DIRTY_REPOS[@]}"; do
		_repo_name=$(basename "${_repo_path}")
		if [[ "${_repo_name}" == "${PREFIX}" ]] || [[ "${_repo_name}" =~ ^${PREFIX}-[0-9]+$ ]]; then
			_recoverable_clone_names+=("${_repo_name}")
		else
			_skipped_nonclone_repos+=("${_repo_name}")
		fi
	done

	if [[ ${#_recoverable_clone_names[@]} -eq 0 ]]; then
		echo "No dirty ${PREFIX} clone directories matched ${PREFIX}{,-<n>}; no recovery needed."
		return 0
	fi

	if [[ ${#_skipped_nonclone_repos[@]} -gt 0 ]]; then
		echo "Skipping dirty non-clone repos from recovery:"
		for _repo_name in "${_skipped_nonclone_repos[@]}"; do
			echo "  ${_repo_name}"
		done
	fi

	_resolve_args=(run resolve-clones -- -p "${PREFIX}" --mode recover)
	for _repo_name in "${_recoverable_clone_names[@]}"; do
		_resolve_args+=(--clone "${_repo_name}")
	done

	echo "=== update.sh recovery for ${PREFIX} ==="
	cd "${_HERE}"
	mise "${_resolve_args[@]}"
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
	-r | --recurse | --recursive)
		RECURSE=true
		shift
		;;
	--recover-dirty)
		RECOVER_DIRTY=true
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 1
		;;
	esac
done

if [[ -z "${PREFIX}" ]]; then
	echo "--prefix is required" >&2
	usage >&2
	exit 1
fi

_outer_dir=~/"$PREFIX"_src

if [[ -d ${_outer_dir} ]]; then
	cd "${_outer_dir}"
	for _inner_path in "${_outer_dir}"/*; do
		if [[ -d "${_inner_path}" ]]; then
			update_repo_path "${_inner_path}"
			if [[ "${RECURSE}" == true && "${LAST_PATH_IS_GIT_REPO}" != true ]]; then
				for _nested_path in "${_inner_path}"/*; do
					if [[ -d "${_nested_path}" ]]; then
						update_repo_path "${_nested_path}"
					fi
				done
			fi
		fi
	done
fi

echo "=== update.sh summary for ${PREFIX} ==="
print_repo_group "updated" "${UPDATED_REPOS[@]}"
print_repo_group "skipped (in-progress git op)" "${SKIPPED_IN_PROGRESS_REPOS[@]}"
print_repo_group "skipped (unmerged paths)" "${SKIPPED_UNMERGED_REPOS[@]}"
print_repo_group "skipped (dirty)" "${SKIPPED_DIRTY_REPOS[@]}"
print_repo_group "failed" "${FAILED_REPOS[@]}"

cd "${_HERE}"
recover_dirty_descript_clones
