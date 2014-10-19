#!/usr/bin/env bash

set -o nounset
set -o xtrace
set -o nounset

gem update --system
gem update
gem cleanup --quiet

pip freeze | cut -d= -f1 | env grep -v git-remote-helpers | env grep -v wsgiref | xargs pip install -U

cd ~/.oh-my-zsh
git pull

cd ~/rebuild_src/macvim
git fetch
git diff master origin/master --exit-code || (
	git merge --quiet origin/master
    brew reinstall --HEAD macvim
)

# cd ~/rebuild_src/ruby
# git fetch
# git diff trunk origin/trunk --exit-code || (
#     git merge --quiet origin/trunk && rbenv install --force 2.2.0-dev
# )

cd ~/rebuild_src/go
hg pull -u

# hg incoming && (
#     hg clean --all
#     hg checkout --clean tip
#     hg pull -u
#     export GOROOT_FINAL='/Users/matt/goroot'
#     cd src
#     bash make.bash --no-banner
#     cd ~/rebuild_src/go

#     # TODO: rsync?
#     rm -rf ~/goroot/*
#     cp -R {bin,pkg,src} ~/goroot/
# )

# for oracle.el
cd ~/external_src/go.tools
hg incoming && (
    hg clean --all
    hg checkout --clean tip
    hg pull -u
)

cd ~/external_src/go-mode.el
git pull

# export GOROOT="$HOME/goroot"
export GOPATH="$HOME/gopath"
go get -u github.com/nsf/gocode
go get -u code.google.com/p/rog-go/exp/cmd/godef
go get -u github.com/golang/lint/golint
go get -u github.com/kisielk/errcheck
go get -u github.com/3rf/go-unused-funcs
go get -u code.google.com/p/go.tools/cmd/{cover,godoc,goimports,oracle,vet}

# cd ~/rebuild_src/etcd
# git fetch
# git diff master origin/master --exit-code || (
#     git clean -fdx
#     git checkout master
#     git reset --hard
#     git merge --quiet origin/master
#     export GOPATH=$(pwd)
#     ./build
#     mv etcd ~/bin/
# )

brew update
brew reinstall --HEAD hub rbenv ruby-build etcdctl

cd ~/rebuild_src/emacs
git fetch
# git diff master origin/master --exit-code || (
#     git merge --quiet origin/master
#     brew reinstall --HEAD --use-git-head --cocoa emacs
#     tic -o ~/.terminfo etc/e/eterm-color.ti
# )

rm -rf ~/.emacs.d; mkdir -p ~/.emacs.d/; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d;
#rm -r ~/.emacs.d; cd ~/external_src/prelude && git pull; ln -s ~/external_src/prelude ~/.emacs.d
/usr/local/bin/emacs --daemon

npm update -g groc bower yo grunt-cli generator-angular npm chartjs

cd
bower install rickshaw d3 jquery bootstrap react

#cabal update
#cabal install pandoc
#cabal install -v pandoc --upgrade-dependencies --dry-run

lein ancient upgrade-profiles

brew outdated
