#!/usr/bin/env bash

set -xueo pipefail

_EMPLOYER="figma"

_HERE=$(
	cd $(dirname $0)
	pwd
)

#TODO: break these all up into functions, make them individually addressable

export PATH=/usr/local/bin:$PATH
if [[ $(which gem) == "$HOME/.rbenv/shims/gem" ]]; then
	gem update --system
	gem update
	gem install showoff exifr pry pygments.rb lolcat bundler
	gem cleanup --quiet
fi

if [[ $(which pip2) == "$HOME/venv/bin/pip2" ]]; then
	easy_install-2.7 -U setuptools
	pip2 install -U pip
	pip2 install -U autopep8 virtualenv howdoi ramlfications pockyt proselint
	pip2 freeze | cut -d= -f1 | xargs pip2 install -U
fi

cd ~/.oh-my-zsh
git pull

brew update

if [[ -d ~/external_src/prelude ]]; then
	cd ~/external_src/prelude
	git clean -fdx
	git checkout init.el
	git pull
else
	mkdir -p ~/external_src/prelude
	git clone https://github.com/bbatsov/prelude ~/external_src/prelude
fi

rm -rf ~/.emacs.d
ln -sf ~/external_src/prelude ~/.emacs.d
cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/
cat >>~/.emacs.d/prelude-modules.el <<'EOF'
  ;;(require 'prelude-helm)
  ;;(require 'prelude-helm-everywhere)
  (require 'prelude-company)
  (require 'prelude-ido)
  (require 'prelude-go)
  (require 'prelude-rust)
EOF
ln -sf ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal

if [[ ! -x /usr/local/bin/npm ]]; then
	brew install node
fi

npm install -g npm@next
npm install -g grunt-cli redis-dump rickshaw jquery bootstrap react underscore d3 coffee-script webtorrent-cli js-yaml how2 eslint create-react-app parsimmon exif standard standard-format write-good fast-cli prettier js-beautify hyperapp wunderline

#if [[ ! -x /usr/local/bin/emacs ]]; then
#  brew install --with-cocoa emacs
#fi

${_HERE}/install.sh

#rm -rf ~/.emacs.d
#mkdir -p ~/.emacs.d/; ln -s ${_HERE}/init.el ~/.emacs.d
#/usr/local/bin/emacs --daemon

brew tap caskroom/fonts
for _pkg in autojump bash ffmpeg git git-extras gnu-sed gnupg irssi jq macvim python python3 s3cmd shellcheck ssh-copy-id the_silver_searcher tmux wget youtube-dl zsh findutils ghi nginx postgresql redis phantomjs pup vault wget httpdiff gifsicle zsh-completions wifi-password cowsay n jid unrar mtr ccat watch go hub emacs httpstat clang-format ctop certbot pngcheck pandoc curl git-lfs exa docker-machine-driver-xhyve telnet azure-cli heroku pgformatter swiftformat go-delve/delve/delve Nonchalant/appicon/appicon; do
	_install_flags=""
	if [[ ${_pkg} == "hub" ]]; then
		_install_flags="--HEAD"
	elif [[ ${_pkg} == "curl" ]]; then
		_install_flags="--with-nghttp2"
	elif [[ ${_pkg} == "emacs" ]]; then
		_install_flags="--with-cocoa"
	elif [[ ${_pkg} == "go" ]]; then
		_install_flags="--devel"
	fi

	brew install ${_install_flags} ${_pkg} || brew upgrade ${_pkg}
done

brew cask install java font-hack-nerd-font minikube keybase

${_HERE}/go_clean.sh

${_HERE}/update_rust.sh

if [[ -f ~/my_src/private/${_EMPLOYER}_updater.sh ]]; then
	. ~/my_src/private/${_EMPLOYER}_updater.sh
fi

#~/Dropbox\ \(Personal\)/experiments/update_external.sh

brew prune
brew outdated
