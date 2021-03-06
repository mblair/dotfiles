_EMPLOYER="google"

if [[ $(uname -s) == "Darwin" ]]; then
	_EMACS=/usr/local/bin/emacs
	_EMACS_C="${_EMACS}client"
	#_EMACS="/Applications/Emacs.app/Contents/MacOS/Emacs --daemon"
	#_EMACS_C="/Applications/Emacs.app/Contents/MacOS/bin/emacsclient"
else
	_EMACS=/usr/bin/emacs
	_EMACS_C="${_EMACS}client"
fi

ZSH=$HOME/.oh-my-zsh
ZSH_THEME="robbyrussell"
DISABLE_CORRECTION=true
DISABLE_UPDATE_PROMPT=true
DISABLE_AUTO_UPDATE=true

plugins=(git osx github virtualenv docker cargo terraform)
fpath=(/usr/local/share/zsh-completions $fpath)
source $ZSH/oh-my-zsh.sh

alias es="${_EMACS} --daemon"
alias ek="${_EMACS_C} --eval \"(progn (setq kill-emacs-hook 'nil) (kill-emacs))\""
alias ekk="kill -9 $(ps -Ao 'pid,command' | grep '[e]macs' | awk '{print $1}')"
#alias eclean="rm -rf ~/.emacs.d; mkdir -p ~/.emacs.d; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d/init.el"
#alias eclean="rm -r ~/.emacs.d; (cd ~/external_src/prelude && git clean -fdx && git pull); ln -s ~/external_src/prelude ~/.emacs.d; cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/; echo \"(require 'prelude-helm)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-helm-everywhere)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-go)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-clojure)\" >> ~/.emacs.d/prelude-modules.el; ln -s ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal"
alias eclean="rm -r ~/.emacs.d; (cd ~/external_src/prelude && git clean -fdx && git pull); ln -s ~/external_src/prelude ~/.emacs.d; ln -s ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal"

if [[ $(uname -s) == "Darwin" ]]; then
	export VISUAL="${_EMACS_C} -c -n"
	alias E="${_EMACS_C} -c -n"
	alias e="${_EMACS_C} -ct"

	export GIT_EDITOR='vim -f'
	export EDITOR='vim -f'
	export HOMEBREW_EDITOR='vim -f'

	# http://tug.org/mactex/faq/
	if [[ -d "/usr/texbin" ]]; then
		export PATH="/usr/texbin:$PATH"
	fi

	export PATH="$PATH:$HOME/go/bin"

	# So we can find Homebrew.
	#export PATH="/usr/local/bin:$PATH"

	if [[ -f "/Users/matt/venv/bin/activate" ]]; then
		source /Users/matt/venv/bin/activate
		export PATH="/Users/matt/venv/bin:$PATH"
	fi

	export PATH="$(brew --prefix)/sbin:$PATH"

	if [[ -d "$HOME/.cabal/bin" ]]; then
		export PATH="$HOME/.cabal/bin:$PATH"
	fi

	if [[ -s $(brew --prefix)/etc/autojump.sh ]]; then
		. $(brew --prefix)/etc/autojump.sh
	fi

	#export JAVA_HOME="$(/usr/libexec/java_home)"
	#alias jdk8="export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)"

	if which rbenv >/dev/null; then
		eval "$(rbenv init -)"
	fi

	if which node >/dev/null; then
		_NODE_VERSION=$(node --version | tr -d 'A-Za-z')
		export PATH="/usr/local/Cellar/node/${_NODE_VERSION}/bin:$PATH"
	fi

	source /Users/matt/Library/Preferences/org.dystroy.broot/launcher/bash/br
elif [[ $(uname -s) == "Linux" ]]; then
	alias E="${_EMACS_C} -ct"
	if [[ -d ~/go/bin ]]; then
		PATH="~/go/bin/:$PATH"
	fi
fi

alias b="brew"
alias git="hub"
alias c="clear"
alias dc="cd"
alias f="fd"
alias l="ls -lha"
alias p="ping google.com"
alias pw="prettier --write --print-width=110"
alias update-packages="make -f ~/Dropbox/experiments/Makefile update-packages"
alias cifmt='find . -type f -name "ci.sh" | xargs -I__ shfmt -i 2 -w __'
alias rscp='rsync -aP --no-whole-file --inplace'
alias rsmv='rscp --remove-source-files'
alias myip="curl -s https://api.ipify.org\?format\=json | jq -r '.ip'"

if [[ -f ~/my_src/private/${_EMPLOYER}_rc ]]; then
	. ~/my_src/private/${_EMPLOYER}_rc
fi

cleanup() {
	ls | while read -r FILE; do
		mv -v "$FILE" $(echo $FILE | tr ' ' '_' | tr -d '[{}(),\!]:"' | tr -d "\'" | tr '[A-Z]' '[a-z]' | tr '&' 'n' | sed 's/_-_/_/g')
	done
}

export GPG_TTY="$(tty)"

if [[ -f "$HOME/.gpg-agent-info" ]]; then
	. "$HOME/.gpg-agent-info"
	export GPG_AGENT_INFO

fi

if which "gpg-agent" >"/dev/null" 2>"/dev/null" && ! gpg-agent >/dev/null 2>&1; then
	eval "$(gpg-agent --daemon --disable-scdaemon)"
fi

alias gpgclean='killall -9 pinentry gpg-agent'

alias yt='youtube-dl -o "%(title)s-%(id)s.%(ext)s" --no-mtime'
alias yta='youtube-dl -o "%(title)s-%(id)s.%(ext)s" --extract-audio --no-mtime'

alias cca='ccat -C=always'

#from @ryankaplan
#-r 10 reduces frame rate from 25 to 10
#-s 600 x 400 tells max width and height
#--delay=3 means 30ms between each gif
#--optimize=3 says use slowest optimization for best file size
gif() {
	ffmpeg -i $1 -pix_fmt rgb24 -r 20 -f gif - | gifsicle --optimize=3 --delay=3 >$2
}

if [[ -d $HOME/.cargo/bin ]]; then
	export PATH=$PATH:$HOME/.cargo/bin

fi

if [[ -d $HOME/.go/bin ]]; then
	export PATH=$PATH:$HOME/.go/bin
fi

ff() {
	ffmpeg -i "$1" -b:a 320k "${1%.*}".mp3
}

gif2png() {
	convert -verbose -coalesce "$1" "${1%.*}".png
}

npmu() {
	npm ls -depth 0 --json | jq ".dependencies | keys" | jq -r '@sh' | tr -d "'" | tr " " "\n" | xargs -I__ npm i --save __@latest
}
