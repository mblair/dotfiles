.PHONY: all
all: fmt check

.PHONY: fmt
fmt:
	shfmt -w *.sh zshrc
	markdownfmt -w *.md

.PHONY: check
check:
	shellcheck *.sh

.PHONY: update-vim
update-vim:
	git submodule update --recursive --remote
