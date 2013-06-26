# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

ZSH_THEME="robbyrussell"

# Comment this out to disable bi-weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment to change how often before auto-updates occur? (in days)
# export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want to disable command autocorrection
# DISABLE_CORRECTION="true"

source $ZSH/oh-my-zsh.sh
plugins=(git brew osx)

# Everything after this line has been moved from my .bashrc, so it's portable.

export PATH="/usr/local/bin:$PATH"
export GOPATH="$HOME/golang"

# rbenv Ruby.
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

alias c="clear"

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
elif [[ $(uname -s) == "Linux" ]]; then
    alias E="${_EMACS_C} -ct"
fi
