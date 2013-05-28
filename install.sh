#!/usr/bin/env bash

set -o errexit
set -o xtrace
set -o nounset

mkdir -p ~/.emacs.d
ln -sf ~/my_src/dotfiles/init.el ~/.emacs.d/init.el

if [[ $(uname -s) == "Darwin" ]]; then
  _EMACS=/usr/local/bin/emacs
else
  _EMACS=/usr/bin/emacs
fi

if [[ $(uname -s) == "Darwin" ]]; then
  _BASH_RC=~/.bash_profile
else
  _BASH_RC=~/.bashrc
fi

ln -sf ~/my_src/dotfiles/bashrc ${_BASH_RC}
ln -s ~/my_src/dotfiles/gitconfig ~/.gitconfig
ln -s ~/my_src/dotfiles/gitignore_global ~/.gitignore
ln -s ~/my_src/dotfiles/inputrc ~/.inputrc
ln -s ~/my_src/dotfiles/tmux.conf ~/.tmux.conf

mkdir .irssi
ln -s ~/my_src/dotfiles/irssi_config ~/.irssi/config

ln -s ~/my_src/dotfiles/hgrc ~/.hgrc

if [[ $(uname -s) == "Darwin" ]]; then
  ln -s ~/my_src/dotfiles/osx ~/.osx
  ln -s ~/my_src/dotfiles/rtorrentrc ~/.rtorrent.rc
fi