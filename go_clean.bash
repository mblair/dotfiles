#!/usr/bin/env bash

set -xueo pipefail

if [[ -z ${GOPATH:-} ]]; then
    export GOPATH="$HOME/go"
fi

_current_employer_github_org=figma
_current_employer_gopath="${GOPATH}/src/github.com/${_current_employer_github_org}"
_unpushed_changes=0
_dirty_repos=()
_to_clone=()

if [[ -d "${_current_employer_gopath}" ]]; then
    cd "${_current_employer_gopath}"
    for _inner in ${_current_employer_gopath}/*; do
        echo "${_inner}"
        if [[ -d "${_inner}" ]]; then
            cd "${_inner}"
            if [[ $(git log --branches --not --remotes) != "" ]] || ! git diff --quiet HEAD || test -n "$(git ls-files --others)"; then
                mv "${_inner}" /tmp
                _dirty_repos+=$(basename ${_inner})
                _unpushed_changes=1
            else
                _to_clone+=($(git remote -v show origin | grep Fetch | cut -d":" -f2- | tr -d '[:space:]'))
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
go get -u github.com/govend/govend
go get -u golang.org/x/tools/cmd/{cover,goimports,gorename,guru}
go get -u github.com/ChimeraCoder/gojson/gojson
go get -u github.com/motemen/go-pocket/...
#go get -u github.com/davecheney/httpstat
go get -u github.com/axw/gocov/gocov
go get -u gopkg.in/matm/v1/gocov-html
go get -u github.com/mvdan/sh/cmd/shfmt
go get -u github.com/shurcooL/markdownfmt
go get -u honnef.co/go/staticcheck/cmd/staticcheck

# in case i missed any
go get -u github.com/alecthomas/gometalinter
gometalinter --install

if [[ ${_unpushed_changes} == 1 ]]; then
    mkdir -p "${_current_employer_gopath}"
    cd "${_current_employer_gopath}"
    for _repo in ${_dirty_repos[*]}; do
        cd "${_current_employer_gopath}"
        mv /tmp/"${_repo}" .
        cd ${_repo}
        git remote prune origin
    done
fi

if [[ ${#_to_clone[*]} -gt 0 ]]; then
    for _url in ${_to_clone[*]}; do
        cd "${_current_employer_gopath}"
        git clone "${_url}"
    done
fi
