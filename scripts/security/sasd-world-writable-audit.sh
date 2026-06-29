#!/usr/bin/env bash
# Path: scripts/security/sasd-world-writable-audit.sh
# Purpose: Find world-writable files and directories in selected paths.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: sasd-world-writable-audit.sh [PATH...]
       sasd-world-writable-audit.sh --help

Find world-writable files and directories. Default paths: /tmp /var/tmp /usr /opt /var
This script is read-only.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

paths=("$@")
if [[ ${#paths[@]} -eq 0 ]]; then
  paths=(/tmp /var/tmp /usr /opt /var)
fi

cat <<EOF
# SASD World-Writable Audit

Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname 2>/dev/null || echo unknown)
Paths: ${paths[*]}

Note: World-writable directories with sticky bit, such as /tmp, can be normal.

EOF

echo '```text'
find "${paths[@]}" \
  \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
  -perm -0002 -printf '%m %u %g %y %p\n' 2>/dev/null | sort || true
echo '```'
