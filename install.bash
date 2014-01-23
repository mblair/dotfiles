#!/usr/bin/env bash

_HERE=$(cd $(dirname "$0"); pwd)

set -o errexit
set -o xtrace
set -o nounset

mkdir -p ~/.emacs.d
ln -sf ${_HERE}/init.el ~/.emacs.d/init.el

if [[ $(uname -s) == "Darwin" ]]; then
    _PREFIX=~/external_src
    _EMACS=/usr/local/bin/emacs
    _EMACS_C="${_EMACS}client"
else
    _PREFIX=/mnt/external/clones
    _EMACS=/usr/bin/emacs
    _EMACS_C="${_EMACS}client"
fi

${_EMACS_C} --eval "(progn (setq kill-emacs-hook 'nil) (kill-emacs))" || true

if [[ ! -d "${_PREFIX}/emacs-color-themes/.git" ]]; then
    cd ${_PREFIX}
    git clone https://github.com/owainlewis/emacs-color-themes
fi

if [[ ! -d "${_PREFIX}/emacs-deep-thought-theme/.git" ]]; then
    cd ${_PREFIX}
    git clone https://github.com/emacsfodder/emacs-deep-thought-theme
fi

if [[ ! -d "${_PREFIX}/phoenix-dark-pink/.git" ]]; then
    cd ${_PREFIX}
    git clone https://github.com/j0ni/phoenix-dark-pink
fi

if [[ ! -d "${_PREFIX}/emacs-powerline/.git" ]]; then
    cd ${_PREFIX}
    git clone https://github.com/jonathanchu/emacs-powerline
fi

${_EMACS} --daemon

if [[ $(uname -s) == "Darwin" ]]; then
    _BASH_RC=~/.bash_profile
else
    _BASH_RC=~/.bashrc
fi

ln -sf ${_HERE}/bashrc ${_BASH_RC}
ln -sf ${_HERE}/zshrc ~/.zshrc

git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh || (cd ~/.oh-my-zsh/ && git pull)

ln -sf ${_HERE}/gitconfig ~/.gitconfig
ln -sf ${_HERE}/gitignore_global ~/.gitignore
ln -sf ${_HERE}/inputrc ~/.inputrc
ln -sf ${_HERE}/tmux.conf ~/.tmux.conf

mkdir -p ${_HERE}/vim/autoload
cd ${_HERE}/vim/autoload
wget https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim

if [[ ! -h ~/.vim ]]; then
    ln -s ${_HERE}/vim ~/.vim
fi

ln -sf ${_HERE}/vimrc ~/.vimrc
cd ${_HERE}
git submodule update --init

cat > ~/.gemrc <<EOF
install: --no-rdoc --no-ri
EOF

ln -sf ${_HERE}/hgrc ~/.hgrc

if [[ $(uname -s) == "Darwin" ]]; then
    ln -sf ${_HERE}/osx ~/.osx
    ln -sf ${_HERE}/rtorrentrc ~/.rtorrent.rc
fi

if [[ ! -x /usr/bin/ec2metadata ]]; then
    mkdir -p ~/.irssi
    ln -sf ${_HERE}/irssi_config ~/.irssi/config
    ln -sf ${_HERE}/rtorrentrc ~/.rtorrent.rc
fi
