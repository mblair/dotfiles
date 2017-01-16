.PHONY: all
all: fmt check

.PHONY: fmt
fmt:
	shfmt -w *.sh
	markdownfmt -w *.md

.PHONY: check
check:
	shellcheck *.sh
