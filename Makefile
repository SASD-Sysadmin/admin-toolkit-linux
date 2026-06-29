# Makefile for admin-toolkit-linux
#
# The targets in this file are intentionally local and conservative.
# They do not depend on GitHub Actions and can be used on a workstation,
# WSL instance, lab VM or small server clone before committing changes.

SHELL := /bin/bash

SCRIPT_FILES := $(shell find scripts -type f -name '*.sh' 2>/dev/null | sort)
REPORT_DIR ?= reports/local-smoke-$(shell date +%Y%m%d-%H%M%S)

.PHONY: help
help:
	@echo "admin-toolkit-linux local targets"
	@echo
	@echo "  make list-scripts   List tracked shell scripts"
	@echo "  make syntax         Run bash -n for every shell script"
	@echo "  make file-modes     Check executable bits for scripts and non-scripts"
	@echo "  make check          Run syntax and file mode checks"
	@echo "  make smoke          Run the read-only report collector into reports/"
	@echo "  make clean-reports  Remove generated local reports"
	@echo

.PHONY: list-scripts
list-scripts:
	@if [ -z "$(SCRIPT_FILES)" ]; then \
		echo "No shell scripts found."; \
	else \
		printf '%s\n' $(SCRIPT_FILES); \
	fi

.PHONY: syntax
syntax:
	@find scripts -type f -name '*.sh' -print0 | sort -z | while IFS= read -r -d '' file; do \
		echo "bash -n $$file"; \
		bash -n "$$file"; \
	done

.PHONY: file-modes
file-modes:
	@echo "Checking executable bit policy..."
	@failed=0; \
	while IFS= read -r -d '' file; do \
		if [ ! -x "$$file" ]; then \
			echo "ERROR: shell script is not executable: $$file"; \
			failed=1; \
		fi; \
	done < <(find scripts -type f -name '*.sh' -print0 | sort -z); \
	while IFS= read -r -d '' file; do \
		case "$$file" in \
			./.git/*|./scripts/*.sh|./scripts/*/*.sh) continue ;; \
		esac; \
		if [ -x "$$file" ]; then \
			echo "ERROR: non-script file is executable: $$file"; \
			failed=1; \
		fi; \
	done < <(find . -type f -not -path './.git/*' -print0 | sort -z); \
	if [ "$$failed" -ne 0 ]; then \
		echo "File mode check failed."; \
		exit 1; \
	fi; \
	echo "OK: file modes look consistent."

.PHONY: check
check: syntax file-modes
	@git diff --check
	@echo "OK: local checks passed."

.PHONY: smoke
smoke:
	@mkdir -p reports
	@echo "Running read-only smoke test into: $(REPORT_DIR)"
	@./scripts/reporting/sasd-run-readonly-checks.sh --output "$(REPORT_DIR)"
	@echo
	@echo "Smoke test index:"
	@echo "$(REPORT_DIR)/INDEX.md"

.PHONY: clean-reports
clean-reports:
	@rm -rf reports/*
	@echo "Removed generated report directories below reports/."
