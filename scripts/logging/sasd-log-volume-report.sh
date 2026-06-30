#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/logging/sasd-log-volume-report.sh
# Purpose: Report visible log volume and largest log files/directories.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model:
#   Read-only. This script does not rotate, compress, delete or truncate logs.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_PATH="/var/log"
MAX_LINES=40
ONE_FILE_SYSTEM=1

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Options:
  --path PATH         Log path to inspect. Default: /var/log.
  --max-lines N       Maximum largest-file entries to show. Default: 40.
  --cross-filesystems Allow crossing filesystem boundaries.
  --one-file-system   Stay on one filesystem. Default.
  -h, --help          Show this help.

Examples:
  ./scripts/logging/sasd-log-volume-report.sh
  ./scripts/logging/sasd-log-volume-report.sh --path /var/log --max-lines 20
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      [[ $# -ge 2 ]] || { echo "ERROR: --path requires a value" >&2; exit 2; }
      LOG_PATH="$2"
      shift 2
      ;;
    --max-lines)
      [[ $# -ge 2 ]] || { echo "ERROR: --max-lines requires a value" >&2; exit 2; }
      [[ "$2" =~ ^[0-9]+$ ]] || { echo "ERROR: --max-lines must be numeric" >&2; exit 2; }
      MAX_LINES="$2"
      shift 2
      ;;
    --cross-filesystems)
      ONE_FILE_SYSTEM=0
      shift
      ;;
    --one-file-system)
      ONE_FILE_SYSTEM=1
      shift
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

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

cat <<HEADER
# SASD Log Volume Report

- Generated: $(date -Is)
- Host: $(hostname 2>/dev/null || echo unknown)
- Path: \`$LOG_PATH\`
- Max entries: $MAX_LINES
- One filesystem: $([[ "$ONE_FILE_SYSTEM" -eq 1 ]] && echo yes || echo no)

> Read-only report. This script does not rotate, compress, delete or truncate logs.
HEADER

echo

if [[ ! -e "$LOG_PATH" ]]; then
  echo "INFO: log path does not exist: $LOG_PATH"
  exit 0
fi

if [[ ! -r "$LOG_PATH" ]]; then
  echo "INFO: log path is not readable by this user: $LOG_PATH"
  exit 0
fi

echo "## Summary"
echo

echo "| Metric | Value |"
echo "| --- | --- |"
if have_cmd du; then
  size="$(du -sh "$LOG_PATH" 2>/dev/null | awk '{print $1}' || true)"
  [[ -n "$size" ]] || size="unknown"
else
  size="du not available"
fi
echo "| Visible total size | $size |"

echo "| Direct child entries | $(find "$LOG_PATH" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ') |"
echo "| Regular files visible | $(find "$LOG_PATH" ${ONE_FILE_SYSTEM:+-xdev} -type f 2>/dev/null | wc -l | tr -d ' ') |"
echo "| Directories visible | $(find "$LOG_PATH" ${ONE_FILE_SYSTEM:+-xdev} -type d 2>/dev/null | wc -l | tr -d ' ') |"

echo

echo "## journald disk usage"
echo

if have_cmd journalctl; then
  echo '```text'
  journalctl --disk-usage 2>&1 | sed -n '1,20p'
  echo '```'
else
  echo "INFO: journalctl not available."
fi

echo

echo "## Largest visible files"
echo

find_args=()
if [[ "$ONE_FILE_SYSTEM" -eq 1 ]]; then
  find_args=(-xdev)
fi

tmp="$(mktemp)"
err="$(mktemp)"
if find "$LOG_PATH" "${find_args[@]}" -type f -printf '%s\t%p\n' >"$tmp" 2>"$err"; then
  if [[ -s "$tmp" ]]; then
    echo "| Size | Path |"
    echo "| ---: | --- |"
    sort -rn "$tmp" | head -n "$MAX_LINES" | while IFS=$'\t' read -r bytes path; do
      if have_cmd numfmt; then
        human="$(numfmt --to=iec --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B")"
      else
        human="${bytes}B"
      fi
      printf '| `%s` | `%s` |\n' "$human" "$path"
    done
  else
    echo "INFO: no regular files visible below $LOG_PATH."
  fi
else
  echo "INFO: find command failed."
fi

if [[ -s "$err" ]]; then
  echo
  echo "## Scan warnings"
  echo
  echo '```text'
  sed -n '1,80p' "$err"
  echo '```'
fi

rm -f "$tmp" "$err"
