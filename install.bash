#!/usr/bin/env bash

_HERE=$(cd $(dirname "$0"); pwd)

set -xueo pipefail

_HUB_VER="2.2.2"
_GO_VER="1.5.1"

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
else
    apt-get -y install autojump silversearcher-ag git zsh emacs24-nox vim-nox htop curl wget
    if ! which tmux; then
        apt-get -y install tmux
    fi
fi

if [[ ! -d "${_PREFIX}/gocode/.git" ]]; then
    cd ${_PREFIX}
    git clone https://github.com/nsf/gocode
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

if [[ ! -d "${_PREFIX}/emacs-powerline/.git" ]]; then
    cd ${_PREFIX}
    git clone https://github.com/jonathanchu/emacs-powerline
fi

if [[ ! -d "${_PREFIX}/ocean-terminal/.git" ]]; then
    cd ${_PREFIX}
    git clone https://github.com/mdo/ocean-terminal
fi

if [[ ! -f "${_PREFIX}/auto-fill-mode-inhibit.el" ]]; then
    cd ${_PREFIX}
    curl -Lskf 'https://alioth.debian.org/scm/viewvc.php/*checkout*/emacs-goodies-el/elisp/emacs-goodies-el/auto-fill-inhibit.el?root=pkg-goodies-el' > auto-fill-mode-inhibit.el
fi

if [[ $(uname -s) == "Darwin" ]]; then
    _BASH_RC=~/.bash_profile
else
    _BASH_RC=~/.bashrc
fi

ln -sf ${_HERE}/bashrc ${_BASH_RC}
ln -sf ${_HERE}/zshrc ~/.zshrc

if [[ -d ~/my_src/personal ]]; then
    ~/my_src/personal/install.bash
fi

git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh || (cd ~/.oh-my-zsh/ && git pull)

ln -sf ${_HERE}/gitconfig ~/.gitconfig
ln -sf ${_HERE}/gitignore_global ~/.gitignore
ln -sf ${_HERE}/inputrc ~/.inputrc
ln -sf ${_HERE}/tmux.conf ~/.tmux.conf

mkdir -p ${_HERE}/vim/autoload

if [[ -f ${_HERE}/vim/autoload/pathogen.vim ]]; then
    cd ${_HERE}/vim/autoload
    wget https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim
fi

if [[ ! -h ~/.vim ]]; then
    ln -s ${_HERE}/vim ~/.vim
fi

ln -sf ${_HERE}/vimrc ~/.vimrc
cd ${_HERE}
git submodule update --init

cat > ~/.gemrc <<EOF
install: --no-rdoc --no-ri --no-document
EOF

ln -sf ${_HERE}/hgrc ~/.hgrc

if [[ $(uname -s) == "Darwin" ]]; then
    ln -sf ${_HERE}/osx ~/.osx
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
    mv "hub-linux-amd64-${_HUB_VER}/hub" /usr/local/bin
    rm -r "hub-linux-amd64-${_HUB_VER}"

    if ! [[ $(go version) =~ ^go\ version\ go${_GO_VER}.*$ ]]; then
        cd
        wget https://godeb.s3.amazonaws.com/godeb-amd64.tar.gz
        tar xf godeb-amd64.tar.gz
        mv godeb /usr/local/bin
        godeb install ${_GO_VER}
        rm godeb-amd64.tar.gz
    fi

    cp /usr/share/zoneinfo/UTC /etc/localtime
fi
