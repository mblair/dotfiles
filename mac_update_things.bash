#!/usr/bin/env bash

set -xueo pipefail

gem update --system
gem update
gem cleanup --quiet

easy_install -U setuptools
pip install -U pip
pip freeze | cut -d= -f1 | env grep -v git-remote-helpers | env grep -v wsgiref | xargs pip install -U

cd ~/.oh-my-zsh
git pull

# for oracle.el
cd ~/external_src/tools
git pull

cd ~/external_src/go-mode.el
git pull

export GOPATH="$HOME/gopath"
go get -u github.com/nsf/gocode
go get -u github.com/rogpeppe/godef
go get -u github.com/golang/lint/golint
go get -u github.com/kisielk/errcheck
go get -u github.com/tools/godep
go get -u rsc.io/grind
go get -u golang.org/x/tools/cmd/{cover,godoc,goimports,oracle,vet}

brew update
brew reinstall --HEAD hub rbenv ruby-build jq

go get -u github.com/coreos/etcd/etcdctl

rm -rf ~/.emacs.d
mkdir -p ~/.emacs.d/; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d

# cd ~/external_src/prelude
# git clean -fdx
# git pull
# ln -s ~/external_src/prelude ~/.emacs.d
# cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/
# cat >> ~/.emacs.d/prelude-modules.el <<EOF
# (require 'prelude-helm)
# (require 'prelude-helm-everywhere)
# (require 'prelude-go)
# (require 'prelude-clojure)
# EOF
# ln -sf ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal

npm install -g npm@latest
npm update -g groc bower yo grunt-cli generator-angular redis-dump

cd
bower install rickshaw d3 jquery bootstrap react chartjs

#cabal update
#cabal install pandoc
#cabal install -v pandoc --upgrade-dependencies --dry-run

lein ancient upgrade-profiles

vagrant up; vagrant ssh -c 'sudo apt-get update; sudo apt-get -y dist-upgrade; sudo apt-get -y install lxc-docker; sudo apt-get -y autoremove; sudo apt-get -y autoclean'; vagrant halt

~/my_src/dotfiles/install.bash

/usr/local/bin/emacs --daemon

heroku update
vagrant version

brew outdated
