# -*- mode: shell-script -*-

# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="robbyrussell"
DISABLE_CORRECTION="true"

fpath=(/usr/local/share/zsh-completions $fpath)

plugins=(git osx brew golang tmux)
#github)

if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

# ZSH_TMUX_AUTOSTART=true
# ZSH_TMUX_ITERM2=true

source $ZSH/oh-my-zsh.sh

# Everything after this line has been moved from my .bashrc, so it's portable.

# Emacs stuff.

if [[ $(uname -s) == "Darwin" ]]; then
    _EMACS=/usr/local/bin/emacs
    _EMACS_C="${_EMACS}client"
else
    _EMACS=/usr/bin/emacs
    _EMACS_C="${_EMACS}client"
fi

export EDITOR='emacsclient -ct'

alias es="${_EMACS} --daemon"
alias ek="${_EMACS_C} --eval \"(progn (setq kill-emacs-hook 'nil) (kill-emacs))\""
if [[ $(uname -s) == "Darwin" ]]; then
    export VISUAL="${_EMACS_C} -c -n"
    alias E="${_EMACS_C} -c -n"
    export PATH="/usr/local/sbin:/usr/local/bin:$PATH"

	  if [ -d "$HOME/.cabal/bin" ]; then
		    export PATH="$HOME/.cabal/bin:$PATH"
	  fi

    if [[ -f "/Users/mblair/venv/bin/activate" ]]; then
        source /Users/mblair/venv/bin/activate
        export PATH="/Users/mblair/venv/bin:$PATH"
    fi

elif [[ $(uname -s) == "Linux" ]]; then
    alias E="${_EMACS_C} -ct"
fi

export GOPATH="$HOME/golang"
# rbenv Ruby.

alias c="clear"
alias l="ls -lha"
alias f="find . -type f | grep -i"

. ~/my_src/personal/flip_sh
