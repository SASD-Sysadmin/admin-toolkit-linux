#!/usr/bin/env bash
# Path: scripts/monitoring/check_reboot_required.sh
# Purpose: Monitoring plugin: check whether a reboot is required.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: check_reboot_required.sh

Nagios/Icinga style reboot-required check.
Exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

if [[ -f /var/run/reboot-required ]]; then
  packages=""
  if [[ -r /var/run/reboot-required.pkgs ]]; then
    packages=" packages: $(tr '\n' ' ' < /var/run/reboot-required.pkgs | sed 's/[[:space:]]*$//')"
  fi
  echo "WARNING - reboot required.${packages}"
  exit 1
fi

if command -v needs-restarting >/dev/null 2>&1; then
  if needs-restarting -r >/dev/null 2>&1; then
    echo "OK - no reboot required"
    exit 0
  else
    echo "WARNING - reboot required according to needs-restarting"
    exit 1
  fi
fi

echo "OK - no Debian-style reboot marker found"
exit 0
