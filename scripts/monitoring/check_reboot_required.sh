#!/usr/bin/env bash
# Path: scripts/monitoring/check_reboot_required.sh
# Purpose: Monitoring-style check for reboot-required indicators.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: check_reboot_required.sh [--help]

Check common reboot-required indicators on Debian/Ubuntu-like systems.
Exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -f /var/run/reboot-required || -f /run/reboot-required ]]; then
  echo "WARNING - reboot required"
  exit 1
fi

echo "OK - no reboot-required marker found"
exit 0
