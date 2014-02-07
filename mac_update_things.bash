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

cd ~/clj_src
for _inner in $(ls -1); do
    cd "~/clj_src/${_inner}"
    if git diff-index --quiet HEAD; then
        git pull
    else
        git stash
        git pull
        git stash pop
    fi
done

# cd ~/rebuild_src/macvim
# git fetch
# git diff master origin/master --exit-code || (
# 	git merge --quiet origin/master
# 	brew reinstall --HEAD macvim
# )


# cd ~/rebuild_src/ruby
# git fetch
# git diff trunk origin/trunk --exit-code || (
#     git merge --quiet origin/trunk && rbenv install --force 2.2.0-dev
# )

# cd ~/rebuild_src/go
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

# # for oracle.el
# cd ~/external_src/go.tools
# hg incoming && (
#     hg clean --all
#     hg checkout --clean tip
#     hg pull -u
# )

# cd ~/external_src/go-mode.el
# git pull

# export GOROOT="$HOME/goroot"
# export GOPATH="$HOME/gopath"
# go get -u github.com/nsf/gocode
# go get -u code.google.com/p/rog-go/exp/cmd/godef
# go get -u code.google.com/p/go.tools/cmd/{cover,godoc,goimports,oracle,vet}

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
brew reinstall --HEAD git-extras hub rbenv ruby-build

cd ~/rebuild_src/emacs
git fetch
git diff master origin/master --exit-code || (
    git merge --quiet origin/master
    brew reinstall --HEAD --use-git-head --cocoa emacs
    tic -o ~/.terminfo etc/e/eterm-color.ti
)

rm -rf ~/.emacs.d; mkdir -p ~/.emacs.d/; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d;
/usr/local/bin/emacs --daemon

npm update -g groc bower

cd
bower update

cabal update
cabal install pandoc
#cabal install -v pandoc --upgrade-dependencies --dry-run

brew outdated
