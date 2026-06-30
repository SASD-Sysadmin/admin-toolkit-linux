#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/logging/sasd-sudo-usage-report.sh
# Purpose: Summarize sudo usage from journald and authentication logs.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model:
#   Read-only. This script does not change sudoers, users, groups or logs.
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
  ./scripts/logging/sasd-sudo-usage-report.sh
  ./scripts/logging/sasd-sudo-usage-report.sh --since today --max-lines 100
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

print_header() {
  cat <<HEADER
# SASD Sudo Usage Report

- Generated: $(date -Is)
- Host: $(hostname 2>/dev/null || echo unknown)
- Since: \`$SINCE\`
- Max lines per source: $MAX_LINES

> Read-only report. Sudo usage is a review signal, not automatically suspicious.
HEADER
}

print_journal_sudo() {
  echo
  echo "## journald sudo entries"
  echo

  if ! have_cmd journalctl; then
    echo "INFO: journalctl not available."
    return 0
  fi

  local tmp err status total denied commands users
  tmp="$(mktemp)"
  err="$(mktemp)"
  if journalctl --since "$SINCE" _COMM=sudo --no-pager -o short-iso >"$tmp" 2>"$err"; then
    status=0
  else
    status=$?
  fi

  if [[ $status -ne 0 ]]; then
    echo "INFO: journalctl sudo query failed or is not permitted."
    echo
    echo '```text'
    sed -n '1,40p' "$err"
    echo '```'
    rm -f "$tmp" "$err"
    return 0
  fi

  total="$(wc -l <"$tmp" | tr -d ' ')"
  denied="$(grep -Ei 'not in the sudoers|incorrect password|authentication failure|user NOT in sudoers|TTY=unknown|session opened|session closed|COMMAND=' "$tmp" | grep -Eic 'not in the sudoers|incorrect password|authentication failure|user NOT in sudoers' || true)"
  commands="$(grep -Eic 'COMMAND=' "$tmp" || true)"
  users="$(sed -n 's/.*sudo\[[0-9]*\]:[[:space:]]*\([^ :]*\).*/\1/p' "$tmp" | sort -u | wc -l | tr -d ' ')"

  cat <<SUMMARY
| Metric | Value |
| --- | ---: |
| Total sudo journal entries | $total |
| Entries with COMMAND= | $commands |
| Denial/authentication-failure hints | $denied |
| Distinct sudo usernames observed | $users |
SUMMARY

  echo
  echo "### Recent sudo entries"
  echo
  if [[ "$total" -eq 0 ]]; then
    echo "INFO: no sudo journal entries found for this time window."
  else
    echo '```text'
    sed -n "1,${MAX_LINES}p" "$tmp"
    echo '```'
    if [[ "$total" -gt "$MAX_LINES" ]]; then
      echo
      echo "> Output truncated after $MAX_LINES lines. Use --max-lines to adjust."
    fi
  fi

  rm -f "$tmp" "$err"
}

print_authlog_sudo() {
  echo
  echo "## Auth log sudo entries"
  echo

  local log found count
  found=0
  for log in /var/log/auth.log /var/log/secure; do
    if [[ -r "$log" ]]; then
      found=1
      echo "### $log"
      echo
      count="$(grep -Eic 'sudo' "$log" || true)"
      echo "- Matching lines in current file: $count"
      echo
      if [[ "$count" -gt 0 ]]; then
        echo '```text'
        grep -Ei 'sudo' "$log" | tail -n "$MAX_LINES"
        echo '```'
      else
        echo "INFO: no sudo lines found in $log."
      fi
      echo
    fi
  done

  if [[ "$found" -eq 0 ]]; then
    echo "INFO: no readable auth log file found at /var/log/auth.log or /var/log/secure."
  fi
}

print_header
print_journal_sudo
print_authlog_sudo
