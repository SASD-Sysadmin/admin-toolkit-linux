#!/usr/bin/env bash
# Path: scripts/security/sasd-suid-sgid-audit.sh
# Purpose: Find SUID and SGID files in selected paths.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: sasd-suid-sgid-audit.sh [PATH ...]

Find SUID and SGID files below the provided paths.
Default paths: /usr /bin /sbin /opt
No system changes are made.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

paths=("$@")
if [[ ${#paths[@]} -eq 0 ]]; then
  paths=(/usr /bin /sbin /opt)
fi

printf '# SUID/SGID Audit\n\nGenerated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf '```text\n'

find "${paths[@]}" -xdev -type f \( -perm -4000 -o -perm -2000 \) -printf '%m %u %g %p\n' 2>/dev/null | sort || true

printf '```\n'
