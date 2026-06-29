SHELL := /usr/bin/env bash

.PHONY: syntax shellcheck markdownlint test

syntax:
	find scripts -type f -name '*.sh' -print0 | while IFS= read -r -d '' file; do \
		echo "bash -n $$file"; \
		bash -n "$$file"; \
	done

shellcheck:
	find scripts -type f -name '*.sh' -print0 | xargs -0 shellcheck

markdownlint:
	markdownlint-cli2 '**/*.md'

test: syntax
