#!/usr/bin/env bash

set -o errexit
set -o xtrace
set -o nounset

mkdir ~/.emacs.d
ln -s ~/my_src/dotfiles/init.el ~/.emacs.d/init.el
/usr/bin/emacs --daemon

ln -sf ~/my_src/dotfiles/bashrc ~/.bashrc
ln -s ~/my_src/dotfiles/gitconfig ~/.gitconfig
ln -s ~/my_src/dotfiles/gitignore_global ~/.gitignore
ln -s ~/my_src/dotfiles/inputrc ~/.inputrc
ln -s ~/my_src/dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/my_src/dotfiles/osx ~/.osx
ln -s ~/my_src/dotfiles/rtorrentrc ~/.rtorrent.rc
ln -s ~/my_src/dotfiles/hgrc ~/.hgrc
