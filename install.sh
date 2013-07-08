#!/usr/bin/env bash

_HERE=$(cd $(dirname "$0"); pwd)

set -o errexit
set -o xtrace
set -o nounset

mkdir -p ~/.emacs.d
ln -sf ${_HERE}/init.el ~/.emacs.d/init.el

if [[ $(uname -s) == "Darwin" ]]; then
  _EMACS=/usr/local/bin/emacs
  _EMACS_C="${_EMACS}client"
else
  _EMACS=/usr/bin/emacs
  _EMACS_C="${_EMACS}client"
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
