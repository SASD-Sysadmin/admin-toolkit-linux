SHELL := /usr/bin/env bash

.PHONY: test syntax shellcheck tree

test: syntax
	@echo "Basic tests completed."

syntax:
	@find scripts -type f -name '*.sh' -print0 | while IFS= read -r -d '' file; do echo "bash -n $$file"; bash -n "$$file"; done

shellcheck:
	@shellcheck scripts/**/*.sh

tree:
	@find . -not -path './.git/*' | sort
