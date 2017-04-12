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

brew tap caskroom/fonts
for _pkg in autojump bash ffmpeg git git-extras gnu-sed gnupg irssi jq macvim python python3 s3cmd shellcheck ssh-copy-id the_silver_searcher tmux wget youtube-dl zsh findutils ghi nginx postgresql redis phantomjs pup vault wget httpdiff gifsicle yarn zsh-completions wifi-password cowsay node jid unrar mtr ccat watch go hub heroku emacs httpstat clang-format ctop certbot pngcheck pandoc go-delve/delve/delve; do
	_install_flags=""
	if [[ ${_pkg} == "hub" ]]; then
		_install_flags="--devel"
	elif [[ ${_pkg} == "curl" ]]; then
		_install_flags="--with-nghttp2"
	elif [[ ${_pkg} == "emacs" ]]; then
		_install_flags="--with-cocoa"
	fi

	brew install ${_install_flags} ${_pkg} || brew upgrade ${_pkg}
done

brew cask install java font-hack-nerd-font

${_HERE}/go_clean.sh

${_HERE}/update_rust.sh

if [[ -f ~/my_src/private/${_EMPLOYER}_updater.sh ]]; then
	. ~/my_src/private/${_EMPLOYER}_updater.sh
fi

~/Dropbox\ \(Personal\)/experiments/update_external.sh

brew prune
brew outdated
