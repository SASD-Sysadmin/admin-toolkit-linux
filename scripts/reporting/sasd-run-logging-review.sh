#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/reporting/sasd-run-logging-review.sh
# Purpose: Run the logging-focused Milestone 3 read-only review scripts.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model:
#   Read-only. Creates local report files only.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
OUTPUT_DIR=""
SINCE="24 hours ago"
MAX_LINES=200

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Options:
  --output DIR        Output directory. Default: reports/logging-review-<timestamp>.
  --since VALUE       Time window for time-based log reports. Default: "24 hours ago".
  --max-lines N       Maximum detailed lines for selected reports. Default: 200.
  -h, --help          Show this help.

Examples:
  ./scripts/reporting/sasd-run-logging-review.sh
  ./scripts/reporting/sasd-run-logging-review.sh --since today --output ./reports/logging-today
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || { echo "ERROR: --output requires a directory" >&2; exit 2; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --since)
      [[ $# -ge 2 ]] || { echo "ERROR: --since requires a value" >&2; exit 2; }
      SINCE="$2"
      shift 2
      ;;
    --max-lines)
      [[ $# -ge 2 ]] || { echo "ERROR: --max-lines requires a value" >&2; exit 2; }
      [[ "$2" =~ ^[0-9]+$ ]] || { echo "ERROR: --max-lines must be numeric" >&2; exit 2; }
      MAX_LINES="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

ROOT="$(repo_root)"
cd "$ROOT" || exit 2

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="reports/logging-review-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUTPUT_DIR" || exit 2
STATUS_FILE="$OUTPUT_DIR/status.tsv"
INDEX_FILE="$OUTPUT_DIR/INDEX.md"
: >"$STATUS_FILE"
printf 'status\tscript\toutput\n' >"$STATUS_FILE"

run_report() {
  local script="$1"
  local output="$2"
  shift 2
  local status

  if [[ ! -x "$script" ]]; then
    printf '2\t%s\t%s\n' "$script" "$output" >>"$STATUS_FILE"
    printf 'ERROR: script is not executable: %s\n' "$script" >"$OUTPUT_DIR/$output"
    return 0
  fi

  if "$script" "$@" >"$OUTPUT_DIR/$output" 2>&1; then
    status=0
  else
    status=$?
  fi
  printf '%s\t%s\t%s\n' "$status" "$script" "$output" >>"$STATUS_FILE"
}

run_report scripts/config/sasd-journald-config-report.sh 01-journald-config.md
run_report scripts/config/sasd-logrotate-report.sh 02-logrotate.md
run_report scripts/logging/sasd-journal-errors.sh 10-journal-errors.md
run_report scripts/logging/sasd-auth-log-report.sh 11-auth-log.md
run_report scripts/logging/sasd-sudo-usage-report.sh 12-sudo-usage.md --since "$SINCE" --max-lines "$MAX_LINES"
run_report scripts/logging/sasd-kernel-warnings.sh 13-kernel-warnings.md --since "$SINCE" --max-lines "$MAX_LINES"
run_report scripts/logging/sasd-log-volume-report.sh 14-log-volume.md --max-lines "$MAX_LINES"

{
  echo "# SASD Logging Review Collection"
  echo
  echo "- Generated: $(date -Is)"
  echo "- Host: $(hostname 2>/dev/null || echo unknown)"
  echo "- Repository root: \`$ROOT\`"
  echo "- Output directory: \`$OUTPUT_DIR\`"
  echo "- Since: \`$SINCE\`"
  echo
  echo "> This collection is read-only. Review output before sharing because logs can"
  echo "> contain hostnames, usernames, paths, IP addresses and operational details."
  echo
  echo "## Command status"
  echo
  echo "| Status | Script | Output |"
  echo "| ---: | --- | --- |"
  tail -n +2 "$STATUS_FILE" | while IFS=$'\t' read -r status script output; do
    printf '| %s | `%s` | [`%s`](%s) |\n' "$status" "$script" "$output" "$output"
  done
  echo
  echo "## Suggested review order"
  echo
  echo "1. Open \`10-journal-errors.md\` and \`13-kernel-warnings.md\` for recent error signals."
  echo "2. Open \`12-sudo-usage.md\` for privilege-use review."
  echo "3. Open \`14-log-volume.md\` for oversized or unexpectedly growing logs."
  echo "4. Compare \`01-journald-config.md\` and \`02-logrotate.md\` with expected retention policy."
} >"$INDEX_FILE"

echo "Report directory: $OUTPUT_DIR"
echo "Index: $INDEX_FILE"
