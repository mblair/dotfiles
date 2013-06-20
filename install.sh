#!/usr/bin/env bash

_HERE=$(cd $(dirname "$0"); pwd)

set -o errexit
set -o xtrace
set -o nounset

mkdir -p ~/.emacs.d
ln -sf ${_HERE}/init.el ~/.emacs.d/init.el

if [[ $(uname -s) == "Darwin" ]]; then
  _EMACS=/usr/local/bin/emacs
else
  _EMACS=/usr/bin/emacs
fi

${_EMACS} --daemon

if [[ $(uname -s) == "Darwin" ]]; then
  _BASH_RC=~/.bash_profile
else
  _BASH_RC=~/.bashrc
fi

ln -sf ${_HERE}/bashrc ${_BASH_RC}
ln -s ${_HERE}/gitconfig ~/.gitconfig
ln -s ${_HERE}/gitignore_global ~/.gitignore
ln -s ${_HERE}/inputrc ~/.inputrc
ln -s ${_HERE}/tmux.conf ~/.tmux.conf

ln -s ${_HERE}/hgrc ~/.hgrc

if [[ $(uname -s) == "Darwin" ]]; then
  ln -s ${_HERE}/osx ~/.osx
  ln -s ${_HERE}/rtorrentrc ~/.rtorrent.rc
fi

if [[ ! -x /usr/bin/ec2metadata ]]; then
    mkdir ~/.irssi
    ln -s ${_HERE}/irssi_config ~/.irssi/config
fi
