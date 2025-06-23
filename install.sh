#!/usr/bin/env bash

set -xueo pipefail

_HERE=$(
	cd $(dirname $0)
	pwd
)

_ME=$(whoami)

source ${_HERE}/vcs.bash

_GO_VER="1.24.4"

if [[ $(uname -s) == "Darwin" ]]; then
	if ! brew list --formula | grep wget; then
		brew install wget
	fi

	if [[ -d $HOME/Dropbox\ \(Persona\)/fonts/ ]]; then
		cp $HOME/Dropbox\ \(Personal\)/fonts/Hack-v*/* $HOME/Library/Fonts/
	fi
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
	if ! brew list --formula | grep hub; then
		brew install hub
	fi
	if ! brew list --formula | grep gnu-sed; then
		brew install gnu-sed
	fi
	gsed -i '1s/^/(setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3")\n/' ~/.emacs.d/init.el
	mkdir -p ~/.emacs.d/personal
	cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/personal/
	cat >>~/.emacs.d/personal/prelude-modules.el <<'EOF'
  ;;(require 'prelude-helm)
  ;;(require 'prelude-helm-everywhere)
  (require 'prelude-company)
  (require 'prelude-ido)
  (require 'prelude-go)
EOF
	ln -sf ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal

	mkdir -p ~/.config/karabiner/
	cp ~/my_src/dotfiles/karabiner.json ~/.config/karabiner/karabiner.json || true
else
	if ! which docker; then
		curl -sSL https://get.docker.com/ | sudo sh
	fi

	sudo apt update
	sudo apt -y dist-upgrade
	sudo apt -y install autojump silversearcher-ag git emacs-nox vim htop curl wget tmux jq ruby build-essential strace locate tcpdump shellcheck mtr traceroute iftop reptyr zsh whois moreutils
	sudo chsh -s /bin/zsh $_ME
	sudo apt -y purge unattended-upgrades lxd snapd lxcfs
fi

if [[ $(uname -s) == "Darwin" ]]; then
	_BASH_RC=~/.bash_profile
else
	_BASH_RC=~/.bashrc
fi

ln -sf ${_HERE}/bashrc ${_BASH_RC}

git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh || (cd ~/.oh-my-zsh/ && git pull)
mkdir -p ~/.zsh/completion/ ~/external_src/

if [[ $(uname -s) == "Linux" ]]; then
	if [[ $_ME == "root" ]]; then
		ln -sf ${_HERE}/zshrc /etc/zsh/zshrc
	else
		ln -sf ${_HERE}/zshrc ~/.zshrc
	fi
else
	ln -sf ${_HERE}/zshrc ~/.zshrc
fi

ln -sf ${_HERE}/gitconfig ~/.gitconfig
ln -sf ${_HERE}/npmrc ~/.npmrc
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

mkdir -p ~/.vim/after/ftplugin/
echo 'setlocal textwidth=0' >~/.vim/after/ftplugin/gitcommit.vim

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

	if [[ -d $HOME/.go/bin ]]; then
		export PATH=$HOME/.go/bin:$PATH
	fi

	if ! [[ $(go version) =~ go${_GO_VER} ]]; then
		cd
		curl -LO https://get.golang.org/$(uname)/go_installer && chmod +x go_installer && ./go_installer && rm go_installer
	fi

	type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)

    if ! which gh; then
	curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
		sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg &&
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
		sudo apt update &&
		sudo apt install gh -y
    fi

	cp /usr/share/zoneinfo/UTC /etc/localtime || true

	if pgrep snapd >/dev/null 2>&1; then
		sudo systemctl disable snapd
		sudo systemctl stop snapd
	fi

	cd
fi
