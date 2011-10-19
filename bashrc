#This makes Ctrl-S (forward-search-history) work.
stty stop undef

export HISTSIZE=100000 #bash history will save this many commands.
export HISTFILESIZE=${HISTSIZE} #bash will remember this many commands.
export HISTCONTROL=ignoredups #ignore duplicate commands
export HISTIGNORE="ls:pwd:exit:clear" #don't put this in the history.
export HISTTIMEFORMAT="[%Y-%m-%d - %H:%M:%S] "

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

#Thanks Gary Bernhardt.
minutes_since_last_commit() {
	now=`date +%s`
	last_commit=`git log --pretty=format:'%at' -1`
	seconds_since_last_commit=$((now - last_commit))
	minutes_since_last_commit=$((seconds_since_last_commit / 60))
	echo $minutes_since_last_commit
}

# Revision of the svn repo in the current directory
svn_rev() {
	unset SVN_REV
	local rev=`svn info 2>/dev/null | grep -i "Revision" | cut -d ' ' -f 2`
	if test $rev
		then
			SVN_REV="${bldgrn}svn:${txtrst}$rev"
	fi
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
		local GIT_PROMPT=`__git_ps1 "(%s|${SINCE_LAST_COMMIT})"`
		echo ${GIT_PROMPT}
	fi
}

GIT_PS1_SHOWDIRTYSTATE=1

update_prompt() {
	RET=$?;

	#For gVim's :sh
	if [ $TERM == 'dumb' ]; then
		#Fix LS_COLORS too.
		PS1="[\w]$ "
		return 0;
	fi

	#TODO: Fix these.
	#history -a #write the current terminal's history to the history file
	#history -n

	#https://wiki.archlinux.org/index.php/Color_Bash_Prompt#Advanced_return_value_visualisation
	#Basically, prepend the prompt with a green 0 if the last command returned 0, or prepend it with a red [error code] if not.
	RET_VALUE="$(if [[ $RET == 0 ]]; then echo -ne "${bldgrn}$RET"; else echo -ne "${bldred}$RET"; fi;)"
	svn_rev
	
	PS1="${bldblu}[${txtrst}\w${bldblu}]"
	PS1="$PS1${bldgrn}$(git_prompt)${SVN_REV} "

	#http://www.fileformat.info/info/unicode/char/26a1/index.htm
	PS1="$PS1${txtblu}⚡ ${txtrst}"

	# Set the title to user@host: dir
	PS1="\[\e]0;\u@\h: \w\a\]$PS1"

	#Show the current Ruby's version, patchlevel and gemset via RVM.
	if [ -f ~/bin/rvm-prompt -o -f ~/.rvm/bin/rvm-prompt ]; then
		PS1="$RET_VALUE ${bldred}$(rvm-prompt v p g) $PS1"
	else
		PS1="$RET_VALUE $PS1"
	fi

}

PROMPT_COMMAND=update_prompt

alias :w='echo "idiot"'

#http://www.debianadmin.com/pv-pipe-viewer-shell-pipeline-element-to-meter-data-passing-through.html/comment-page-1#comment-3739
alias rscp='rsync -aP --no-whole-file --inplace'
alias rsmv='rscp --remove-source-files'

alias less='less -N' #show line numbers when I invoke less myself, not for man.
alias f='find . | grep -i'
alias p='ping google.com'
alias c='clear'
alias git=hub
export LESS="-IMR" #search case insensitively, prompt verbosely (i.e. show percentage through the file) and repaint the screen, useful when a file is changing as you're reading it.
alias path='echo -e ${PATH//:/\\n}' # print path components, one per line

#http://superuser.com/questions/36022/less-and-grep-color
alias grep='grep --color=always -HI'

if [ "`uname`" == "Darwin" ]; then
	# Crusty, but I'm not putting my Flipboard hostnames in here.
	# http://www.commandlinefu.com/commands/view/2766/ssh-autocomplete
	#complete -W "$(echo $(grep '^ssh ' .bash_history | sort -u | sed 's/^ssh //'))" ssh ssh-copy-id

	. ~/.git-completion.bash

	source `brew --prefix`/Library/Contributions/brew_bash_completion.sh

	if [ -f `brew --prefix`/etc/bash_completion ]; then
		. `brew --prefix`/etc/bash_completion
	fi

	export PATH="/usr/local/sbin/:/usr/local/bin:$PATH"

	if [ -d "$HOME/.cabal/bin" ]; then
		export PATH="$HOME/.cabal/bin:$PATH"
	fi

	#https://github.com/mxcl/homebrew/wiki/Homebrew-and-Python
	export PATH="/usr/local/share/python:$PATH"

	alias ls='ls -pG'
	export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx
fi

if [ "`uname`" == "Linux" ]; then
	export VISUAL=vim
	export EDITOR=$VISUAL

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

	if [ -f ~/.rvm/scripts/completion ]; then
		. ~/.rvm/scripts/completion
	fi

	#TODO: Profile your prompt and see if this is what's slowing things down.
	#GIT_PS1_SHOWUPSTREAM="verbose"

	. ~/.git-completion.bash

	alias ls='ls --color=auto -p --group-directories-first'
	alias pstree='pstree -ap' #args & PID

	#http://www.webupd8.org/2010/07/get-notified-when-job-you-run-in.html#comment-64740149
	alias alert_summ='history|tail -n1|sed -e "s/^\s*[0-9]\+\s*//" -e "s/\s*;\s*alert[0-9]*.*$//"'
	alias alert_body='history|tail -n1|sed -e "s/\([^;]*\;\)\+//" -e "s/\s*alert\s*//" -e "s/#\(.*\)/\1/"'
	alias alert='notify-send -i /usr/share/icons/gnome/32x32/apps/gnome-terminal.png "$(alert_summ)" "$(alert_body)"'

	#Archive extractor.
	ex ()
	{
	if [ -f $1 ] ; then
		case $1 in
		*.tar.bz2)   tar xjvf $1      ;;
		*.tar.gz)    tar xzvf $1      ;;
		*.bz2)       bunzip2 $1      ;;
		*.rar)       unrar e $1        ;;
		*.gz)        gunzip $1       ;;
		*.tar)       tar xvf $1       ;;
		*.tbz2)      tar xjvf $1      ;;
		*.tgz)       tar xzvf $1      ;;
		*.zip)       unzip -jo $1        ;;
		*.Z)         uncompress $1   ;;
		*.7z)        7z x $1         ;;
		*)           echo "'$1' cannot be extracted via ex()" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
	}

	cleanup() {
		ls | while read -r FILE
			do
			mv -v "$FILE" `echo $FILE | tr ' ' '_' | tr -d '[{}(),\!]:"' | tr -d "\'" | tr '[A-Z]' '[a-z]' | sed 's/_-_/_/g'`
			done
	}

	mkcd() {
		if [ "$1" ]; then
			mkdir -p "$1" && cd "$1"
		fi
	}

	historyawk() {
		history | awk '{a[$2]++}END{for(i in a){printf"%5d\t%s\n",a[i],i}}' | sort -nr | head; 
	}

	if [[ -s "$HOME/.bash_profile" ]]; then
		. "$HOME/.bash_profile"
	fi
fi
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
