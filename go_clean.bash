#!/bin/bash

set -xueo pipefail

export GOPATH="$HOME/gopath"
_current_employer_github_org=Flipboard
_current_employer_gopath="${GOPATH}/src/github.com/${_current_employer_github_org}"
_unpushed_changes=0
_dirty_repos=()

if [[ -d "${_current_employer_gopath}" ]]; then
    cd "${_current_employer_gopath}"
    for _inner in ./*; do
        if [[ -d "${_inner}" ]]; then
            cd "${_current_employer_gopath}/${_inner}"
            if [[ $(git log --branches --not --remotes) != "" ]] || ! git diff --quiet HEAD; then
                mv "${_current_employer_gopath}/${_inner}" /tmp
                _dirty_repos+=${_inner}
                _unpushed_changes=1
            fi
        fi
    done
fi

rm -rf "$GOPATH"
mkdir -p "$GOPATH"
go get -u github.com/nsf/gocode
go get -u github.com/rogpeppe/godef
go get -u github.com/golang/lint/golint
go get -u github.com/kisielk/errcheck
go get -u github.com/tools/godep
go get -u golang.org/x/tools/cmd/{cover,godoc,goimports,oracle,vet}
go get -u github.com/ChimeraCoder/gojson

if [[ ${_unpushed_changes} == 1 ]]; then
    mkdir -p "${_current_employer_gopath}"
    cd "${_current_employer_gopath}"
    for _repo in ${_dirty_repos[*]}; do
        mv /tmp/"${_repo}" .
    done
fi
