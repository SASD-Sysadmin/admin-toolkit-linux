#!/usr/bin/env bash
# Path: scripts/logging/sasd-journal-errors.sh
# Purpose: Summarize warning and error messages from systemd-journald.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

SINCE="${SINCE:-today}"

usage() {
  cat <<'EOF'
Usage: sasd-journal-errors.sh [--since VALUE]

Summarize journal entries with priority warning or worse.
Default: --since today
No system changes are made.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --since)
      SINCE="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 3
      ;;
  esac
done

if ! command -v journalctl >/dev/null 2>&1; then
  echo "UNKNOWN: journalctl is not available"
  exit 3
fi

printf '# Journal Warning/Error Summary\n\nGenerated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Since: `%s`\n\n' "$SINCE"
printf '```text\n'
journalctl --since "$SINCE" -p warning..alert --no-pager 2>/dev/null | tail -n 200 || true
printf '```\n'
