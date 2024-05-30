#!/usr/bin/env bash

set -xueo pipefail

export HOMEBREW_INSTALL_CLEANUP=1

_EMPLOYER="descript"

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

if [[ $(which docker >/dev/null 2>&1) ]]; then
	if [[ "$(du -ms ~/Library/Containers/com.docker.docker | awk '{print $1}')" -gt 25000 ]]; then
		docker rmi -f $(docker images -q) || true
	fi
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

#brew install node || brew upgrade node
#npm install -g webtorrent-cli # broken rn
#npm install -g grunt-cli redis-dump rickshaw jquery bootstrap react underscore d3 coffee-script js-yaml how2 eslint create-react-app parsimmon exif standard standard-format write-good fast-cli prettier js-beautify hyperapp wunderline ndb bash-language-server public-ip-cli corona-cli

${_HERE}/install.sh
# ${_HERE}/python.sh

#rm -rf ~/.emacs.d
#mkdir -p ~/.emacs.d/; ln -s ${_HERE}/init.el ~/.emacs.d
#/usr/local/bin/emacs --daemon

#brew tap caskroom/fonts

for _pkg in autojump bash ffmpeg git git-extras gnu-sed gnupg irssi jq s3cmd shellcheck ssh-copy-id ripgrep tmux wget youtube-dl zsh findutils ghi nginx postgresql@15 redis pup vault wget httpdiff gifsicle zsh-completions wifi-password cowsay jid mtr ccat watch go hub gh httpstat clang-format ctop pngcheck curl git-lfs exa telnet pgformatter moreutils azure-cli llvm imagemagick wireguard-tools iperf3 swiftformat python kubernetes-cli fd broot cppcheck openssh macvim loc gopls shfmt Nonchalant/appicon/appicon orbstack rustup-init minikube uutils-coreutils ijq hidetatz/tap/kubecolor; do
	brew install ${_pkg} || brew upgrade ${_pkg}
done

# Install random tools in Go and Node.
go install github.com/shurcooL/markdownfmt@latest
npm install -g git-removed-branches

# gcc is busted on catalina, needed for binwalk.
#brew install binwalk

#brew cask install java font-hack-nerd-font minikube keybase
brew install --cask google-cloud-sdk emacs

${_HERE}/update.sh --prefix external
${_HERE}/update.sh --prefix ${_EMPLOYER}

if [[ -f ~/my_src/private/install.sh ]]; then
	~/my_src/private/install.sh
fi

if [[ -f ~/my_src/private/${_EMPLOYER}_install.sh ]]; then
	~/my_src/private/${_EMPLOYER}_install.sh
fi

~/my_src/dotfiles/update_rust.sh

brew outdated
brew outdated --cask
