#!/usr/bin/env bash
# Path: scripts/monitoring/check_inodes.sh
# Purpose: Monitoring-style inode usage check for one mount point or path.
# Date: 2026-06-30
# License: MIT
#
# Exit codes follow common Nagios/Icinga plugin conventions:
#   0 = OK
#   1 = WARNING
#   2 = CRITICAL
#   3 = UNKNOWN

set -uo pipefail

VERSION="0.1.0"
WARNING=80
CRITICAL=90
CHECK_PATH="/"

usage() {
  cat <<'USAGE'
Usage: check_inodes.sh [OPTIONS]

Check inode usage for one mount point or path.

Options:
  -p, --path PATH        Mount point or path to check, default: /
  -w, --warning PERCENT Warning threshold, default: 80
  -c, --critical PERCENT Critical threshold, default: 90
  -h, --help            Show this help text
      --version         Print version

Examples:
  scripts/monitoring/check_inodes.sh -p / -w 70 -c 85
  scripts/monitoring/check_inodes.sh --path /var --warning 75 --critical 90

Exit codes:
  0 OK
  1 WARNING
  2 CRITICAL
  3 UNKNOWN
USAGE
}

is_percent() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 0 && "$1" <= 100 ))
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--path)
      CHECK_PATH="${2:-}"
      shift 2
      ;;
    -w|--warning)
      WARNING="${2:-}"
      shift 2
      ;;
    -c|--critical)
      CRITICAL="${2:-}"
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
      echo "UNKNOWN - unsupported argument: $1"
      exit 3
      ;;
  esac
done

if ! is_percent "$WARNING" || ! is_percent "$CRITICAL" || (( WARNING >= CRITICAL )); then
  echo "UNKNOWN - thresholds must be integers with warning < critical"
  exit 3
fi

if [[ -z "$CHECK_PATH" ]]; then
  echo "UNKNOWN - path must not be empty"
  exit 3
fi

if [[ ! -e "$CHECK_PATH" ]]; then
  echo "UNKNOWN - path does not exist: $CHECK_PATH"
  exit 3
fi

if ! command -v df >/dev/null 2>&1; then
  echo "UNKNOWN - df command is not available"
  exit 3
fi

line="$(df -Pi "$CHECK_PATH" 2>/dev/null | tail -n 1 || true)"
if [[ -z "$line" ]]; then
  echo "UNKNOWN - could not read inode usage for $CHECK_PATH"
  exit 3
fi

filesystem="$(awk '{print $1}' <<<"$line")"
inodes="$(awk '{print $2}' <<<"$line")"
iused="$(awk '{print $3}' <<<"$line")"
ifree="$(awk '{print $4}' <<<"$line")"
iuse_percent_raw="$(awk '{print $5}' <<<"$line")"
mounted_on="$(awk '{print $6}' <<<"$line")"
iuse_percent="${iuse_percent_raw%%%}"

if ! [[ "$iuse_percent" =~ ^[0-9]+$ ]]; then
  echo "UNKNOWN - inode usage is not available for $CHECK_PATH on $filesystem"
  exit 3
fi

perfdata="inodes_used_percent=${iuse_percent}%;${WARNING};${CRITICAL};0;100 inodes_used=${iused};;;; inodes_free=${ifree};;;; inodes_total=${inodes};;;;"

if (( iuse_percent >= CRITICAL )); then
  echo "CRITICAL - $mounted_on inode usage is ${iuse_percent}% on $filesystem | $perfdata"
  exit 2
fi

if (( iuse_percent >= WARNING )); then
  echo "WARNING - $mounted_on inode usage is ${iuse_percent}% on $filesystem | $perfdata"
  exit 1
fi

echo "OK - $mounted_on inode usage is ${iuse_percent}% on $filesystem | $perfdata"
exit 0
