# -*- mode: shell-script -*-

_HERE=$(cd $(dirname $(readlink ~/.zshrc)); pwd)

ZSH=$HOME/.oh-my-zsh
ZSH_THEME="robbyrussell"
DISABLE_CORRECTION=true
DISABLE_UPDATE_PROMPT=true
DISABLE_AUTO_UPDATE=true

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
alias ekk="kill -9 `ps -Ao 'pid,command' | grep '[e]macs' | awk '{print $1}'`"
#alias eclean="rm -rf ~/.emacs.d; mkdir -p ~/.emacs.d/; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d;"
alias eclean="rm -r ~/.emacs.d; (cd ~/external_src/prelude && git clean -fdx && git pull); ln -s ~/external_src/prelude ~/.emacs.d; cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/; echo \"(require 'prelude-helm)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-helm-everywhere)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-go)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-clojure)\" >> ~/.emacs.d/prelude-modules.el; ln -s ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal"

if [[ $(uname -s) == "Darwin" ]]; then
    export VISUAL="${_EMACS_C} -c -n"
    alias E="${_EMACS_C} -c -n"

    export GIT_EDITOR='mvim -f'

    # For etcd.
    export PATH="$HOME/bin:$PATH"

    # http://tug.org/mactex/faq/
	  if [ -d "/usr/texbin" ]; then
		    export PATH="/usr/texbin:$PATH"
	  fi

    export GOPATH="$HOME/gopath"
    export PATH="$PATH:$GOPATH/bin"
    _goroot_bin="$(go env | grep GOROOT | perl -pe 's/^.*=\"(.*)\"/${1}/')/bin"
    export PATH="$PATH:${_goroot_bin}"

    # So we can find Homebrew.
    export PATH="/usr/local/bin:$PATH"

    export PATH="$(brew --prefix)/sbin:$PATH"

	  if [ -d "$HOME/.cabal/bin" ]; then
		    export PATH="$HOME/.cabal/bin:$PATH"
	  fi

    [[ -s `brew --prefix`/etc/autojump.sh ]] && . `brew --prefix`/etc/autojump.sh

	  export JAVA_HOME="$(/usr/libexec/java_home)"
    alias jdk6="export JAVA_HOME=$(/usr/libexec/java_home -v 1.6)"
    alias jdk7="export JAVA_HOME=$(/usr/libexec/java_home -v 1.7)"
    alias jdk8="export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)"

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

plugins=(git osx brew golang virtualenv tmux vagrant)

# ZSH_TMUX_AUTOSTART=true
# ZSH_TMUX_ITERM2=true

source $ZSH/oh-my-zsh.sh
### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"
