#!/usr/bin/env bash

set -xueo pipefail

_HERE=$(cd $(dirname $0); pwd)

gem update --system
gem update
gem install showoff exifr rethinkdb riemann-tools riemann-client pry lunchy puppet puppet-lint
gem cleanup --quiet

# check to make sure we're using the virtualenv python here
easy_install -U setuptools
pip install -U pip
pip install -U s3cmd autopep8 virtualenv howdoi
pip freeze | cut -d= -f1 | env grep -v git-remote-helpers | env grep -v wsgiref | xargs pip install -U

cd ~/.oh-my-zsh
git pull

cd ~/external_src/go-mode.el
git pull

brew update

#cd ~/external_src/prelude
#git clean -fdx
#git pull
#ln -sf ~/external_src/prelude ~/.emacs.d
#cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/
#cat >> ~/.emacs.d/prelude-modules.el <<EOF
#  (require 'prelude-helm)
#  (require 'prelude-helm-everywhere)
#  (require 'prelude-go)
#  (require 'prelude-clojure)
#EOF
#ln -sf ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal

if [[ ! -x /usr/local/bin/npm ]]; then
    brew install node
fi
npm install -g grunt-cli redis-dump rickshaw jquery bootstrap react underscore d3 coffee-script torrent js-yaml how2 jsfmt

#cabal update
#cabal install pandoc
#cabal install -v pandoc --upgrade-dependencies --dry-run

if [[ ! -x /usr/local/bin/emacs ]]; then
  brew install --with-cocoa emacs
fi

${_HERE}/install.bash

if which lein; then
    lein ancient upgrade-profiles
fi

rm -rf ~/.emacs.d
mkdir -p ~/.emacs.d/; ln -s ${_HERE}/init.el ~/.emacs.d
/usr/local/bin/emacs --daemon

${_HERE}/go_clean.bash

if which heroku; then
  heroku update
fi

vagrant version

brew outdated
