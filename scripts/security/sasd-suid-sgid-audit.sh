#!/usr/bin/env bash
# Path: scripts/security/sasd-suid-sgid-audit.sh
# Purpose: Find SUID and SGID files in selected paths.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: sasd-suid-sgid-audit.sh [PATH...]
       sasd-suid-sgid-audit.sh --help

Find files with SUID or SGID bits. Default paths: /usr /bin /sbin /opt /var
This script is read-only.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

paths=("$@")
if [[ ${#paths[@]} -eq 0 ]]; then
  paths=(/usr /bin /sbin /opt /var)
fi

cat <<EOF
# SASD SUID/SGID Audit

Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname 2>/dev/null || echo unknown)
Paths: ${paths[*]}

EOF

echo '```text'
find "${paths[@]}" \
  \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
  -type f -perm /6000 -printf '%m %u %g %p\n' 2>/dev/null | sort || true
echo '```'
