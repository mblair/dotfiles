#!/usr/bin/env bash

_HERE=$(
	cd $(dirname "$0")
	pwd
)

set -xueo pipefail

_HUB_VER="2.3.0-pre8"
_GO_VER="1.8beta2"

if [[ $(uname -s) == "Darwin" ]]; then
	_PREFIX=~/external_src
	mkdir -p ${_PREFIX}
else
	_PREFIX=/mnt/external/clones
fi

mkdir -p ${_PREFIX}

if [[ $(uname -s) == "Darwin" ]]; then
	if ! brew list -1 | grep wget; then
		brew install wget
	fi

	cp /Applications/Xcode.app/Contents/SharedFrameworks/DVTKit.framework/Versions/A/Resources/fonts/* $HOME/Library/Fonts/
	cp $HOME/Dropbox\ \(Personal\)/fonts/Hack-v*/* $HOME/Library/Fonts/
else
	curl -sSL https://get.docker.com/ | sh
	curl -s https://s3.amazonaws.com/download.draios.com/stable/install-sysdig | sudo bash
	apt-get update
	apt-get -y dist-upgrade
	apt-get -y install autojump silversearcher-ag git zsh emacs24-nox vim-nox htop curl wget tmux jq ruby python build-essential
fi

if [[ ! -d "${_PREFIX}/go-mode.el/.git" ]]; then
	cd ${_PREFIX}
	git clone https://github.com/dominikh/go-mode.el
fi

if [[ ! -d "${_PREFIX}/prelude/.git" ]]; then
	cd ${_PREFIX}
	git clone https://github.com/bbatsov/prelude
fi

if [[ ! -d "${_PREFIX}/emacs-color-themes/.git" ]]; then
	cd ${_PREFIX}
	git clone https://github.com/owainlewis/emacs-color-themes
fi

if [[ ! -d "${_PREFIX}/emacs-deep-thought-theme/.git" ]]; then
	cd ${_PREFIX}
	git clone https://github.com/emacsfodder/emacs-deep-thought-theme
fi

if [[ ! -d "${_PREFIX}/ocean-terminal/.git" ]]; then
	cd ${_PREFIX}
	git clone https://github.com/mdo/ocean-terminal
fi

if [[ $(uname -s) == "Darwin" ]]; then
	_BASH_RC=~/.bash_profile
else
	_BASH_RC=~/.bashrc
fi

ln -sf ${_HERE}/bashrc ${_BASH_RC}
mkdir -p ~/.gnupg
ln -sf ${_HERE}/gpg.conf ~/.gnupg/

if [[ -d ~/my_src/private ]]; then
	~/my_src/private/install.sh
fi

git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh || (cd ~/.oh-my-zsh/ && git pull)
ln -sf ${_HERE}/zshrc ~/.zshrc
#ln -sf ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc

ln -sf ${_HERE}/gitconfig ~/.gitconfig
ln -sf ${_HERE}/gitignore_global ~/.gitignore_global
ln -sf ${_HERE}/inputrc ~/.inputrc
ln -sf ${_HERE}/tmux.conf ~/.tmux.conf

mkdir -p ${_HERE}/vim/autoload

if [[ ! -f ${_HERE}/vim/autoload/pathogen.vim ]]; then
	cd ${_HERE}/vim/autoload
	wget https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim
fi

if [[ ! -L ~/.vim ]]; then
	ln -s ${_HERE}/vim ~/.vim
fi

ln -sf ${_HERE}/vimrc ~/.vimrc
cd ${_HERE}
git submodule update --init

cat >~/.gemrc <<EOF
gem: --no-ri --no-rdoc
install: --no-rdoc --no-ri --no-document
EOF

if [[ $(uname -s) == "Darwin" ]]; then
	ln -sf ${_HERE}/osx ~/.osx
	ln -sf ${_HERE}/hyper.js ~/.hyper.js
fi

mkdir -p ~/.irssi
ln -sf ${_HERE}/irssi_config ~/.irssi/config

mkdir -p ~/.lein
ln -sf ${_HERE}/lein_profiles.clj ~/.lein/profiles.clj

if [[ $(uname -s) == "Linux" ]]; then
	cd
	wget "https://github.com/github/hub/releases/download/v${_HUB_VER}/hub-linux-amd64-${_HUB_VER}.tgz"
	tar xf "hub-linux-amd64-${_HUB_VER}.tgz"
	rm "hub-linux-amd64-${_HUB_VER}.tgz"
	mv "hub-linux-amd64-${_HUB_VER}/bin/hub" /usr/local/bin
	rm -r "hub-linux-amd64-${_HUB_VER}"

	if ! [[ $(go version) =~ go${_GO_VER} ]]; then
		cd
		wget https://godeb.s3.amazonaws.com/godeb-amd64.tar.gz
		tar xf godeb-amd64.tar.gz
		mv godeb /usr/local/bin
		godeb install ${_GO_VER}
		rm godeb-amd64.tar.gz
	fi

	cp /usr/share/zoneinfo/UTC /etc/localtime || true

    systemctl disable snapd
    systemctl stop snapd
fi

curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain nightly --no-modify-path -y -v
