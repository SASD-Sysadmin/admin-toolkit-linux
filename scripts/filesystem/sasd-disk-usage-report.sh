#!/usr/bin/env bash
# Path: scripts/filesystem/sasd-disk-usage-report.sh
# Purpose: Create a read-only Markdown report about mounted filesystem usage.
# Date: 2026-06-29
# License: MIT
#
# This script is intentionally conservative:
# - It does not modify filesystems.
# - It uses standard Linux tools only.
# - It returns useful exit codes for automation.
#
# Exit codes:
#   0 = all checked filesystems are below warning threshold
#   1 = at least one filesystem is at or above warning threshold
#   2 = at least one filesystem is at or above critical threshold
#   3 = unknown / invalid arguments / required command missing

set -uo pipefail

VERSION="0.2.0"
WARNING=80
CRITICAL=90
INCLUDE_ALL=0

usage() {
  cat <<'USAGE'
Usage: sasd-disk-usage-report.sh [OPTIONS]

Create a Markdown report for mounted filesystem usage.

Options:
  -w, --warning PERCENT    Warning threshold, default: 80
  -c, --critical PERCENT   Critical threshold, default: 90
      --all                Include pseudo, tmpfs and special filesystems
  -h, --help               Show this help text
      --version            Print version

Examples:
  scripts/filesystem/sasd-disk-usage-report.sh
  scripts/filesystem/sasd-disk-usage-report.sh --warning 75 --critical 90
  scripts/filesystem/sasd-disk-usage-report.sh --all

Notes:
  The script is read-only. It does not delete files and does not remount anything.
USAGE
}

is_integer_percent() {
  # Accept integers from 0 to 100. Thresholds outside this range usually indicate
  # a typing mistake, so the script treats them as invalid input.
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 0 && "$1" <= 100 ))
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--warning)
      WARNING="${2:-}"
      shift 2
      ;;
    -c|--critical)
      CRITICAL="${2:-}"
      shift 2
      ;;
    --all)
      INCLUDE_ALL=1
      shift
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

if ! is_integer_percent "$WARNING" || ! is_integer_percent "$CRITICAL" || (( WARNING >= CRITICAL )); then
  echo "UNKNOWN - thresholds must be integers with warning < critical" >&2
  exit 3
fi

if ! command -v df >/dev/null 2>&1; then
  echo "UNKNOWN - df command is not available" >&2
  exit 3
fi

printf '# Disk Usage Report\n\n'
printf 'Generated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Warning threshold: %s%%  \n' "$WARNING"
printf 'Critical threshold: %s%%\n\n' "$CRITICAL"
printf '| Status | Filesystem | Type | Size | Used | Available | Use%% | Mounted on |\n'
printf '| --- | --- | --- | ---: | ---: | ---: | ---: | --- |\n'

# df -PT produces stable, parseable output on GNU/Linux:
# Filesystem Type 1024-blocks Used Available Capacity Mounted on
# We intentionally skip the header line and evaluate one filesystem per row.
status_code=0
while IFS= read -r line; do
  filesystem="$(awk '{print $1}' <<<"$line")"
  fstype="$(awk '{print $2}' <<<"$line")"
  size="$(awk '{print $3}' <<<"$line")"
  used="$(awk '{print $4}' <<<"$line")"
  available="$(awk '{print $5}' <<<"$line")"
  use_percent_raw="$(awk '{print $6}' <<<"$line")"
  mountpoint="$(awk '{print $7}' <<<"$line")"
  use_percent="${use_percent_raw%%%}"

  # Pseudo filesystems can dominate reports on modern Linux systems. By default,
  # we focus on storage-backed filesystems. --all shows everything.
  if (( INCLUDE_ALL == 0 )); then
    case "$fstype" in
      tmpfs|devtmpfs|proc|sysfs|cgroup|cgroup2|pstore|securityfs|debugfs|tracefs|configfs|fusectl|overlay)
        continue
        ;;
    esac
  fi

  if ! [[ "$use_percent" =~ ^[0-9]+$ ]]; then
    continue
  fi

  status="OK"
  if (( use_percent >= CRITICAL )); then
    status="CRITICAL"
    status_code=2
  elif (( use_percent >= WARNING )); then
    status="WARNING"
    if (( status_code < 1 )); then
      status_code=1
    fi
  fi

  printf '| %s | `%s` | `%s` | %s | %s | %s | %s%% | `%s` |\n' \
    "$status" "$filesystem" "$fstype" "$size" "$used" "$available" "$use_percent" "$mountpoint"
done < <(df -PT 2>/dev/null | awk 'NR > 1')

exit "$status_code"
