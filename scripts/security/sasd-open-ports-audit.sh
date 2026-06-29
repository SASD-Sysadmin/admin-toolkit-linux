#!/usr/bin/env bash
# Path: scripts/security/sasd-open-ports-audit.sh
# Purpose: Report listening TCP/UDP sockets and related processes.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: sasd-open-ports-audit.sh [--help]

Report listening TCP/UDP sockets. This is a read-only audit helper.
No system changes are made.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

printf '# Open Ports Audit\n\nGenerated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf '```text\n'

if command -v ss >/dev/null 2>&1; then
  ss -tulpen 2>/dev/null || ss -tulpn 2>/dev/null || ss -tuln 2>/dev/null
elif command -v netstat >/dev/null 2>&1; then
  netstat -tulpen 2>/dev/null || netstat -tuln 2>/dev/null
else
  echo 'Neither ss nor netstat is available.'
  printf '```\n'
  exit 3
fi

printf '```\n'
