#!/usr/bin/env bash

set -xueo pipefail

_EMPLOYER="figma"

_HERE=$(cd $(dirname $0); pwd)

gem update --system
gem update
gem install showoff exifr rethinkdb pry lunchy pygments.rb lolcat
gem cleanup --quiet

# TODO: figure out how to check to make sure we're using the virtualenv python here
easy_install-3.5 -U setuptools
pip install -U pip
pip install -U autopep8 virtualenv howdoi ramlfications pockyt proselint
pip freeze | cut -d= -f1 | xargs pip install -U

pip3 install -U pip
pip3 install gitsome

cd ~/.oh-my-zsh
git pull

cd ~/external_src/go-mode.el
git pull

brew update

cd ~/external_src/prelude
git clean -fdx
git checkout init.el
git pull
rm -rf ~/.emacs.d
ln -sf ~/external_src/prelude ~/.emacs.d
cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/
cat >> ~/.emacs.d/prelude-modules.el <<EOF
  (require 'prelude-helm)
  (require 'prelude-helm-everywhere)
  (require 'prelude-go)
EOF
ln -sf ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal

if [[ ! -x /usr/local/bin/npm ]]; then
    brew install node
fi

npm install -g grunt-cli redis-dump rickshaw jquery bootstrap react underscore d3 coffee-script webtorrent-cli js-yaml how2 jsfmt eslint bower create-react-app parsimmon exif standard standard-format write-good

#if [[ ! -x /usr/local/bin/emacs ]]; then
#  brew install --with-cocoa emacs
#fi

${_HERE}/install.bash

#rm -rf ~/.emacs.d
#mkdir -p ~/.emacs.d/; ln -s ${_HERE}/init.el ~/.emacs.d
#/usr/local/bin/emacs --daemon

${_HERE}/go_clean.bash

#${_HERE}/update_rust.bash

if which vagrant; then
    vagrant version
fi

brew install autojump bash cloc ffmpeg git git-extras gnu-sed gnupg hub irssi jq macvim multirust node python python3 rbenv s3cmd shellcheck ssh-copy-id the_silver_searcher tmux wget youtube-dl zsh findutils ghi keybase nginx postgresql redis phantomjs pup vault wget httpdiff gifsicle heroku yarn zsh-completions wifi-password cowsay
brew install curl --with-nghttp2

if [[ -f ~/my_src/private/${_EMPLOYER}_updater.bash ]]; then
    . ~/my_src/private/${_EMPLOYER}_updater.bash
fi

~/Dropbox/experiments/update_external.sh

brew outdated
