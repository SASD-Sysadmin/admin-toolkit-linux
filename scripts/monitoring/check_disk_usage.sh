#!/usr/bin/env bash
# Path: scripts/monitoring/check_disk_usage.sh
# Purpose: Monitoring-style disk usage check for one mount point.
# Date: 2026-06-29
# License: MIT
#
# Exit codes follow common Nagios/Icinga plugin conventions:
#   0 = OK
#   1 = WARNING
#   2 = CRITICAL
#   3 = UNKNOWN

set -uo pipefail

VERSION="0.2.0"
WARNING=80
CRITICAL=90
MOUNTPOINT="/"

usage() {
  cat <<'USAGE'
Usage: check_disk_usage.sh [OPTIONS]

Check disk usage for one mount point.

Options:
  -p, --path PATH        Mount point or path to check, default: /
  -w, --warning PERCENT Warning threshold, default: 80
  -c, --critical PERCENT Critical threshold, default: 90
  -h, --help            Show this help text
      --version         Print version

Examples:
  scripts/monitoring/check_disk_usage.sh -p / -w 80 -c 90
  scripts/monitoring/check_disk_usage.sh --path /var --warning 75 --critical 90
USAGE
}

is_percent() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 0 && "$1" <= 100 ))
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--path)
      MOUNTPOINT="${2:-}"
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

if [[ ! -e "$MOUNTPOINT" ]]; then
  echo "UNKNOWN - path does not exist: $MOUNTPOINT"
  exit 3
fi

if ! command -v df >/dev/null 2>&1; then
  echo "UNKNOWN - df command is not available"
  exit 3
fi

# df -P keeps output predictable. tail -n 1 selects the data row.
line="$(df -P "$MOUNTPOINT" 2>/dev/null | tail -n 1 || true)"
if [[ -z "$line" ]]; then
  echo "UNKNOWN - could not read disk usage for $MOUNTPOINT"
  exit 3
fi

filesystem="$(awk '{print $1}' <<<"$line")"
size="$(awk '{print $2}' <<<"$line")"
used="$(awk '{print $3}' <<<"$line")"
available="$(awk '{print $4}' <<<"$line")"
use_percent_raw="$(awk '{print $5}' <<<"$line")"
mounted_on="$(awk '{print $6}' <<<"$line")"
use_percent="${use_percent_raw%%%}"

if ! [[ "$use_percent" =~ ^[0-9]+$ ]]; then
  echo "UNKNOWN - could not parse disk usage for $MOUNTPOINT"
  exit 3
fi

perfdata="used_percent=${use_percent}%;${WARNING};${CRITICAL};0;100 used_kb=${used}KB;;;; available_kb=${available}KB;;;; size_kb=${size}KB;;;;"

if (( use_percent >= CRITICAL )); then
  echo "CRITICAL - $mounted_on is ${use_percent}% full on $filesystem | $perfdata"
  exit 2
fi

if (( use_percent >= WARNING )); then
  echo "WARNING - $mounted_on is ${use_percent}% full on $filesystem | $perfdata"
  exit 1
fi

echo "OK - $mounted_on is ${use_percent}% full on $filesystem | $perfdata"
exit 0
