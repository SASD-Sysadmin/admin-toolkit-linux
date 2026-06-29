#!/usr/bin/env bash
# Path: scripts/monitoring/check_service_active.sh
# Purpose: Monitoring-style check for an active systemd service.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: check_service_active.sh SERVICE

Check whether a systemd service is active.
Exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
EOF
}

service="${1:-}"

if [[ "$service" == "--help" || "$service" == "-h" || -z "$service" ]]; then
  usage
  [[ -z "$service" ]] && exit 3 || exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "UNKNOWN - systemctl is not available"
  exit 3
fi

if systemctl is-active --quiet "$service"; then
  echo "OK - service $service is active"
  exit 0
fi

if systemctl list-unit-files --type=service --no-pager 2>/dev/null | awk '{print $1}' | grep -Fxq "$service.service" || systemctl status "$service" >/dev/null 2>&1; then
  echo "CRITICAL - service $service is not active"
  exit 2
fi

echo "UNKNOWN - service $service was not found"
exit 3
