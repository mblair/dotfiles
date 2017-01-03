.PHONY: fmt
fmt:
	shfmt -w *.sh
	markdownfmt -w *.md

check:
	shellcheck *.sh
