#!/usr/bin/env bash
# Path: scripts/host-doc/sasd-service-inventory.sh
# Purpose: Document systemd service state.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: sasd-service-inventory.sh [--help] [--version]

Create a read-only Markdown report of running, failed and enabled systemd services.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "ERROR: systemctl not available" >&2
  exit 2
fi

section() { printf '\n## %s\n\n```text\n' "$1"; cat; printf '```\n'; }

cat <<EOF
# SASD Service Inventory

Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname 2>/dev/null || echo unknown)
EOF

systemctl list-units --type=service --state=running --no-pager 2>/dev/null | section "Running Services"
systemctl --failed --no-pager 2>/dev/null | section "Failed Units"
systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null | section "Enabled Service Files"
