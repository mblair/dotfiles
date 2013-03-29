#!/usr/bin/env bash # because emacs is a little stupid sometimes

# This makes Ctrl-S (forward-search-history) work.
stty stop undef

export HISTSIZE=100000 #bash history will save this many commands
export HISTFILESIZE=${HISTSIZE} #bash will remember this many commands
export HISTCONTROL=ignoredups #ignore duplicate commands
export HISTIGNORE="cd:ls:clear" #don't put these in the history
export HISTTIMEFORMAT="[%Y-%m-%d - %H:%M:%S] " #timestamps

shopt -s cmdhist # save multi-line commands as a single line in the history.
shopt -s expand_aliases   # expand aliases in this file.
shopt -s histappend # append to the history file instead of overwriting

pcp() {
	if [ -d "$2" ]; then
		pv "$1" > "$2"/"$1"
	else
		pv "$1" > "$2"
	fi
}

#Regular Colors
txtblk='\[\e[0;30m\]' # Black
txtred='\[\e[0;31m\]' # Red
txtgrn='\[\e[0;32m\]' # Green
txtylw='\[\e[0;33m\]' # Yellow
txtblu='\[\e[0;34m\]' # Blue
txtpur='\[\e[0;35m\]' # Purple
txtcyn='\[\e[0;36m\]' # Cyan
txtwht='\[\e[0;37m\]' # White
#Bold Colors
bldblk='\[\e[1;30m\]' # Black
bldred='\[\e[1;31m\]' # Red
bldgrn='\[\e[1;32m\]' # Green
bldylw='\[\e[1;33m\]' # Yellow
bldblu='\[\e[1;34m\]' # Blue
bldpur='\[\e[1;35m\]' # Purple
bldcyn='\[\e[1;36m\]' # Cyan
bldwht='\[\e[1;37m\]' # White
#Underlined Colors
unkblk='\[\e[4;30m\]' # Black
undred='\[\e[4;31m\]' # Red
undgrn='\[\e[4;32m\]' # Green
undylw='\[\e[4;33m\]' # Yellow
undblu='\[\e[4;34m\]' # Blue
undpur='\[\e[4;35m\]' # Purple
undcyn='\[\e[4;36m\]' # Cyan
undwht='\[\e[4;37m\]' # White
#Background Colors
bakblk='\[\e[40m\]'   # Black
bakred='\[\e[41m\]'   # Red
badgrn='\[\e[42m\]'   # Green
bakylw='\[\e[43m\]'   # Yellow
bakblu='\[\e[44m\]'   # Blue
bakpur='\[\e[45m\]'   # Purple
bakcyn='\[\e[46m\]'   # Cyan
bakwht='\[\e[47m\]'   # White
txtrst='\[\e[0m\]'    # Text Reset

cleanup() {
	ls | while read -r FILE
		do
		mv -v "$FILE" `echo $FILE | tr ' ' '_' | tr -d '[{}(),\!]:"' | tr -d "\'" | tr '[A-Z]' '[a-z]' | tr '&' 'n' | sed 's/_-_/_/g'`
		done
}

# Thanks Gary Bernhardt.
minutes_since_last_commit() {
	now=`date +%s`
	last_commit=`git log --pretty=format:'%at' -1`
	seconds_since_last_commit=$((now - last_commit))
	minutes_since_last_commit=$((seconds_since_last_commit / 60))
	echo $minutes_since_last_commit
}

git_prompt() {
    local g="$(__gitdir)"
	if [ -n "$g" ]; then
		local MINUTES_SINCE_LAST_COMMIT=`minutes_since_last_commit`
		if [ "$MINUTES_SINCE_LAST_COMMIT" -gt 30 ]; then
			local COLOR=${bldred}
		elif [ "$MINUTES_SINCE_LAST_COMMIT" -gt 10 ]; then
			local COLOR=${bldylw}
		else
			local COLOR=${bldgrn}
		fi
		local SINCE_LAST_COMMIT="${COLOR}$(minutes_since_last_commit)m${txtrst}"
		# __git_ps1 is from the Git source tree's contrib/completion/git-completion.bash
		local GIT_PROMPT=`__git_ps1 "${txtrst}(${bldgrn}%s${txtrst}|${SINCE_LAST_COMMIT}${txtrst})"`
		echo ${GIT_PROMPT}
	fi
}

# If you don't have an SSD, setting this to 1 will noticeably slow down
# operations within that directory (including `cd`), so be careful.
GIT_PS1_SHOWDIRTYSTATE=1

update_prompt() {
	RET=$?;

	#TODO: Fix these.
	#history -a #write the current terminal's history to the history file
	#history -n

	# https://wiki.archlinux.org/index.php/Color_Bash_Prompt#Advanced_return_value_visualisation
	# Basically, prepend the prompt with a green 0 if the last command returned 0, or prepend it with a red $error_code if not.
	RET_VALUE="$(if [[ $RET == 0 ]]; then echo -ne "${bldgrn}$RET"; else echo -ne "${bldred}$RET"; fi;)"

        # If I'm root, use a red prompt. Green otherwise.
	if [[ ${EUID} == 0 ]]; then
		_color="${bldred}"
	else
		_color="${bldgrn}"
	fi

	# On a Mac (read: my workstation), just show the return value and working directory.
	if [[ $(uname -s) == "Darwin" ]]; then
		PS1="${bldblu}[${txtrst}\w${bldblu}]"
	else
		# On Linux, show the user and hostname too.
		PS1="${_color}\u${bldblu}@${_color}\h "
		PS1="${PS1}${bldblu}[${txtrst}\w${bldblu}]"
	fi
	PS1="$PS1$(git_prompt) "

	#http://www.fileformat.info/info/unicode/char/26a1/index.htm
	PS1="$PS1${bldblu}⚡ ${txtrst}"

	# Set the term title to user@host: working_dir
	PS1="\[\e]0;\u@\h: \w\a\]$PS1"

	PS1="$RET_VALUE $PS1"
}

PROMPT_COMMAND=update_prompt

alias :w='echo "idiot"'

#http://www.debianadmin.com/pv-pipe-viewer-shell-pipeline-element-to-meter-data-passing-through.html/comment-page-1#comment-3739
alias rscp='rsync -aP --no-whole-file --inplace'
alias rsmv='rscp --remove-source-files'

alias less='less -N' # show line numbers when I invoke `less` myself, but not for `man`.
alias f='find . | grep -i' # useful for finding files within the
                           # current directory.
alias p='ping google.com'

alias es='/usr/local/Cellar/emacs/24.3/Emacs.app/Contents/MacOS/Emacs --daemon'
export EDITOR='/usr/local/bin/emacsclient -ct'

alias emacs='/usr/local/bin/emacsclient -c -n'
alias E='/usr/local/bin/emacsclient -c -n'
export VISUAL='/usr/local/bin/emacsclient -c -n'

alias m='make'
alias v='vagrant'
alias c='clear'
alias x='clear' # what is this X you speak of?

if [[ -f /usr/local/bin/hub ]]; then
	alias git=hub
fi

export LESS="-IMR" # search case insensitively, prompt verbosely (i.e. show percentage through the file) and repaint the screen, useful when a file is changing as you're reading it.
alias path='echo -e ${PATH//:/\\n}' # print path components, one per line.

# http://superuser.com/questions/36022/less-and-grep-color
# Print the filename and don't search binary files. Note that if you're
# piping stuff through grep, the `-H` will annoy you. So I call `env
# grep` in pipelines.
alias grep='grep --color=always -HI'

# I have a `git-new` script in here that I use to see new Homebrew
# formulae. I never use it, but why not.
export PATH="$HOME/dotfiles/bin:$PATH"

export NODE_PATH="/usr/local/lib/node_modules"

if [ "`uname`" == "Darwin" ]; then
	export JAVA_HOME="$(/usr/libexec/java_home)"

	if [ -f "`brew --prefix`/Library/Contributions/brew_bash_completion.sh" ]; then
		source `brew --prefix`/Library/Contributions/brew_bash_completion.sh
	fi

	if [ -f "`brew --prefix`/etc/bash_completion" ]; then
		. `brew --prefix`/etc/bash_completion
	fi

	# Put Homebrew stuff before Apple's stuff.
	export PATH="/usr/local/sbin:/usr/local/bin:$PATH"

  # Homebrew Ruby.
  # export PATH="/usr/local/opt/ruby/bin:$PATH"

  # rbenv Ruby.
  if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

  alias g="cd $(ruby -r rubygems -e 'p Gem.path.select { |p| File.exists?(p) }.first')/gems"

  # Node binaries.
  export PATH="/usr/local/share/npm/bin:$PATH"

	if [ -d "$HOME/.cabal/bin" ]; then
		export PATH="$HOME/.cabal/bin:$PATH"
	fi

	# http://tug.org/mactex/faq/
	if [ -d "/usr/texbin" ]; then
		export PATH="/usr/texbin:$PATH"
	fi

	# https://github.com/mxcl/homebrew/wiki/Homebrew-and-Python
	export PATH="/usr/local/share/python:$PATH"

  source /Users/mblair/venv/bin/activate
  export PATH="/Users/mblair/venv/bin:$PATH"

	# Colors + slash after directory names.
	alias ls='ls -pG'

	# Document this.
	export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx
fi

if [ "`uname`" == "Linux" ]; then
	PAGER=less

	# LESS man page colors
	export LESS_TERMCAP_mb=$'\E[01;31m'
	export LESS_TERMCAP_md=$'\E[01;31m'
	export LESS_TERMCAP_me=$'\E[0m'
	export LESS_TERMCAP_se=$'\E[0m'
	export LESS_TERMCAP_so=$'\E[01;44;33m'
	export LESS_TERMCAP_ue=$'\E[0m'
	export LESS_TERMCAP_us=$'\E[01;32m'

	if [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi

	# Only source this if we installed Git from source. If we
	# didn't, it's installed already.
        # TODO: Put this file somewhere else.
	if [[ -f ~/.git-completion.bash ]]; then
		. ~/.git-completion.bash
	fi

	alias ls='ls --color=auto -p --group-directories-first'
	alias pstree='pstree -ap' # args & PID

	if [[ -s "$HOME/.bash_profile" ]]; then
		. "$HOME/.bash_profile"
	fi
fi

if [[ -f /Users/mblair/my_src/personal/flip_bash ]]; then
    . /Users/mblair/my_src/personal/flip_bash
fi

if [[ -f ~/.maven_bash_completion.bash ]]; then
    . ~/.maven_bash_completion.bash
fi
