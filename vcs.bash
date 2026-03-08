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

git_update() {
	_current_branch=$(git branch --show-current)

	# Try origin first, fall back to upstream if origin is unreachable
	_remote="origin"
	if ! timeout 5 git ls-remote --exit-code origin &>/dev/null; then
		if git remote get-url upstream &>/dev/null; then
			echo "origin unreachable, using upstream instead"
			_remote="upstream"
		else
			echo "origin unreachable and no upstream remote, skipping"
			return 1
		fi
	fi

	_default_branch=$(git remote show "${_remote}" | grep 'HEAD branch' | perl -pe 's|HEAD branch: (.*)|${1}|g' | awk '{print $1}')
	git checkout "${_default_branch}"
	git branch --set-upstream-to="${_remote}"/"${_default_branch}" "${_default_branch}"

	if [[ -f .gitmodules ]]; then
		git submodule update --init
	fi
	git pull --rebase --autostash
	if [[ $_default_branch != "$_current_branch" ]]; then
		git checkout "${_current_branch}"
	fi

	#git-delete-merged-branches
}
