#!/usr/bin/env bash
# Path: scripts/logging/sasd-journal-errors.sh
# Purpose: Summarize warning and error messages from systemd journal.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: sasd-journal-errors.sh [--since "24 hours ago"]
       sasd-journal-errors.sh --help

Create a read-only summary of journal messages with priority warning or higher.
EOF
}

since="24 hours ago"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --version) echo "$VERSION"; exit 0 ;;
    --since) since="${2:-}"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! command -v journalctl >/dev/null 2>&1; then
  echo "ERROR: journalctl not available" >&2
  exit 2
fi

cat <<EOF
# SASD Journal Warning/Error Summary

Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname 2>/dev/null || echo unknown)
Since: $since

## Messages

EOF

echo '```text'
journalctl -p warning..alert --since "$since" --no-pager 2>/dev/null | tail -n 300 || true
echo '```'
