#!/usr/bin/env bash
# Path: scripts/host-doc/sasd-service-inventory.sh
# Purpose: Collect read-only systemd service inventory.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: sasd-service-inventory.sh [--help]

Print active, enabled and failed systemd services.
No system changes are made.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "ERROR: systemctl is not available" >&2
  exit 3
fi

section() {
  printf '\n## %s\n\n```text\n' "$1"
}

end_section() {
  printf '```\n'
}

printf '# Service Inventory\n\nGenerated: %s\n' "$(date -Is 2>/dev/null || date)"

section "Active services"
systemctl list-units --type=service --state=running --no-pager 2>/dev/null || true
end_section

section "Enabled service files"
systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null || true
end_section

section "Failed units"
systemctl --failed --no-pager 2>/dev/null || true
end_section
