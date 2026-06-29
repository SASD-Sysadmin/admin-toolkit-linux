#!/usr/bin/env bash
# Path: scripts/security/sasd-sensitive-files-check.sh
# Purpose: Find potentially sensitive files in a repository or directory tree.
# Date: 2026-06-29
# License: MIT
#
# Why this matters:
#   Public repositories must not contain secrets, private keys, database dumps,
#   environment files or customer data. This script is a lightweight pre-flight
#   check before committing or publishing files.
#
# Exit codes:
#   0 = no potential sensitive files found
#   1 = potential sensitive files found
#   3 = unknown / invalid argument

set -uo pipefail

VERSION="0.2.0"
SCAN_PATH="."
MAX_DEPTH=6

usage() {
  cat <<'USAGE'
Usage: sasd-sensitive-files-check.sh [OPTIONS]

Find filenames that often indicate secrets or sensitive data.

Options:
      --path DIR          Directory to scan, default: current directory
      --max-depth NUMBER  Maximum find depth, default: 6
  -h, --help              Show this help text
      --version           Print version

Examples:
  scripts/security/sasd-sensitive-files-check.sh
  scripts/security/sasd-sensitive-files-check.sh --path /srv/project --max-depth 8

Notes:
  This is a filename-based helper. It does not prove that a repository is clean.
  It is intentionally conservative and may produce false positives.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      SCAN_PATH="${2:-}"
      shift 2
      ;;
    --max-depth)
      MAX_DEPTH="${2:-}"
      shift 2
      ;;
    --version)
      echo "$VERSION"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN - unsupported argument: $1" >&2
      usage >&2
      exit 3
      ;;
  esac
done

if [[ ! -d "$SCAN_PATH" ]]; then
  echo "UNKNOWN - scan path is not a directory: $SCAN_PATH" >&2
  exit 3
fi

if ! [[ "$MAX_DEPTH" =~ ^[0-9]+$ ]] || (( MAX_DEPTH < 1 )); then
  echo "UNKNOWN - --max-depth must be a positive integer" >&2
  exit 3
fi

printf '# Sensitive Files Check\n\n'
printf 'Generated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Scan path: `%s`  \n' "$SCAN_PATH"
printf 'Maximum depth: `%s`\n\n' "$MAX_DEPTH"
printf '| Severity | Reason | Path |\n'
printf '| --- | --- | --- |\n'

found=0

# Exclude .git because it contains internal object storage and can produce many
# false positives. The goal is to check project files, not Git internals.
while IFS= read -r -d '' file; do
  name="${file##*/}"
  reason=""
  severity="REVIEW"

  case "$name" in
    .env|.env.*|*.env)
      reason="environment file"
      severity="HIGH"
      ;;
    id_rsa|id_dsa|id_ecdsa|id_ed25519|*.pem|*.key|*.p12|*.pfx)
      reason="private key or certificate container"
      severity="HIGH"
      ;;
    *.kdbx|*.gpg|*.asc)
      reason="encrypted secret store or key material"
      severity="HIGH"
      ;;
    *password*|*passwd*|*secret*|*token*|*credential*)
      reason="sensitive keyword in filename"
      severity="REVIEW"
      ;;
    *.sql|*.dump|*.bak|*.backup)
      reason="backup or database dump candidate"
      severity="REVIEW"
      ;;
    *)
      continue
      ;;
  esac

  printf '| %s | %s | `%s` |\n' "$severity" "$reason" "$file"
  found=1
done < <(
  find "$SCAN_PATH" \
    -path '*/.git' -prune -o \
    -maxdepth "$MAX_DEPTH" \
    -type f \
    -print0 2>/dev/null
)

if (( found == 0 )); then
  printf '| OK | No suspicious filenames found | `%s` |\n' "$SCAN_PATH"
fi

exit "$found"
