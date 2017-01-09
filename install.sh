#!/usr/bin/env bash

_HERE=$(
	cd $(dirname "$0")
	pwd
)

set -xueo pipefail

_HUB_VER="2.3.0-pre8"
_GO_VER="1.8beta2"

if [[ $(uname -s) == "Darwin" ]]; then
	if ! brew list -1 | grep wget; then
		brew install wget
	fi

	cp /Applications/Xcode.app/Contents/SharedFrameworks/DVTKit.framework/Versions/A/Resources/fonts/* $HOME/Library/Fonts/
	cp $HOME/Dropbox\ \(Personal\)/fonts/Hack-v*/* $HOME/Library/Fonts/
else
	curl -sSL https://get.docker.com/ | sh
	curl -s https://s3.amazonaws.com/download.draios.com/stable/install-sysdig | bash
	curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
	echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
	apt-get update
	apt-get -y dist-upgrade
	apt-get -y install autojump silversearcher-ag git emacs24-nox vim-nox htop curl wget tmux jq ruby python build-essential nodejs-legacy strace locate tcpdump yarn shellcheck mtr traceroute
	yarn global add js-beautify
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

if [[ $(uname -s) == "Darwin" ]]; then
	git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh || (cd ~/.oh-my-zsh/ && git pull)
	ln -sf ${_HERE}/zshrc ~/.zshrc
fi

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

if [[ $(uname -s) == "Linux" ]]; then
	mkdir -p ~/.irssi
	ln -sf ${_HERE}/irssi_config ~/.irssi/config

	_installed_hub_ver=$(hub --version 2>&1 | /bin/grep hub | cut -d" " -f3)
	if [[ ${_installed_hub_ver} != ${_HUB_VER} ]]; then
		cd
		wget "https://github.com/github/hub/releases/download/v${_HUB_VER}/hub-linux-amd64-${_HUB_VER}.tgz"
		tar xf "hub-linux-amd64-${_HUB_VER}.tgz"
		rm "hub-linux-amd64-${_HUB_VER}.tgz"
		mv "hub-linux-amd64-${_HUB_VER}/bin/hub" /usr/local/bin
		rm -r "hub-linux-amd64-${_HUB_VER}"
	fi

	if ! [[ $(go version) =~ go${_GO_VER} ]]; then
		cd
		wget https://godeb.s3.amazonaws.com/godeb-amd64.tar.gz
		tar xf godeb-amd64.tar.gz
		mv godeb /usr/local/bin
		godeb install ${_GO_VER}
		rm godeb-amd64.tar.gz go*.deb
	fi

	cp /usr/share/zoneinfo/UTC /etc/localtime || true

	systemctl disable snapd
	systemctl stop snapd
fi

curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain nightly --no-modify-path -y -v
rustup update
for _pkg in racer rustfmt; do
	${_pkg} --version || {
		cargo install ${_pkg}
		break
	}
	_installed_version=$(${_pkg} --version | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	_latest_version=$(cargo search ${_pkg} | ruby -e 'input = gets(nil); puts /[0-9\.]+/.match(input)')
	if [[ $_installed_version < $_latest_version ]]; then
		cargo uninstall "${_pkg}"
		cargo install "${_pkg}"
	fi
done
