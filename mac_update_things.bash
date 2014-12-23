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

# for oracle.el
cd ~/external_src/tools
git pull

cd ~/external_src/go-mode.el
git pull

# export GOROOT="$HOME/goroot"
export GOPATH="$HOME/gopath"
go get -u github.com/nsf/gocode
go get -u code.google.com/p/rog-go/exp/cmd/godef
go get -u github.com/golang/lint/golint
go get -u github.com/kisielk/errcheck
go get -u github.com/3rf/go-unused-funcs
go get -u github.com/tools/godep
go get -u golang.org/x/tools/cmd/{cover,godoc,goimports,oracle,vet}

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

# cd ~/rebuild_src/emacs
# git fetch
# git diff master origin/master --exit-code || (
#     git merge --quiet origin/master
#     brew reinstall --HEAD --use-git-head --cocoa emacs
#     tic -o ~/.terminfo etc/e/eterm-color.ti
# )

if [[ -d ~/external_src/prelude ]]; then
    cd ~/external_src/prelude
    git clean -fdx
    git pull
else
    cd ~/external_src
    git clone https://github.com/bbatsov/prelude
fi


rm -rf ~/.emacs.d
mkdir -p ~/.emacs.d/; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d

# ln -s ~/external_src/prelude ~/.emacs.d
# cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/
# cat >> ~/.emacs.d/prelude-modules.el <<EOF
# (require 'prelude-helm)
# (require 'prelude-helm-everywhere)
# (require 'prelude-go)
# (require 'prelude-clojure)
# EOF
# ln -s ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal

/usr/local/bin/emacs --daemon

npm install -g npm
npm update -g groc bower yo grunt-cli generator-angular

cd
bower install rickshaw d3 jquery bootstrap react chartjs

#cabal update
#cabal install pandoc
#cabal install -v pandoc --upgrade-dependencies --dry-run

lein ancient upgrade-profiles

vagrant up; vagrant ssh -c 'sudo apt-get update; sudo apt-get -y dist-upgrade'; vagrant suspend

brew outdated
