#!/usr/bin/env bash

set -xueo pipefail

export HOMEBREW_INSTALL_CLEANUP=1

_EMPLOYER="descript"
_RESOLVE_CLONES=false

_HERE=$(
	cd "$(dirname "$0")"
	pwd
)

while [[ $# -gt 0 ]]; do
	case "$1" in
	--resolve-clones)
		_RESOLVE_CLONES=true
		shift
		;;
	-h | --help)
		echo "Usage: $0 [--resolve-clones]"
		echo "  --resolve-clones    Run mise run resolve-clones -- -p ${_EMPLOYER} after update.sh"
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		exit 1
		;;
	esac
done

list_wedged_employer_clones() {
	_outer_dir=~/"${_EMPLOYER}"_src
	[[ -d "${_outer_dir}" ]] || return 0

	for _clone_path in "${_outer_dir}"/"${_EMPLOYER}" "${_outer_dir}"/"${_EMPLOYER}"-*; do
		[[ -d "${_clone_path}" ]] || continue
		git -C "${_clone_path}" rev-parse --is-inside-work-tree &>/dev/null || continue

		_git_dir=$(git -C "${_clone_path}" rev-parse --git-dir 2>/dev/null) || continue
		_reason=""
		if [[ -d "${_clone_path}/${_git_dir}/rebase-merge" ]] || [[ -d "${_clone_path}/${_git_dir}/rebase-apply" ]]; then
			_reason="rebase"
		elif [[ -f "${_clone_path}/${_git_dir}/MERGE_HEAD" ]]; then
			_reason="merge"
		elif [[ -f "${_clone_path}/${_git_dir}/CHERRY_PICK_HEAD" ]]; then
			_reason="cherry-pick"
		elif [[ -f "${_clone_path}/${_git_dir}/REVERT_HEAD" ]]; then
			_reason="revert"
		elif [[ -f "${_clone_path}/${_git_dir}/BISECT_LOG" ]]; then
			_reason="bisect"
		elif [[ -n "$(git -C "${_clone_path}" diff --name-only --diff-filter=U)" ]]; then
			_reason="unmerged paths"
		fi

		if [[ -n "${_reason}" ]]; then
			printf "%s\t%s\n" "$(basename "${_clone_path}")" "${_reason}"
		fi
	done
}

#TODO: break these all up into functions, make them individually addressable

export PATH=/usr/local/bin:$PATH
if [[ $(which gem) == "$HOME/.rbenv/shims/gem" ]]; then
	gem update --system
	gem update
	gem install showoff exifr pry pygments.rb lolcat bundler
	gem cleanup --quiet
fi

if command -v docker >/dev/null 2>&1; then
	if [[ "$(du -ms ~/Library/Containers/com.docker.docker | awk '{print $1}')" -gt 25000 ]]; then
		docker rmi -f "$(docker images -q)" || true
	fi
fi

#easy_install -U setuptools
#pip install -U pip
#pip install -U autopep8 virtualenv howdoi ramlfications pockyt proselint
#pip freeze | cut -d= -f1 | xargs pip install -U

if [[ -d ~/.oh-my-zsh ]]; then
	cd ~/.oh-my-zsh
	git pull
else
	git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
fi

brew update

#brew install node || brew upgrade node
#npm install -g grunt-cli redis-dump rickshaw jquery bootstrap react underscore d3 coffee-script js-yaml how2 eslint create-react-app parsimmon exif standard standard-format write-good fast-cli prettier js-beautify hyperapp wunderline ndb bash-language-server public-ip-cli corona-cli

"${_HERE}"/install.sh
# ${_HERE}/python.sh

#rm -rf ~/.emacs.d
#mkdir -p ~/.emacs.d/; ln -s ${_HERE}/init.el ~/.emacs.d
#/usr/local/bin/emacs --daemon

#brew tap caskroom/fonts

for _pkg in autojump bash ffmpeg git git-extras gnu-sed gnupg irssi jq s3cmd shellcheck ssh-copy-id ripgrep tmux wget zsh findutils ghi nginx postgresql redis pup vault wget httpdiff gifsicle zsh-completions wifi-password cowsay jid mtr ccat watch go gh httpstat clang-format ctop pngcheck curl git-lfs telnet pgformatter moreutils azure-cli llvm imagemagick wireguard-tools iperf3 swiftformat python kubernetes-cli fd broot cppcheck openssh macvim loc gopls shfmt Nonchalant/appicon/appicon rustup minikube ijq kubecolor httpie yt-dlp pipx ruff jj uv kubectl-ai font-inter mise just nbping llmfit shadcn gawk ty fzf weave cloudflare-speed-cli dtop k9s sqlite kustomize pyrefly pi-coding-agent sem-cli; do
	brew install ${_pkg} || brew upgrade ${_pkg}
done

# Install random tools in Go and Node.
go install github.com/shurcooL/markdownfmt@latest

mise install
eval "$(mise activate bash)"
npm cache clean --force
_NPM_PREFIX=$(npm prefix -g)
for _npm in @google/gemini-cli @openai/codex@latest opencode-ai@latest git-trim @github/copilot npm-check-updates webtorrent-cli wscat gnomon socket.io-cli oxfmt oxlint @googleworkspace/cli; do
	rm -rf "${_NPM_PREFIX}"/lib/node_modules/${_npm%@latest}
	npm i -g ${_npm}
done
# Fix broken execute permissions on npm global binaries (some packages don't set +x)
find "${_NPM_PREFIX}"/lib/node_modules -type f \( -name "*.js" -o -name "cli" \) -path "*/bin/*" -exec chmod +x {} \; 2>/dev/null || true
chmod +x "${_NPM_PREFIX}"/lib/node_modules/npm-check-updates/build/cli.js 2>/dev/null || true

curl -fsSL https://bun.com/install | bash

"${_HERE}"/install_claude.sh

for _pipx in token-count llm shot-scraper black ttok git-delete-merged-branches autowt; do
	pipx install ${_pipx} --force || pipx reinstall ${_pipx}
done
llm install --upgrade llm-ollama llm-video-frames

# gcc is busted on catalina, needed for binwalk.
#brew install binwalk

#brew cask install java font-hack-nerd-font minikube keybase
brew install --cask gcloud-cli emacs-app || true

"${_HERE}"/update.sh --prefix external
"${_HERE}"/update.sh --prefix ${_EMPLOYER} --recurse

if [[ "${_RESOLVE_CLONES}" == true ]]; then
	mise run resolve-clones -- -p "${_EMPLOYER}"
fi

if [[ -f ~/my_src/private/install.sh ]]; then
	~/my_src/private/install.sh
fi

if [[ -f ~/my_src/private/${_EMPLOYER}_install.sh ]]; then
	~/my_src/private/${_EMPLOYER}_install.sh
fi

if [[ -f ~/my_src/private/${_EMPLOYER}_update.sh ]]; then
	~/my_src/private/${_EMPLOYER}_update.sh mac-update
fi

"${_HERE}"/update_rust.sh

brew outdated
brew outdated --cask

set +x

# Show new formulae added to Homebrew in the last week
echo "=== New Homebrew formulae (last week) ==="
_HOMEBREW_CORE_PATH="${HOME}/external_src/homebrew-core"
if [[ -d "${_HOMEBREW_CORE_PATH}" ]]; then
	git -C "${_HOMEBREW_CORE_PATH}" fetch --quiet
	_NEW_FORMULAE=$(git -C "${_HOMEBREW_CORE_PATH}" log --since="1 week ago" --diff-filter=A --pretty=format: --name-only -- Formula | sort -u | grep -v '^$')
	if [[ -n "${_NEW_FORMULAE}" ]]; then
		echo "${_NEW_FORMULAE}" | while read -r formula_path; do
			formula_name=$(basename "${formula_path}" .rb)
			desc=$(brew info "${formula_name}" 2>/dev/null | sed -n '2p')
			printf "%-30s %s\n" "${formula_name}" "${desc}"
		done
	else
		echo "No new formulae this week"
	fi
else
	echo "homebrew-core not found at ${_HOMEBREW_CORE_PATH}"
fi

echo "=== ${_EMPLOYER} wedged clone summary ==="
_WEDGED_CLONES=$(list_wedged_employer_clones)
if [[ -n "${_WEDGED_CLONES}" ]]; then
	echo "${_WEDGED_CLONES}" | while IFS=$'\t' read -r clone_name reason; do
		printf "%-24s %s\n" "${clone_name}" "${reason}"
	done
	echo
	echo "Run: mise run resolve-clones -- -p ${_EMPLOYER}"
else
	echo "No wedged ${_EMPLOYER} clones found."
fi

grep agent ~/.zshrc || true
