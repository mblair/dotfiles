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
    _default_branch=$(git remote show origin | grep 'HEAD branch' | perl -pe 's|HEAD branch: (.*)|${1}|g' | awk '{print $1}')
    _current_branch=$(git branch --show-current)
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
    if [[ $_default_branch != $_current_branch ]]; then
        git checkout "${_current_branch}"
    fi

    git-removed-branches -f -p || nodenv which node
}
