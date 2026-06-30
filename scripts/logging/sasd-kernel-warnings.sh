#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/logging/sasd-kernel-warnings.sh
# Purpose: Review recent kernel warnings and errors.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model:
#   Read-only. This script only queries journald/dmesg when permitted.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SINCE="24 hours ago"
MAX_LINES=200

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Options:
  --since VALUE       Time window for journalctl, e.g. "24 hours ago", "today".
                      Default: "24 hours ago".
  --max-lines N       Maximum detailed log lines to print per source. Default: 200.
  -h, --help          Show this help.

Examples:
  ./scripts/logging/sasd-kernel-warnings.sh
  ./scripts/logging/sasd-kernel-warnings.sh --since today --max-lines 100
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

cat <<HEADER
# SASD Kernel Warnings Report

- Generated: $(date -Is)
- Host: $(hostname 2>/dev/null || echo unknown)
- Since: \`$SINCE\`
- Max lines per source: $MAX_LINES

> Read-only report. Kernel warnings need context: hardware, drivers, containers,
> virtualization and desktop components can all generate noisy messages.
HEADER

echo

echo "## journald kernel warnings and errors"
echo

if have_cmd journalctl; then
  tmp="$(mktemp)"
  err="$(mktemp)"
  if journalctl -k --since "$SINCE" -p warning..alert --no-pager -o short-iso >"$tmp" 2>"$err"; then
    total="$(wc -l <"$tmp" | tr -d ' ')"
    cat <<SUMMARY
| Metric | Value |
| --- | ---: |
| Journal kernel warning/error entries | $total |
SUMMARY
    echo
    if [[ "$total" -gt 0 ]]; then
      echo '```text'
      sed -n "1,${MAX_LINES}p" "$tmp"
      echo '```'
      if [[ "$total" -gt "$MAX_LINES" ]]; then
        echo
        echo "> Output truncated after $MAX_LINES lines. Use --max-lines to adjust."
      fi
    else
      echo "INFO: no kernel warnings/errors found in journald for this time window."
    fi
  else
    echo "INFO: journalctl kernel query failed or is not permitted."
    echo
    echo '```text'
    sed -n '1,40p' "$err"
    echo '```'
  fi
  rm -f "$tmp" "$err"
else
  echo "INFO: journalctl not available."
fi

echo

echo "## dmesg fallback"
echo

if have_cmd dmesg; then
  tmp="$(mktemp)"
  err="$(mktemp)"
  if dmesg --level=warn,err,crit,alert,emerg >"$tmp" 2>"$err"; then
    total="$(wc -l <"$tmp" | tr -d ' ')"
    echo "- dmesg warning/error lines visible: $total"
    echo
    if [[ "$total" -gt 0 ]]; then
      echo '```text'
      tail -n "$MAX_LINES" "$tmp"
      echo '```'
    else
      echo "INFO: no dmesg warning/error lines visible."
    fi
  else
    echo "INFO: dmesg is not permitted or failed."
    echo
    echo '```text'
    sed -n '1,40p' "$err"
    echo '```'
  fi
  rm -f "$tmp" "$err"
else
  echo "INFO: dmesg not available."
fi
