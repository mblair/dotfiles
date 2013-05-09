#!/usr/bin/env bash

set -o errexit
set -o xtrace
set -o nounset

mkdir ~/.emacs.d
ln -s ~/dotfiles/init.el ~/.emacs.d/init.el
/usr/bin/emacs --daemon

ln -sf ~/dotfiles/bashrc ~/.bashrc
ln -s ~/dotfiles/gitconfig ~/.gitconfig
ln -s ~/dotfiles/gitignore_global ~/.gitignore
ln -s ~/dotfiles/inputrc ~/.inputrc
ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
