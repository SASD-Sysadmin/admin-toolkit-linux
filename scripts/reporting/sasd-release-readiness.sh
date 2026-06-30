#!/usr/bin/env bash
# scripts/reporting/sasd-release-readiness.sh
#
# Purpose:
#   Read-only repository readiness review before tagging a release.
#
# Scope:
#   This script checks local repository hygiene. It does not create tags, commit
#   files, change permissions, run destructive commands or contact GitHub.

set -u
set -o pipefail

FORMAT="markdown"
RUN_SMOKE=0
MAX_OUTPUT_LINES=80

usage() {
  cat <<'USAGE'
Usage:
  sasd-release-readiness.sh [options]

Options:
  --format markdown|text   Output format. Default: markdown
  --run-smoke              Also run make smoke. Disabled by default because it can take time.
  --max-output-lines N     Limit captured command output in report. Default: 80
  -h, --help               Show this help.

Exit codes:
  0 - readiness checks completed without blocking findings
  1 - one or more release-blocking checks failed
  2 - invalid arguments or not running inside the repository
USAGE
}

is_positive_int() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) [ "$1" -gt 0 ] ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --format)
      [ "$#" -ge 2 ] || { echo "ERROR: --format requires a value" >&2; exit 2; }
      FORMAT="$2"
      shift 2
      ;;
    --run-smoke)
      RUN_SMOKE=1
      shift
      ;;
    --max-output-lines)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-output-lines requires a value" >&2; exit 2; }
      MAX_OUTPUT_LINES="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$FORMAT" in
  markdown|text) ;;
  *) echo "ERROR: unsupported format: $FORMAT" >&2; exit 2 ;;
esac

if ! is_positive_int "$MAX_OUTPUT_LINES"; then
  echo "ERROR: --max-output-lines must be a positive integer" >&2
  exit 2
fi

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: not inside a git repository" >&2
  exit 2
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || exit 2

HOSTNAME_VALUE="$(hostname 2>/dev/null || printf 'unknown')"
GENERATED="$(date -Is 2>/dev/null || date)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
CURRENT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
SCRIPT_COUNT="$(find scripts -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
DOC_COUNT="$(find docs -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
BLOCKERS=0
WARNINGS=0

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

run_check() {
  name="$1"
  severity="$2"
  shift 2
  outfile="$TMP_DIR/$(printf '%s' "$name" | tr ' /' '__').out"

  if "$@" >"$outfile" 2>&1; then
    result="OK"
  else
    result="FAIL"
    if [ "$severity" = "BLOCKER" ]; then
      BLOCKERS=$((BLOCKERS + 1))
    else
      WARNINGS=$((WARNINGS + 1))
    fi
  fi

  if [ "$FORMAT" = "markdown" ]; then
    printf '| `%s` | `%s` | `%s` |\n' "$result" "$severity" "$name"
  else
    printf '%-6s %-8s %s\n' "$result" "$severity" "$name"
  fi
}

check_clean_worktree() {
  [ -z "$(git status --porcelain)" ]
}

check_diff_check() {
  git diff --check
}

check_make_check() {
  make check
}

check_reports_ignored() {
  git check-ignore -q reports/local-test-placeholder.md
}

check_gitattributes() {
  [ -f .gitattributes ] && grep -q 'text=auto' .gitattributes
}

check_readme() {
  [ -f README.md ] && grep -qi 'read-only\|readonly' README.md && grep -qi 'script' README.md
}

check_changelog() {
  [ -f CHANGELOG.md ] && grep -q '0.1.0\|Unreleased' CHANGELOG.md
}

check_license() {
  [ -f LICENSE ]
}

check_release_docs() {
  [ -f docs/release-checklist.md ] || [ -f docs/release-readiness.md ]
}

check_script_count() {
  [ "$SCRIPT_COUNT" -ge 20 ]
}

check_executable_scripts() {
  bad=0
  while IFS= read -r script; do
    if [ ! -x "$script" ]; then
      echo "not executable: $script"
      bad=1
    fi
  done < <(find scripts -type f -name '*.sh' | sort)
  [ "$bad" -eq 0 ]
}

check_non_scripts_not_executable() {
  bad=0
  while IFS= read -r file; do
    case "$file" in
      ./.git/*|./scripts/*.sh|./scripts/*/*.sh) continue ;;
    esac
    if [ -x "$file" ] && [ -f "$file" ]; then
      echo "unexpected executable bit: $file"
      bad=1
    fi
  done < <(find . -type f -not -path './.git/*' | sort)
  [ "$bad" -eq 0 ]
}

run_smoke_check() {
  make smoke
}

if [ "$FORMAT" = "markdown" ]; then
  # Use printf instead of an unquoted here-doc here. Backticks in an
  # unquoted here-doc are command substitutions, which breaks paths and
  # branch names when Markdown code spans are used.
  printf '# SASD Release Readiness Report\n\n'
  printf -- '- Generated: %s\n' "$GENERATED"
  printf -- '- Host: %s\n' "$HOSTNAME_VALUE"
  printf -- '- Repository: `%s`\n' "$ROOT"
  printf -- '- Branch: `%s`\n' "$CURRENT_BRANCH"
  printf -- '- Commit: `%s`\n' "$CURRENT_COMMIT"
  printf -- '- Shell scripts: %s\n' "$SCRIPT_COUNT"
  printf -- '- Markdown docs: %s\n\n' "$DOC_COUNT"
  printf '> This is a read-only repository readiness check. It does not create a release tag.\n\n'
  printf '## Checks\n\n'
  printf '| Result | Severity | Check |\n'
  printf '| --- | --- | --- |\n'
else
  cat <<HEADER
SASD Release Readiness Report
Generated: $GENERATED
Host:      $HOSTNAME_VALUE
Repository: $ROOT
Branch:     $CURRENT_BRANCH
Commit:     $CURRENT_COMMIT
Scripts:    $SCRIPT_COUNT
Docs:       $DOC_COUNT

Checks
------
HEADER
fi

run_check "working tree is clean" "BLOCKER" check_clean_worktree
run_check "git diff --check passes" "BLOCKER" check_diff_check
run_check "make check passes" "BLOCKER" check_make_check
run_check "shell scripts are executable" "BLOCKER" check_executable_scripts
run_check "non-script files are not executable" "BLOCKER" check_non_scripts_not_executable
run_check "reports directory is ignored" "BLOCKER" check_reports_ignored
run_check ".gitattributes normalizes line endings" "WARN" check_gitattributes
run_check "README describes read-only script toolkit" "WARN" check_readme
run_check "CHANGELOG has release/unreleased section" "WARN" check_changelog
run_check "LICENSE exists" "BLOCKER" check_license
run_check "release documentation exists" "WARN" check_release_docs
run_check "script inventory is substantial" "WARN" check_script_count

if [ "$RUN_SMOKE" -eq 1 ]; then
  run_check "make smoke passes" "BLOCKER" run_smoke_check
fi

if [ "$FORMAT" = "markdown" ]; then
  cat <<SUMMARY

## Summary

| Metric | Value |
| --- | ---: |
| Blocking failures | $BLOCKERS |
| Warnings | $WARNINGS |

SUMMARY
  if [ "$BLOCKERS" -eq 0 ]; then
    cat <<'OK'
Result: **release candidate looks taggable after human review**.

Suggested manual checks before tagging:

1. Review `README.md`, `docs/script-index.md`, and `CHANGELOG.md` in GitHub.
2. Run one final `make check && make smoke` locally.
3. Inspect the generated smoke report and `89-findings-summary.md`.
4. Tag only after confirming the repository state is intentionally read-only.
OK
  else
    cat <<'FAIL'
Result: **do not tag yet**. Resolve blocking failures first.
FAIL
  fi
else
  cat <<SUMMARY

Summary
-------
Blocking failures: $BLOCKERS
Warnings:          $WARNINGS
SUMMARY
  if [ "$BLOCKERS" -eq 0 ]; then
    echo "Result: release candidate looks taggable after human review."
  else
    echo "Result: do not tag yet. Resolve blocking failures first."
  fi
fi

if [ "$BLOCKERS" -eq 0 ]; then
  exit 0
fi

exit 1
