#!/usr/bin/env bash
# Path: scripts/monitoring/check_service_active.sh
# Purpose: Monitoring plugin: check whether a systemd service is active.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: check_service_active.sh SERVICE

Nagios/Icinga style check for a systemd service.
Exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

service="${1:-}"
if [[ -z "$service" ]]; then
  echo "UNKNOWN - service name missing"
  exit 3
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "UNKNOWN - systemctl not available"
  exit 3
fi

if systemctl is-active --quiet "$service"; then
  echo "OK - service '$service' is active"
  exit 0
fi

state="$(systemctl is-active "$service" 2>/dev/null || true)"
if systemctl list-unit-files "$service" >/dev/null 2>&1; then
  echo "CRITICAL - service '$service' is not active (state: ${state:-unknown})"
  exit 2
fi

echo "UNKNOWN - service '$service' not found"
exit 3
