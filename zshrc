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

alias es="${_EMACS} --daemon"
alias ek="${_EMACS_C} --eval \"(progn (setq kill-emacs-hook 'nil) (kill-emacs))\""
alias ekk="kill -9 `ps -Ao 'pid,command' | grep '[e]macs' | awk '{print $1}'`"
alias eclean="rm -rf ~/.emacs.d; mkdir -p ~/.emacs.d; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d/init.el"
#alias eclean="rm -r ~/.emacs.d; (cd ~/external_src/prelude && git clean -fdx && git pull); ln -s ~/external_src/prelude ~/.emacs.d; cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/; echo \"(require 'prelude-helm)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-helm-everywhere)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-go)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-clojure)\" >> ~/.emacs.d/prelude-modules.el; ln -s ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal"
#alias eclean="rm -r ~/.emacs.d; (cd ~/external_src/prelude && git clean -fdx && git pull); ln -s ~/external_src/prelude ~/.emacs.d"

if [[ $(uname -s) == "Darwin" ]]; then
    alias v="vagrant"
    export VISUAL="${_EMACS_C} -c -n"
    #alias E="${_EMACS_C} -c -n"
    alias E='open -a /Applications/Emacs.app'

    export GIT_EDITOR='mvim -f'
    export EDITOR='mvim -f'
    export HOMEBREW_EDITOR='mvim -f'

    export PATH="$HOME/.cargo/bin:$PATH"

    # http://tug.org/mactex/faq/
	  if [ -d "/usr/texbin" ]; then
		    export PATH="/usr/texbin:$PATH"
	  fi

    export GOPATH="$HOME/gopath"
    export PATH="$PATH:$GOPATH/bin"
    if which go >/dev/null; then
        _goroot_bin="$(go env | grep GOROOT | perl -pe 's/^.*=\"(.*)\"/${1}/')/bin"
        export PATH="$PATH:${_goroot_bin}"
    fi

    # So we can find Homebrew.
    export PATH="/usr/local/bin:$PATH"

    export PATH="$(brew --prefix)/sbin:$PATH"

	  if [ -d "$HOME/.cabal/bin" ]; then
		    export PATH="$HOME/.cabal/bin:$PATH"
	  fi

    [[ -s `brew --prefix`/etc/autojump.sh ]] && . `brew --prefix`/etc/autojump.sh

    #export JAVA_HOME="$(/usr/libexec/java_home)"
    #alias jdk8="export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)"

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

alias b="brew"
alias git="hub"
alias c="clear"
alias dc="cd"
alias l="ls -lha"
alias f="find . | grep -i"
alias p="ping google.com"
alias rscp='rsync -aP --no-whole-file --inplace'
alias rsmv='rscp --remove-source-files'
alias myip="curl -s https://api.ipify.org\?format\=json | jq -r '.ip'"

if [[ -f ~/my_src/personal/figma_sh ]]; then
    . ~/my_src/personal/figma_sh
fi

cleanup() {
	  ls | while read -r FILE
		do
		    mv -v "$FILE" `echo $FILE | tr ' ' '_' | tr -d '[{}(),\!]:"' | tr -d "\'" | tr '[A-Z]' '[a-z]' | tr '&' 'n' | sed 's/_-_/_/g'`
		done
}

export NODE_PATH="/usr/local/lib/node_modules"

fpath=(/usr/local/share/zsh-completions $fpath)

plugins=(git osx brew golang virtualenv tmux vagrant github)

# ZSH_TMUX_AUTOSTART=true
# ZSH_TMUX_ITERM2=true

source $ZSH/oh-my-zsh.sh
### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

export PATH="$HOME/.multirust/toolchains/nightly/cargo/bin:${PATH}"

if [[ -d $HOME/bin ]]; then
    export PATH="$HOME/bin:${PATH}"
fi

export GPG_TTY="$(tty)"

if [[ -f "$HOME/.gpg-agent-info" ]]; then
    . "$HOME/.gpg-agent-info"
    export GPG_AGENT_INFO

fi

if which "gpg-agent" >"/dev/null" 2>"/dev/null" && ! gpg-agent >/dev/null 2>&1; then
    eval "$(gpg-agent --daemon --disable-scdaemon --write-env-file "$HOME/.gpg-agent-info")"
fi

# from @ryankaplan
# -r 10 reduces frame rate from 25 to 10
# -s 600 x 400 tells max width and height
# --delay=3 means 30ms between each gif
# --optimize=3 says use slowest optimization for best file size
gif() {
    ffmpeg -i $1 -pix_fmt rgb24 -r 20 -f gif - | gifsicle --optimize=3 --delay=3 > $2
}
