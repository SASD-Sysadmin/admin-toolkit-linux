#!/usr/bin/env bash
# Path: scripts/security/sasd-world-writable-audit.sh
# Purpose: Find world-writable files and directories in selected paths.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: sasd-world-writable-audit.sh [PATH ...]

Find world-writable files and directories below the provided paths.
Default paths: /tmp /var /home /opt
No system changes are made.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

paths=("$@")
if [[ ${#paths[@]} -eq 0 ]]; then
  paths=(/tmp /var /home /opt)
fi

printf '# World-writable Audit\n\nGenerated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf '```text\n'

find "${paths[@]}" -xdev \( -type f -o -type d \) -perm -0002 -printf '%m %u %g %p\n' 2>/dev/null | sort || true

printf '```\n'
