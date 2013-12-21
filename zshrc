# -*- mode: shell-script -*-

# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="robbyrussell"
DISABLE_CORRECTION="true"

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

    export PATH="/usr/local/bin:$PATH"
    export PATH="$(brew --prefix)/sbin:$(brew --prefix)/bin:$PATH"

	  if [ -d "$HOME/.cabal/bin" ]; then
		    export PATH="$HOME/.cabal/bin:$PATH"
	  fi

	  export JAVA_HOME="$(/usr/libexec/java_home)"

    if [[ -f "/Users/matt/venv/bin/activate" ]]; then
        source /Users/matt/venv/bin/activate
        export PATH="/Users/matt/venv/bin:$PATH"
    fi

    if which rbenv >/dev/null; then
        eval "$(rbenv init -)"
    fi

elif [[ $(uname -s) == "Linux" ]]; then
    alias E="${_EMACS_C} -ct"
fi

export GOROOT="$HOME/goroot"
export GOPATH="$HOME/gopath"
PATH="${GOROOT}/bin:${GOPATH}/bin:${PATH}"

alias git="hub"
alias c="clear"
alias dc="cd"
alias l="ls -lha"
alias f="find . | grep -i"
alias p="ping google.com"
alias rscp='rsync -aP --no-whole-file --inplace'
alias rsmv='rscp --remove-source-files'

if [[ -f ~/my_src/personal/flip_sh ]]; then
    . ~/my_src/personal/flip_sh
fi

cleanup() {
	  ls | while read -r FILE
		do
		    mv -v "$FILE" `echo $FILE | tr ' ' '_' | tr -d '[{}(),\!]:"' | tr -d "\'" | tr '[A-Z]' '[a-z]' | tr '&' 'n' | sed 's/_-_/_/g'`
		done
}

export NODE_PATH="/usr/local/lib/node_modules"


fpath=(/usr/local/share/zsh-completions $fpath)

plugins=(git osx brew golang virtualenv tmux)

# ZSH_TMUX_AUTOSTART=true
# ZSH_TMUX_ITERM2=true

source $ZSH/oh-my-zsh.sh
