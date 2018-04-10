#!/usr/bin/env bash

set -xueo pipefail

_HERE=$(
	cd $(dirname $0)
	pwd
)

source ${_HERE}/vcs.bash

_HUB_VER="2.3.0-pre10"
_CTOP_VER="0.7.1"
_GO_VER="1.10.1"

if [[ $(uname -s) == "Darwin" ]]; then
	if ! brew list -1 | grep wget; then
		brew install wget
	fi

	if [[ -d /Applications/Xcode.app ]]; then
		cp /Applications/Xcode.app/Contents/SharedFrameworks/DVTKit.framework/Versions/A/Resources/fonts/* $HOME/Library/Fonts/
	fi

	if [[ -d $HOME/Dropbox\ \(Persona\)/fonts/ ]]; then
		cp $HOME/Dropbox\ \(Personal\)/fonts/Hack-v*/* $HOME/Library/Fonts/
	fi
else
	curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain nightly --no-modify-path -y -v
	${_HERE}/update_rust.sh
	if ! which docker; then
		curl -sSL https://get.docker.com/ | sh
	fi
	curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
	apt-get -y install nodejs
	curl -s https://s3.amazonaws.com/download.draios.com/stable/install-sysdig | bash
	apt-get update
	apt-get -y dist-upgrade
	apt-get -y install autojump silversearcher-ag git emacs25-nox vim htop curl wget tmux jq ruby python build-essential strace locate tcpdump shellcheck mtr traceroute iftop auditd reptyr zsh whois
	chsh -s /bin/zsh
	apt-get -y purge unattended-upgrades lxd snapd lxcfs
	npm install -g prettier

	_AUDITD_RESTART=0
	if ! sudo grep -q execve /etc/audit/audit.rules; then
		echo "-a exit,always -F arch=b64 -S execve" | sudo tee --append /etc/audit/audit.rules
		echo "-a exit,always -F arch=b32 -S execve" | sudo tee --append /etc/audit/audit.rules
		_AUDITD_RESTART=1
	fi

	if ! sudo grep -q 'active = yes' /etc/audisp/plugins.d/syslog.conf; then
		sudo sed -i '/active/ s/no/yes/' /etc/audisp/plugins.d/syslog.conf
		_AUDITD_RESTART=1
	fi

	if [[ $_AUDITD_RESTART -eq 1 ]]; then
		sudo service auditd restart
	fi
fi

if [[ $(uname -s) == "Darwin" ]]; then
	_BASH_RC=~/.bash_profile
else
	_BASH_RC=~/.bashrc
fi

ln -sf ${_HERE}/bashrc ${_BASH_RC}
mkdir -p ~/.gnupg
ln -sf ${_HERE}/gpg.conf ~/.gnupg/
ln -sf ${_HERE}/gpg-agent.conf ~/.gnupg/

if [[ -d ~/my_src/private ]]; then
	~/my_src/private/install.sh
fi

git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh || (cd ~/.oh-my-zsh/ && git pull)
mkdir -p ~/.zsh/completion/ ~/external_src/
git clone https://github.com/docker/cli ~/external_src/cli || (cd ~/external_src/cli && git pull)
ln -sf ~/external_src/cli/contrib/completion/zsh/_docker ~/.zsh/completion/

if [[ $(uname -s) == "Darwin" ]]; then
	ln -sf ${_HERE}/zshrc ~/.zshrc
else
	ln -sf ${_HERE}/zshrc /etc/zsh/zshrc
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

cat >~/.gemrc <<EOF
gem: --no-ri --no-rdoc
install: --no-rdoc --no-ri --no-document
EOF

if [[ $(uname -s) == "Darwin" ]]; then
	ln -sf ${_HERE}/osx ~/.osx
	ln -sf ${_HERE}/hyper.js ~/.hyper.js
fi

install_hub() {
	wget "https://github.com/github/hub/releases/download/v${_HUB_VER}/hub-linux-amd64-${_HUB_VER}.tgz"
	tar xf "hub-linux-amd64-${_HUB_VER}.tgz"
	rm "hub-linux-amd64-${_HUB_VER}.tgz"
	mv "hub-linux-amd64-${_HUB_VER}/bin/hub" /usr/local/bin
	rm -r "hub-linux-amd64-${_HUB_VER}"
}

if [[ $(uname -s) == "Linux" ]]; then
	mkdir -p ~/.irssi
	ln -sf ${_HERE}/irssi_config ~/.irssi/config

	if ! which hub; then
		install_hub
	else
		_installed_hub_ver=$(hub --version 2>&1 | /bin/grep hub | cut -d" " -f3)
		if [[ ${_installed_hub_ver} != ${_HUB_VER} ]]; then
			install_hub
		fi
	fi

	if [[ -d $HOME/.go/bin ]]; then
		export PATH=$HOME/.go/bin:$PATH
	fi

	if ! [[ $(go version) =~ go${_GO_VER} ]]; then
		cd
		curl -LO https://get.golang.org/$(uname)/go_installer && chmod +x go_installer && ./go_installer && rm go_installer
	fi

	cp /usr/share/zoneinfo/UTC /etc/localtime || true

	if pgrep snapd >/dev/null 2>&1; then
		systemctl disable snapd
		systemctl stop snapd
	fi

	wget https://github.com/bcicen/ctop/releases/download/v${_CTOP_VER}/ctop-${_CTOP_VER}-linux-amd64 -O /usr/local/bin/ctop
	chmod +x /usr/local/bin/ctop

	cd
	export GOPATH=$HOME/go
	mkdir -p go/src/github.com/mblair/matthewblair.net
	if [[ ! -d go/src/github.com/mblair/matthewblair.net/.git ]]; then
		git clone https://github.com/mblair/matthewblair.net go/src/github.com/mblair/matthewblair.net
		cd go/src/github.com/mblair/matthewblair.net
		make run
	else
		cd go/src/github.com/mblair/matthewblair.net
		git_update
		make restart
	fi
fi
