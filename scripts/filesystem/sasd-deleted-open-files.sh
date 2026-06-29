#!/usr/bin/env bash
# Path: scripts/filesystem/sasd-deleted-open-files.sh
# Purpose: Report deleted files that are still held open by running processes.
# Date: 2026-06-29
# License: MIT
#
# Why this matters:
#   A common Linux operations problem is "disk is full, but I already deleted
#   files". If a process keeps a deleted file open, the disk space is not released
#   until the process closes the file or restarts. This script helps identify those
#   processes without changing the system.
#
# Exit codes:
#   0 = no deleted open files found
#   1 = deleted open files found
#   3 = unknown / insufficient tooling

set -uo pipefail

VERSION="0.2.0"
LIMIT=200

usage() {
  cat <<'USAGE'
Usage: sasd-deleted-open-files.sh [OPTIONS]

Report deleted files that are still open by running processes.

Options:
      --limit NUMBER   Maximum number of rows to print, default: 200
  -h, --help           Show this help text
      --version        Print version

Notes:
  The script is read-only. Running it as root usually gives a more complete view.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      LIMIT="${2:-}"
      shift 2
      ;;
    --version)
      echo "$VERSION"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN - unsupported argument: $1" >&2
      usage >&2
      exit 3
      ;;
  esac
done

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || (( LIMIT < 1 )); then
  echo "UNKNOWN - --limit must be a positive integer" >&2
  exit 3
fi

printf '# Deleted Open Files Report\n\n'
printf 'Generated: %s\n\n' "$(date -Is 2>/dev/null || date)"

found=0

if command -v lsof >/dev/null 2>&1; then
  # lsof +L1 lists open files with fewer than one link, which is the standard
  # way to find deleted-but-open files. We keep a header and then limit rows.
  printf 'Method: `lsof +L1`\n\n'
  printf '```text\n'
  if lsof_output="$(lsof +L1 2>/dev/null | head -n $((LIMIT + 1)))" && [[ -n "$lsof_output" ]]; then
    printf '%s\n' "$lsof_output"
    if (( $(wc -l <<<"$lsof_output") > 1 )); then
      found=1
    fi
  else
    echo 'No deleted open files found, or lsof could not access process data.'
  fi
  printf '```\n'
  exit "$found"
fi

# Fallback for minimal systems without lsof. It inspects /proc/*/fd symlinks.
# This is less rich than lsof, but it still identifies PID and file descriptor.
if [[ ! -d /proc ]]; then
  echo 'UNKNOWN - neither lsof nor /proc is available' >&2
  exit 3
fi

printf 'Method: `/proc/*/fd` fallback\n\n'
printf '| PID | FD | Target |\n'
printf '| ---: | ---: | --- |\n'

rows=0
for fd in /proc/[0-9]*/fd/*; do
  [[ -e "$fd" ]] || continue
  target="$(readlink "$fd" 2>/dev/null || true)"
  if [[ "$target" == *'(deleted)'* ]]; then
    pid="${fd#/proc/}"
    pid="${pid%%/*}"
    fdnum="${fd##*/}"
    printf '| %s | %s | `%s` |\n' "$pid" "$fdnum" "$target"
    found=1
    rows=$((rows + 1))
    if (( rows >= LIMIT )); then
      break
    fi
  fi
done

if (( found == 0 )); then
  printf '\nNo deleted open files found.\n'
fi

exit "$found"
