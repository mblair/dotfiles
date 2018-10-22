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

#easy_install -U setuptools
#pip install -U pip
#pip install -U autopep8 virtualenv howdoi ramlfications pockyt proselint
#pip freeze | cut -d= -f1 | xargs pip install -U

if [[ -d ~/.oh-my-zsh ]]; then
	cd ~/.oh-my-zsh
	git pull
else
	git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
fi

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

#if [[ ! -x /usr/local/bin/npm ]]; then
#	brew install node
#fi

npm install -g npm
npm install -g grunt-cli redis-dump rickshaw jquery bootstrap react underscore d3 coffee-script webtorrent-cli js-yaml how2 eslint create-react-app parsimmon exif standard standard-format write-good fast-cli prettier js-beautify hyperapp wunderline ndb

${_HERE}/install.sh

#rm -rf ~/.emacs.d
#mkdir -p ~/.emacs.d/; ln -s ${_HERE}/init.el ~/.emacs.d
#/usr/local/bin/emacs --daemon

#brew tap caskroom/fonts

brew install swiftformat python python@2 kubernetes-cli
for _pkg in autojump bash ffmpeg git git-extras gnu-sed gnupg irssi jq s3cmd shellcheck ssh-copy-id the_silver_searcher tmux wget youtube-dl zsh findutils ghi nginx postgresql redis phantomjs pup vault wget httpdiff gifsicle zsh-completions wifi-password cowsay n jid unrar mtr ccat watch go hub httpstat clang-format ctop pngcheck curl git-lfs exa telnet pgformatter vim Nonchalant/appicon/appicon moreutils azure-cli macvim annie llvm golang-migrate; do
	_install_flags=""
	if [[ ${_pkg} == "curl" ]]; then
		_install_flags="--with-nghttp2"
	fi

	brew install ${_install_flags} ${_pkg} || brew upgrade ${_pkg}
done

#brew cask install java font-hack-nerd-font minikube keybase
brew cask install google-cloud-sdk emacs

${_HERE}/go_clean.sh

${_HERE}/update_rust.sh || true

if [[ -f ~/my_src/private/${_EMPLOYER}_updater.sh ]]; then
	. ~/my_src/private/${_EMPLOYER}_updater.sh
fi

${_HERE}/update_external.sh

brew prune
brew outdated
