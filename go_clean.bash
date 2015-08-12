#!/usr/bin/env bash

set -xueo pipefail

export GOPATH="$HOME/gopath"
_current_employer_github_org=Flipboard
_current_employer_gopath="${GOPATH}/src/github.com/${_current_employer_github_org}"
_unpushed_changes=0
_dirty_repos=()
_to_clone=()
if [[ -d "${_current_employer_gopath}" ]]; then
    cd "${_current_employer_gopath}"
    for _inner in ./*; do
        if [[ -d "${_inner}" ]]; then
            cd "${_current_employer_gopath}/${_inner}"
            if [[ $(git log --branches --not --remotes) != "" ]] || ! git diff --quiet HEAD; then
                mv "${_current_employer_gopath}/${_inner}" /tmp
                _dirty_repos+=${_inner}
                _unpushed_changes=1
            else
                _to_clone+=$(git remote -v show origin | grep Fetch | cut -d":" -f2- | tr -d '[:space:]')
            fi
        fi
    done
fi

rm -rf "$GOPATH"
mkdir -p "${_current_employer_gopath}"
cd
go get -u github.com/nsf/gocode
go get -u github.com/rogpeppe/godef
go get -u github.com/golang/lint/golint
go get -u github.com/kisielk/errcheck
go get -u github.com/tools/godep
go get -u golang.org/x/tools/cmd/{cover,godoc,goimports,oracle}
go get -u github.com/ChimeraCoder/gojson/gojson

# https://github.com/3rf/codecoroner/issues/5
#go get -u github.com/3rf/codecoroner

if [[ ${_unpushed_changes} == 1 ]]; then
    mkdir -p "${_current_employer_gopath}"
    cd "${_current_employer_gopath}"
    for _repo in ${_dirty_repos[*]}; do
        mv /tmp/"${_repo}" .
    done
fi

if [[ ${#_to_clone[*]} -gt 0 ]]; then
    for _url in ${_to_clone[*]}; do
        cd "${_current_employer_gopath}"
        git clone "${_url}"
    done
fi
