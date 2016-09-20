#!/usr/bin/env bash

set -xueo pipefail

export GOPATH="$HOME/gopath"
rm -rf "$GOPATH"

cd
go get -u github.com/nsf/gocode
go get -u github.com/rogpeppe/godef
go get -u github.com/golang/lint/golint
go get -u github.com/kisielk/errcheck
go get -u github.com/tools/godep
go get -u github.com/govend/govend
go get -u github.com/FiloSottile/gvt
go get -u golang.org/x/tools/cmd/{cover,goimports,gorename,guru}
go get -u github.com/ChimeraCoder/gojson/gojson
go get -u github.com/jstemmer/gotags
go get -u github.com/newhook/go-symbols
go get -u github.com/lukehoban/go-outline
go get -u github.com/tpng/gopkgs
go get -u github.com/sqs/goreturns
go get -u github.com/alecthomas/gometalinter
go get -u github.com/motemen/go-pocket/...
gometalinter --install
