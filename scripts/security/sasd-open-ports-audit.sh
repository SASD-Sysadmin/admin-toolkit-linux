#!/usr/bin/env bash
# Path: scripts/security/sasd-open-ports-audit.sh
# Purpose: Report local listening network ports and owning processes where available.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: sasd-open-ports-audit.sh [--help] [--version]

Report local listening TCP/UDP ports. This script does not scan remote hosts.
For full process information, run with sufficient privileges.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

cat <<EOF
# SASD Open Ports Audit

Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname 2>/dev/null || echo unknown)

EOF

if command -v ss >/dev/null 2>&1; then
  echo '```text'
  ss -tulpen 2>/dev/null || ss -tuln 2>/dev/null
  echo '```'
elif command -v netstat >/dev/null 2>&1; then
  echo '```text'
  netstat -tulpen 2>/dev/null || netstat -tuln 2>/dev/null
  echo '```'
else
  echo "ERROR: neither ss nor netstat is available" >&2
  exit 2
fi
