_EMPLOYER="descript"

if [[ $(uname -s) == "Darwin" ]]; then
	_EMACS=/opt/homebrew/bin/emacs
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

plugins=(git golang python gcloud brew gh kubectl terraform rust)
if [[ $(uname -s) == "Darwin" ]]; then
	plugins+=(macos)
fi

source $ZSH/oh-my-zsh.sh

alias es="${_EMACS} --daemon"
alias ek="${_EMACS_C} --eval \"(progn (setq kill-emacs-hook 'nil) (kill-emacs))\""
alias ekk="kill -9 $(ps -Ao 'pid,command' | grep '[e]macs' | awk '{print $1}')"
#alias eclean="rm -rf ~/.emacs.d; mkdir -p ~/.emacs.d; ln -s ~/my_src/dotfiles/init.el ~/.emacs.d/init.el"
#alias eclean="rm -r ~/.emacs.d; (cd ~/external_src/prelude && git clean -fdx && git pull); ln -s ~/external_src/prelude ~/.emacs.d; cp ~/external_src/prelude/sample/prelude-modules.el ~/.emacs.d/; echo \"(require 'prelude-helm)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-helm-everywhere)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-go)\" >> ~/.emacs.d/prelude-modules.el; echo \"(require 'prelude-clojure)\" >> ~/.emacs.d/prelude-modules.el; ln -s ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal"
alias eclean="rm -r ~/.emacs.d; (cd ~/external_src/prelude && git clean -fdx && git pull); ln -s ~/external_src/prelude ~/.emacs.d; ln -s ~/my_src/dotfiles/prelude/personal.el ~/.emacs.d/personal"

if [[ $(uname -s) == "Darwin" ]]; then
	FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
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
	export HF_HUB_ENABLE_HF_TRANSFER=True

	if [[ -f "/Users/matt/venv/bin/activate" ]]; then
		source /Users/matt/venv/bin/activate
		export PATH="/Users/matt/venv/bin:$PATH"
	fi

	export PATH="$(brew --prefix)/sbin:$PATH"

	if [[ -d "$HOME/.cabal/bin" ]]; then
		export PATH="$HOME/.cabal/bin:$PATH"
	fi

	if which zoxide >/dev/null; then
		eval "$(zoxide init zsh --cmd j)"
	fi

	#export JAVA_HOME="$(/usr/libexec/java_home)"
	#alias jdk8="export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)"

	if which rbenv >/dev/null; then
		eval "$(rbenv init -)"
	fi

	#if which node >/dev/null; then
	#	_NODE_VERSION=$(node --version | tr -d 'A-Za-z')
	#	export PATH="/usr/local/Cellar/node/${_NODE_VERSION}/bin:$PATH"
	#fi

	_PYTHON_VERSION=$(brew info python --json | jq -r '.[0].versions.stable' | cut -d'.' -f1-2)
	export PATH="/opt/homebrew/opt/python@${_PYTHON_VERSION}/libexec/bin:$PATH"
	_PG_VER=$(brew list | grep postgresql | cut -d'@' -f2)
	export PATH="/opt/homebrew/opt/postgresql@${_PG_VER}/bin:$PATH"

	alias ag='rg --hidden'
	alias rg='rg --hidden'
	alias remove-whitespace="gsed -i 's/[ \t]*$//'"
elif [[ $(uname -s) == "Linux" ]]; then
	alias E="${_EMACS_C} -ct"
	if [[ -d ~/go/bin ]]; then
		PATH="~/go/bin/:$PATH"
	fi

	if dpkg -l | grep --silent autojump; then
		. /usr/share/autojump/autojump.sh
	fi
fi

alias b="brew"
alias m="mise"
alias c="clear"
alias dc="cd"
alias f="fd -H"
alias l="ls -lha"
alias p="ping google.com"
alias pw="prettier --write --print-width=110"
alias update-packages="make -f ~/Dropbox/experiments/Makefile update-packages"
alias cifmt='find . -type f -name "ci.sh" | xargs -I__ shfmt -i 2 -w __'
alias rscp='rsync -aP --no-whole-file --inplace'
alias rsmv='rscp --remove-source-files'
alias myip="curl -s https://api.ipify.org\?format\=json | jq -r '.ip'"
alias wattage="system_profiler SPPowerDataType | awk '/Wattage/ {print \$3}'"
alias battery="pmset -g batt | grep -o '[0-9]*%'"
alias ocd="open -a /Applications/OpenCode.app"

if [[ -f ~/my_src/private/${_EMPLOYER}_rc ]]; then
	. ~/my_src/private/${_EMPLOYER}_rc
fi

if [[ -f ~/my_src/private/matt_rc ]]; then
	. ~/my_src/private/matt_rc
fi

cleanup() {
	ls | while read -r FILE; do
		mv -v "$FILE" $(echo $FILE | tr ' ' '_' | tr -d '[{}(),\!]:"' | tr -d "\'" | tr '[A-Z]' '[a-z]' | tr '&' 'n' | sed 's/_-_/_/g')
	done
}

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

d-ytdlp() {
	yt-dlp -f "bv*[ext=mp4]+ba*[ext=m4a]" --merge-output-format mp4 "$@"
}

_yt_transcribe_setup() {
	emulate -L zsh

	local cmd="${1:-yt-transcribe}"
	local whisper_dir="${WHISPER_CPP_DIR:-$HOME/external_src/whisper.cpp}"
	local whisper_cli="${WHISPER_CPP_BIN:-$whisper_dir/build/bin/whisper-cli}"
	local whisper_lang="${WHISPER_CPP_LANG:-en}"
	local whisper_model_name="${WHISPER_CPP_MODEL_NAME:-base.en}"
	local default_model="$whisper_dir/models/ggml-$whisper_model_name.bin"
	local whisper_model="${WHISPER_CPP_MODEL:-$default_model}"

	if ! command -v ffmpeg >/dev/null 2>&1; then
		echo "$cmd: ffmpeg not found" >&2
		return 1
	fi
	if [[ ! -d "$whisper_dir" ]]; then
		echo "$cmd: whisper.cpp not found at $whisper_dir" >&2
		return 1
	fi
	if [[ ! -x "$whisper_cli" ]]; then
		if ! command -v cmake >/dev/null 2>&1; then
			echo "$cmd: cmake not found; cannot build whisper.cpp" >&2
			return 1
		fi
		echo "$cmd: building whisper.cpp" >&2
		(
			cd "$whisper_dir" &&
				cmake -B build &&
				cmake --build build --config Release
		) || return 1
	fi
	if [[ ! -f "$whisper_model" ]]; then
		if [[ "$whisper_model" != "$default_model" ]]; then
			echo "$cmd: whisper model not found at $whisper_model" >&2
			return 1
		fi
		echo "$cmd: downloading whisper.cpp model $whisper_model_name" >&2
		(
			cd "$whisper_dir" &&
				bash ./models/download-ggml-model.sh "$whisper_model_name"
		) || return 1
	fi

	typeset -g _YT_TRANSCRIBE_WHISPER_CLI="$whisper_cli"
	typeset -g _YT_TRANSCRIBE_WHISPER_MODEL="$whisper_model"
	typeset -g _YT_TRANSCRIBE_WHISPER_LANG="$whisper_lang"
}

_yt_transcribe_file() {
	emulate -L zsh
	set -o pipefail

	local cmd="$1"
	local media_path="${2:A}"
	local out_dir="${4:-${media_path:h}}"
	local out_base="$out_dir/${${media_path:t}%.*}"
	local wav_path="$3/${${media_path:t}%.*}.wav"
	local txt_path="$out_base.txt"

	echo "$cmd: converting $media_path to wav" >&2
	ffmpeg -hide_banner -loglevel error -y -i "$media_path" \
		-ar 16000 -ac 1 -c:a pcm_s16le "$wav_path" || return 1

	echo "$cmd: transcribing $media_path with whisper.cpp" >&2
	"$_YT_TRANSCRIBE_WHISPER_CLI" -m "$_YT_TRANSCRIBE_WHISPER_MODEL" \
		-l "$_YT_TRANSCRIBE_WHISPER_LANG" -f "$wav_path" \
		-otxt -of "$out_base" -np >/dev/null || return 1

	echo "$txt_path"
}

yt-transcribe-local() (
	emulate -L zsh
	set -o pipefail

	if [[ $# -eq 0 ]]; then
		set -- .
	fi

	_yt_transcribe_setup yt-transcribe-local || return 1

	local tmpdir
	tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/yt-transcribe-local.XXXXXX")" || return 1
	trap 'rm -rf "$tmpdir"' EXIT

	local target media_path
	for target in "$@"; do
		if [[ -d "$target" ]]; then
			local found=0
			for media_path in "$target"/*.(mp4|mkv|webm|m4a|mp3|wav|opus|flac|mov)(N); do
				found=1
				_yt_transcribe_file yt-transcribe-local "$media_path" "$tmpdir" || return 1
			done
			if [[ "$found" -eq 0 ]]; then
				echo "yt-transcribe-local: no supported media files found in $target" >&2
			fi
		elif [[ -f "$target" ]]; then
			_yt_transcribe_file yt-transcribe-local "$target" "$tmpdir" || return 1
		else
			echo "yt-transcribe-local: not a file or directory: $target" >&2
			return 1
		fi
	done
)

yt-transcribe() (
	emulate -L zsh
	set -o pipefail

	local url="$1"
	if [[ -z "$url" ]]; then
		echo "Usage: yt-transcribe URL" >&2
		return 1
	fi

	if ! command -v yt-dlp >/dev/null 2>&1; then
		echo "yt-transcribe: yt-dlp not found" >&2
		return 1
	fi
	_yt_transcribe_setup yt-transcribe || return 1

	local tmpdir
	tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/yt-transcribe.XXXXXX")" || return 1
	trap 'rm -rf "$tmpdir"' EXIT

	echo "yt-transcribe: downloading audio" >&2
	local audio_path
	audio_path="$(yt-dlp --quiet --no-warnings --no-playlist \
		-f "bestaudio/best" \
		-o "$tmpdir/%(title).180B [%(id)s].%(ext)s" \
		--print after_move:filepath \
		"$url")" || return 1
	audio_path="${audio_path##*$'\n'}"

	_yt_transcribe_file yt-transcribe "$audio_path" "$tmpdir" "${PWD:A}" || return 1
)

av1tohevc() {
	local in="$1"
	if [[ -z "$in" ]]; then
		echo "Usage: av1tohevc /path/to/file.mp4"
		return 1
	fi
	local out="${in%.mp4}-HEVC.mp4"
	ffmpeg -i "$in" \
		-c:v libx265 -preset slow -crf 20 -pix_fmt yuv420p -tag:v hvc1 -movflags +faststart \
		-c:a aac -b:a 192k \
		"$out"
}

if [[ -d $HOME/.cargo ]]; then
	. "$HOME/.cargo/env"
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

if which mise >/dev/null; then
	_MISE=$(which mise)
	eval "$(${_MISE} activate zsh --shims)"
fi

if command -v twig >/dev/null 2>&1; then
	eval "$(twig shell-init zsh)"
fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/matt/.lmstudio/bin"
# End of LM Studio CLI section

# bun completions
[ -s "/Users/matt/.bun/_bun" ] && source "/Users/matt/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

if [[ -d "$HOME/.local/bin" ]]; then
	case ":$PATH:" in
	*":$HOME/.local/bin:"*) ;;
	*) export PATH="$HOME/.local/bin:$PATH" ;;
	esac
fi

code_locs() {
	scc "${1:-.}" --by-file -s code --exclude-dir .git,node_modules,dist,build,coverage,vendor,tmp,out,target,.next,.turbo --no-min-gen --no-large
}

source <(fzf --zsh)

alias isodate='date -u +"%Y-%m-%dT%H:%M:%SZ"'
alias tz='date +"%z"'

source <(kubectl-argo-rollouts completion zsh)

# Added by Antigravity CLI installer
export PATH="/Users/matt/.local/bin:$PATH"

# Added by Antigravity CLI installer
export PATH="/Users/matthew/.local/bin:$PATH"
