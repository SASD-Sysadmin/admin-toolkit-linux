#!/usr/bin/env bash
# Path: scripts/host-doc/sasd-package-inventory.sh
# Purpose: Document installed packages on common Linux distributions.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: sasd-package-inventory.sh [--help] [--version]

Create a read-only package inventory for Debian/Ubuntu or RPM-based Linux systems.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

cat <<EOF
# SASD Package Inventory

Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname 2>/dev/null || echo unknown)

EOF

if command -v dpkg-query >/dev/null 2>&1; then
  echo '```text'
  dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' | sort
  echo '```'
elif command -v rpm >/dev/null 2>&1; then
  echo '```text'
  rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\n' | sort
  echo '```'
elif command -v pacman >/dev/null 2>&1; then
  echo '```text'
  pacman -Q | sort
  echo '```'
else
  echo "ERROR: no supported package manager found" >&2
  exit 2
fi
