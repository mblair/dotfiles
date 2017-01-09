#!/usr/bin/env bash

set -xueo pipefail

_EMPLOYER="figma"

_HERE=$(
	cd $(dirname $0)
	pwd
)

gem update --system
gem update
gem install showoff exifr pry pygments.rb lolcat bundler
gem cleanup --quiet

# TODO: figure out how to check to make sure we're using the virtualenv python here
easy_install -U setuptools
pip install -U pip
pip install -U autopep8 virtualenv howdoi ramlfications pockyt proselint
pip freeze | cut -d= -f1 | xargs pip install -U

cd ~/.oh-my-zsh
git pull

brew update

cd ~/external_src/prelude
git clean -fdx
git checkout init.el
git pull
rm -rf ~/.emacs.d
ln -sf ~/external_src/prelude ~/.emacs.d
cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/
cat >>~/.emacs.d/prelude-modules.el <<EOF
  (require 'prelude-helm)
  (require 'prelude-helm-everywhere)
  (require 'prelude-go)
EOF
ln -sf ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal

if [[ ! -x /usr/local/bin/npm ]]; then
	brew install node
fi

yarn global add grunt-cli redis-dump rickshaw jquery bootstrap react underscore d3 coffee-script webtorrent-cli js-yaml how2 jsfmt eslint bower create-react-app parsimmon exif standard standard-format write-good fast-cli js-beautify

#if [[ ! -x /usr/local/bin/emacs ]]; then
#  brew install --with-cocoa emacs
#fi

${_HERE}/install.sh

#rm -rf ~/.emacs.d
#mkdir -p ~/.emacs.d/; ln -s ${_HERE}/init.el ~/.emacs.d
#/usr/local/bin/emacs --daemon

brew install autojump bash loc ffmpeg git git-extras gnu-sed gnupg irssi jq macvim python python3 s3cmd shellcheck ssh-copy-id the_silver_searcher tmux wget youtube-dl zsh findutils ghi keybase nginx postgresql redis phantomjs pup vault wget httpdiff gifsicle yarn zsh-completions wifi-password cowsay node jid ripgrep unrar mtr ccat watch
brew install --devel go
brew install --HEAD hub
brew install --with-toolchain --with-all-targets llvm
brew install curl --with-nghttp2
brew cask install hab hyper emacs
brew install go-delve/delve/delve

${_HERE}/go_clean.sh

${_HERE}/update_rust.sh

if [[ -f ~/my_src/private/${_EMPLOYER}_updater.sh ]]; then
	. ~/my_src/private/${_EMPLOYER}_updater.sh
fi

~/Dropbox\ \(Personal\)/experiments/update_external.sh

brew prune
brew outdated
