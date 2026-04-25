#!/usr/bin/env bash

pretty_date() {
	_TS=$1
	_FORMAT='+%Y%m%dT%H%M'

	if [[ $(uname -s) == 'Darwin' ]]; then
		date -u -j -f '%s' "${_TS}" "${_FORMAT}"
	else
		date -u --date @"${_TS}" "${_FORMAT}"
	fi
}

git_revid() {
	git log -n1 --format='%H'
}

git_epoch() {
	git log -n1 --format='%at'
}

git_branch() {
	git symbolic-ref --short -q HEAD
}

git_clean() {
	git clean -fdx
	git reset --hard
}

git_is_dirty() {
	[[ -n "$(git status --porcelain=v1 --untracked-files=normal)" ]]
}

git_has_unmerged_paths() {
	[[ -n "$(git diff --name-only --diff-filter=U)" ]]
}

git_has_in_progress_operation() {
	_git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 1

	[[ -d "${_git_dir}/rebase-merge" ]] ||
		[[ -d "${_git_dir}/rebase-apply" ]] ||
		[[ -f "${_git_dir}/MERGE_HEAD" ]] ||
		[[ -f "${_git_dir}/CHERRY_PICK_HEAD" ]] ||
		[[ -f "${_git_dir}/REVERT_HEAD" ]] ||
		[[ -f "${_git_dir}/BISECT_LOG" ]]
}

git_default_branch_for_remote() {
	_remote=$1

	_default_branch=$(
		git symbolic-ref --quiet --short "refs/remotes/${_remote}/HEAD" 2>/dev/null |
			sed "s#^${_remote}/##"
	)
	if [[ -n "${_default_branch}" ]]; then
		echo "${_default_branch}"
		return 0
	fi

	_default_branch=$(
		git remote show "${_remote}" 2>/dev/null |
			grep 'HEAD branch' |
			perl -pe 's|HEAD branch: (.*)|${1}|g' |
			awk '{print $1}'
	)
	if [[ -n "${_default_branch}" ]]; then
		echo "${_default_branch}"
		return 0
	fi

	echo "Unable to determine default branch for ${_remote}" >&2
	return 1
}

git_update() {
	_current_branch=$(git branch --show-current)

	if git_has_in_progress_operation; then
		echo "Skipping repo with in-progress git operation"
		return 10
	fi

	if git_has_unmerged_paths; then
		echo "Skipping repo with unmerged paths"
		return 11
	fi

	if git_is_dirty; then
		echo "Skipping dirty repo"
		return 12
	fi

	# Try origin first, fall back to upstream if origin is unreachable
	_remote="origin"
	if ! timeout 5 git ls-remote --exit-code origin &>/dev/null; then
		if git remote get-url upstream &>/dev/null; then
			echo "origin unreachable, using upstream instead"
			_remote="upstream"
		else
			echo "origin unreachable and no upstream remote, skipping"
			return 20
		fi
	fi

	# Stale reflog for ${_remote}/<repo-dir> can break fetch; remove before pull.
	_git_dir=$(git rev-parse --git-dir)
	_repo_reflog="${_git_dir}/logs/refs/remotes/${_remote}/$(basename "$(git rev-parse --show-toplevel)")"
	if [[ -f "${_repo_reflog}" ]]; then
		rm -f -- "${_repo_reflog}"
	fi

	git fetch --prune "${_remote}" || return 21
	_default_branch=$(git_default_branch_for_remote "${_remote}") || return 22
	git checkout "${_default_branch}" || return 23
	git branch --set-upstream-to="${_remote}"/"${_default_branch}" "${_default_branch}"

	if [[ -f .gitmodules ]]; then
		git submodule update --init || return 24
	fi
	git merge --ff-only "${_remote}"/"${_default_branch}" || return 25
	if [[ -n "${_current_branch}" && $_default_branch != "$_current_branch" ]]; then
		git checkout "${_current_branch}" || return 26
	fi

	#git-delete-merged-branches
}
