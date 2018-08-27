#!/usr/bin/env bash

set -xueo pipefail

if [[ -z ${GOPATH:-} ]]; then
	export GOPATH="$HOME/go"
fi

# _current_employer_github_org=figma
# _github_gopath_prefix="${GOPATH}/src/github.com"
# _current_employer_gopath="${_github_gopath_prefix}/${_current_employer_github_org}"
# _unpushed_changes=0
#
# # TODO: use two arrays here, one for personal, one for work
# _dirty_repos=()
# _to_clone=()
#
# if [[ -d "${_current_employer_gopath}" ]]; then
# 	cd "${_current_employer_gopath}"
# 	for _inner in ${_current_employer_gopath}/*; do
# 		echo "${_inner}"
# 		if [[ -d "${_inner}" ]]; then
# 			cd "${_inner}"
# 			if [[ $(git log --branches --not --remotes) != "" ]] || ! git diff --quiet HEAD || test -n "$(git ls-files --others)"; then
# 				mv "${_inner}" /tmp
# 				_dirty_repos+=("$(basename "${_inner}")")
# 				_unpushed_changes=1
# 			else
# 				_to_clone+=($(git remote -v show origin | grep Fetch | cut -d":" -f2- | tr -d '[:space:]'))
# 			fi
# 		fi
# 	done
# fi
#
# rm -rf "$GOPATH"
# mkdir -p "${_current_employer_gopath}"
#
# if [[ ${_unpushed_changes} == 1 ]]; then
# 	mkdir -p "${_current_employer_gopath}"
# 	cd "${_current_employer_gopath}"
# 	for _repo in ${_dirty_repos[*]}; do
# 		cd "${_current_employer_gopath}"
# 		mv /tmp/"${_repo}" .
# 		cd "${_repo}"
# 		git remote prune origin
# 	done
# fi
#
# if [[ ${#_to_clone[*]} -gt 0 ]]; then
# 	for _url in ${_to_clone[*]}; do
# 		cd "${_current_employer_gopath}"
# 		git clone "${_url}"
# 	done
# fi

go get -u github.com/alecthomas/gometalinter
gometalinter --install

# vs code wants these
go get -u github.com/acroca/go-symbols
go get -u github.com/cweill/gotests/...
go get -u github.com/fatih/gomodifytags
go get -u github.com/golang/lint/golint
go get -u github.com/ramya-rao-a/go-outline
go get -u github.com/newhook/go-symbols
go get -u github.com/nsf/gocode
go get -u github.com/rogpeppe/godef
go get -u github.com/tpng/gopkgs
go get -u github.com/zmb3/gogetdoc
go get -u sourcegraph.com/sqs/goreturns
go get -u github.com/sourcegraph/go-langserver

go get -u golang.org/x/tools/cmd/{cover,godoc,gorename,guru}
go get -u mvdan.cc/{unparam,sh/cmd/shfmt}
go get -u github.com/ChimeraCoder/gojson/gojson
go get -u github.com/ChimeraCoder/goxml
go get -u github.com/motemen/go-pocket/...
go get -u github.com/axw/gocov/gocov
go get -u gopkg.in/matm/v1/gocov-html
go get -u github.com/AlekSi/gocov-xml
go get -u github.com/shurcooL/markdownfmt
go get -u github.com/cespare/deplist
go get -u github.com/spf13/cobra/cobra
go get -u github.com/KyleBanks/depth/cmd/depth
go get -u honnef.co/go/tools/...
#go get -u github.com/ascarter/conductor
go get -u github.com/square/certigo
go get -u github.com/govend/govend
go get -u github.com/kyoh86/scopelint
go get -u github.com/davecheney/httpstat
go get -u github.com/uudashr/gopkgs/cmd/gopkgs
go get -u github.com/GoogleChromeLabs/simplehttp2server
go get -u golang.org/x/vgo
go get -u github.com/genuinetools/weather
go get -u github.com/kubernetes/kompose
go get -u github.com/GoogleContainerTools/skaffold/cmd/skaffold
go get -u github.com/FiloSottile/mkcert
go get -u github.com/golang/dep/cmd/dep
go get -u github.com/derekparker/delve/cmd/dlv
