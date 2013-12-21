#!/usr/bin/env bash

set -o nounset
set -o xtrace
set -o nounset

gem update --system
gem update
gem cleanup --quiet

pip freeze | cut -d= -f1 | env grep -v git-remote-helpers | xargs pip install -U

#cabal update
#cabal install -v pandoc --upgrade-dependencies --dry-run

cd ~/.oh-my-zsh
git pull

# cd ~/rebuild_src/macvim
# git fetch
# git diff master origin/master --exit-code || (
# 	git merge --quiet origin/master
# 	brew reinstall --HEAD macvim
# )

# Not until ~24.4 is stable.
# cd ~/rebuild_src/emacs
# git fetch
# git diff master origin/master --exit-code || (
#     git merge --quiet origin/master
#     brew reinstall --HEAD --use-git-head --cocoa --srgb emacs
# )

# Not until RubyGems 2.2 is stable.
# brew reinstall --HEAD ruby-build rbenv
# cd ~/rebuild_src/ruby
# git fetch
# git diff trunk origin/trunk --exit-code || (
#     git merge --quiet origin/trunk && rbenv install --force 2.1.0-dev
# )

cd ~/rebuild_src/go
hg incoming && (
    hg clean --all
    hg checkout --clean tip
    hg pull -u
    export GOROOT_FINAL='/Users/matt/goroot'
    cd src
    bash make.bash --no-banner
    rm -rf ~/goroot/
    mkdir -p ~/goroot/
    cd ~/rebuild_src/go
    cp -R {bin,pkg,src} ~/goroot/
)

cd ~/external_src/go.tools
hg incoming && (
    hg clean --all
    hg checkout --clean tip
    hg pull -u
)

export GOROOT="$HOME/goroot"
export GOPATH="$HOME/gopath"
go get -u github.com/nsf/gocode
go get -u code.google.com/p/rog-go/exp/cmd/godef
go get -u code.google.com/p/go.tools/cmd/{cover,godoc,oracle,vet}

brew update

brew reinstall --HEAD git-extras hub
brew reinstall --HEAD --ignore-dependencies --fresh etcd

rm -rf ~/.emacs.d; mkdir -p ~/.emacs.d/; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d;
/usr/local/bin/emacs --daemon

npm update -g groc bower

brew outdated
