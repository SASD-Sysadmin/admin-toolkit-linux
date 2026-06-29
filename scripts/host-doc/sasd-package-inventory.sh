#!/usr/bin/env bash
# Path: scripts/host-doc/sasd-package-inventory.sh
# Purpose: Collect read-only package inventory on common Linux distributions.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: sasd-package-inventory.sh [--help]

Print installed package information for Debian/Ubuntu or RPM-based systems.
No system changes are made.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

printf '# Package Inventory\n\nGenerated: %s\n\n' "$(date -Is 2>/dev/null || date)"

if command -v dpkg-query >/dev/null 2>&1; then
  echo '## Debian packages'
  echo
  echo '```text'
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null | sort
  echo '```'
elif command -v rpm >/dev/null 2>&1; then
  echo '## RPM packages'
  echo
  echo '```text'
  rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' 2>/dev/null | sort
  echo '```'
else
  echo 'No supported package manager found.'
  exit 3
fi
