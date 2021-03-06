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
    _default_branch=$(git for-each-ref --format='%(refname:short)' refs/heads/ | head -n1)
    git checkout "${_default_branch}"
    if [[ -f .gitmodules ]]; then
        git submodule update --init
    fi
    if git diff-index --quiet HEAD; then
        git pull
    else
        git stash
        git pull
        git stash pop
    fi
}
