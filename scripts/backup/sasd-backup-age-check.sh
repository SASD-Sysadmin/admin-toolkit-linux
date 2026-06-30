#!/usr/bin/env bash
# scripts/backup/sasd-backup-age-check.sh
#
# Purpose:
#   Read-only backup freshness check for a configured directory.
#
# Design goals:
#   - never modifies backup files
#   - safe in the generic collector even when no backup path is configured
#   - useful for explicit checks against real backup/snapshot directories
#
# Exit codes:
#   0 - check completed and policy is satisfied, or no path configured
#   1 - check completed but policy is not satisfied
#   2 - invalid arguments or configured path cannot be scanned

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
BACKUP_PATH="${SASD_BACKUP_CHECK_PATH:-}"
PATTERN="${SASD_BACKUP_CHECK_PATTERN:-*}"
MAX_AGE_DAYS="${SASD_BACKUP_CHECK_MAX_AGE_DAYS:-7}"
MIN_COUNT="${SASD_BACKUP_CHECK_MIN_COUNT:-1}"
MAX_SHOWN="${SASD_BACKUP_CHECK_MAX_SHOWN:-10}"
FORMAT="text"

usage() {
  cat <<'USAGE'
Usage:
  sasd-backup-age-check.sh [options]

Options:
  --path PATH            Backup/snapshot directory to scan.
  --pattern GLOB         File glob to match. Default: *
  --max-age-days N       Newest matching file must be at most N days old. Default: 7
  --min-count N          Minimum number of matching files expected. Default: 1
  --max-shown N          Show at most N newest matching files. Default: 10
  --format text|markdown Output format. Default: text
  -h, --help             Show this help.

Environment defaults:
  SASD_BACKUP_CHECK_PATH
  SASD_BACKUP_CHECK_PATTERN
  SASD_BACKUP_CHECK_MAX_AGE_DAYS
  SASD_BACKUP_CHECK_MIN_COUNT
  SASD_BACKUP_CHECK_MAX_SHOWN

Examples:
  ./scripts/backup/sasd-backup-age-check.sh --path /backup --pattern '*.tar.gz' --max-age-days 2
  SASD_BACKUP_CHECK_PATH=/backup ./scripts/backup/sasd-backup-age-check.sh

Notes:
  Without --path or SASD_BACKUP_CHECK_PATH this script exits 0 with an INFO
  report. This keeps the generic read-only collector usable on hosts where a
  backup location has not been configured yet.
USAGE
}

is_positive_int() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) [ "$1" -gt 0 ] ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      [ "$#" -ge 2 ] || { echo "ERROR: --path requires a value" >&2; exit 2; }
      BACKUP_PATH="$2"
      shift 2
      ;;
    --pattern)
      [ "$#" -ge 2 ] || { echo "ERROR: --pattern requires a value" >&2; exit 2; }
      PATTERN="$2"
      shift 2
      ;;
    --max-age-days)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-age-days requires a value" >&2; exit 2; }
      MAX_AGE_DAYS="$2"
      shift 2
      ;;
    --min-count)
      [ "$#" -ge 2 ] || { echo "ERROR: --min-count requires a value" >&2; exit 2; }
      MIN_COUNT="$2"
      shift 2
      ;;
    --max-shown)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-shown requires a value" >&2; exit 2; }
      MAX_SHOWN="$2"
      shift 2
      ;;
    --format)
      [ "$#" -ge 2 ] || { echo "ERROR: --format requires a value" >&2; exit 2; }
      FORMAT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$FORMAT" in
  text|markdown) ;;
  *) echo "ERROR: unsupported format: $FORMAT" >&2; exit 2 ;;
esac

for value_name in MAX_AGE_DAYS MIN_COUNT MAX_SHOWN; do
  value="$(eval "printf '%s' \"\${$value_name}\"")"
  if ! is_positive_int "$value"; then
    echo "ERROR: $value_name must be a positive integer" >&2
    exit 2
  fi
done

HOSTNAME_VALUE="$(hostname 2>/dev/null || printf 'unknown')"
GENERATED="$(date -Is 2>/dev/null || date)"

print_header() {
  if [ "$FORMAT" = "markdown" ]; then
    cat <<HEADER
# SASD Backup Age Check

- Generated: $GENERATED
- Host: $HOSTNAME_VALUE
- Path: ${BACKUP_PATH:-not configured}
- Pattern: $PATTERN
- Max age: $MAX_AGE_DAYS day(s)
- Min count: $MIN_COUNT

> This script is read-only. It checks file timestamps only and does not validate restoreability.

HEADER
  else
    cat <<HEADER
SASD Backup Age Check
Generated: $GENERATED
Host:      $HOSTNAME_VALUE
Path:      ${BACKUP_PATH:-not configured}
Pattern:   $PATTERN
Max age:   $MAX_AGE_DAYS day(s)
Min count: $MIN_COUNT
HEADER
  fi
}

print_header

if [ -z "$BACKUP_PATH" ]; then
  if [ "$FORMAT" = "markdown" ]; then
    cat <<'INFO'
## Result

INFO: no backup path configured.

Configure a path with `--path PATH` or `SASD_BACKUP_CHECK_PATH`. The generic
collector intentionally treats this as informational so read-only host reports do
not fail on systems without a known backup location.
INFO
  else
    cat <<'INFO'
== Result ==
INFO: no backup path configured.

Configure a path with --path PATH or SASD_BACKUP_CHECK_PATH. The generic
collector intentionally treats this as informational so read-only host reports do
not fail on systems without a known backup location.
INFO
  fi
  exit 0
fi

if [ ! -d "$BACKUP_PATH" ]; then
  echo "ERROR: configured path is not a directory: $BACKUP_PATH" >&2
  exit 2
fi

TMP_LIST="$(mktemp)"
TMP_WARN="$(mktemp)"
cleanup() {
  rm -f "$TMP_LIST" "$TMP_WARN"
}
trap cleanup EXIT

# Output columns: epoch<TAB>size<TAB>mtime<TAB>path
find "$BACKUP_PATH" -type f -name "$PATTERN" -printf '%T@\t%s\t%TY-%Tm-%Td %TH:%TM:%TS %Tz\t%p\n' 2>"$TMP_WARN" \
  | sort -nr > "$TMP_LIST"

COUNT="$(wc -l < "$TMP_LIST" | tr -d ' ')"
NOW_EPOCH="$(date +%s)"
MAX_AGE_SECONDS="$((MAX_AGE_DAYS * 86400))"
STATUS=0

NEWEST_LINE="$(head -n 1 "$TMP_LIST")"
NEWEST_EPOCH=""
NEWEST_SIZE=""
NEWEST_MTIME=""
NEWEST_PATH=""

if [ -n "$NEWEST_LINE" ]; then
  TAB_CHAR="$(printf '\t')"
  NEWEST_EPOCH="$(printf '%s\n' "$NEWEST_LINE" | cut -f1)"
  NEWEST_SIZE="$(printf '%s\n' "$NEWEST_LINE" | cut -f2)"
  NEWEST_MTIME="$(printf '%s\n' "$NEWEST_LINE" | cut -f3)"
  NEWEST_PATH="$(printf '%s\n' "$NEWEST_LINE" | cut -f4-)"
fi

if [ "$COUNT" -lt "$MIN_COUNT" ]; then
  STATUS=1
fi

if [ -n "$NEWEST_EPOCH" ]; then
  # Convert floating epoch to integer seconds.
  NEWEST_EPOCH_INT="${NEWEST_EPOCH%.*}"
  AGE_SECONDS="$((NOW_EPOCH - NEWEST_EPOCH_INT))"
  if [ "$AGE_SECONDS" -gt "$MAX_AGE_SECONDS" ]; then
    STATUS=1
  fi
else
  AGE_SECONDS=""
  STATUS=1
fi

if [ "$FORMAT" = "markdown" ]; then
  cat <<SUMMARY
## Summary

| Metric | Value |
| --- | ---: |
| Matching files | $COUNT |
| Minimum expected | $MIN_COUNT |
| Newest age seconds | ${AGE_SECONDS:-n/a} |
| Max age seconds | $MAX_AGE_SECONDS |

SUMMARY
  if [ -s "$TMP_WARN" ]; then
    cat <<'WARN'
## Scan warnings

\`\`\`text
WARN
    sed 's/[[:cntrl:]]//g' "$TMP_WARN"
    cat <<'WARN'
\`\`\`

WARN
  fi
  if [ -n "$NEWEST_PATH" ]; then
    cat <<NEWEST
## Newest matching file

| Field | Value |
| --- | --- |
| Path | \`$NEWEST_PATH\` |
| Size | $NEWEST_SIZE bytes |
| Mtime | $NEWEST_MTIME |
| Age | ${AGE_SECONDS:-n/a} second(s) |

NEWEST
  fi
  cat <<FILES
## Newest matching files

| Mtime | Size | Path |
| --- | ---: | --- |
FILES
  head -n "$MAX_SHOWN" "$TMP_LIST" | while IFS= read -r line; do
    size="$(printf '%s\n' "$line" | cut -f2)"
    mtime="$(printf '%s\n' "$line" | cut -f3)"
    path="$(printf '%s\n' "$line" | cut -f4-)"
    printf '| `%s` | %s | `%s` |\n' "$mtime" "$size" "$path"
  done
  echo
  if [ "$STATUS" -eq 0 ]; then
    echo "OK: backup age/count policy looks satisfied."
  else
    echo "WARN: backup age/count policy is not satisfied."
  fi
else
  cat <<SUMMARY
== Summary ==
Matching files:   $COUNT
Minimum expected: $MIN_COUNT
Newest age:       ${AGE_SECONDS:-n/a} second(s)
Max age:          $MAX_AGE_SECONDS second(s)
SUMMARY
  if [ -s "$TMP_WARN" ]; then
    echo
    echo "== Scan warnings =="
    sed 's/[[:cntrl:]]//g' "$TMP_WARN"
  fi
  if [ -n "$NEWEST_PATH" ]; then
    cat <<NEWEST

== Newest matching file ==
Path:  $NEWEST_PATH
Size:  $NEWEST_SIZE bytes
Mtime: $NEWEST_MTIME
Age:   ${AGE_SECONDS:-n/a} second(s)
NEWEST
  fi
  echo
  echo "== Newest matching files =="
  head -n "$MAX_SHOWN" "$TMP_LIST" | while IFS= read -r line; do
    size="$(printf '%s\n' "$line" | cut -f2)"
    mtime="$(printf '%s\n' "$line" | cut -f3)"
    path="$(printf '%s\n' "$line" | cut -f4-)"
    printf '%s  %12s  %s\n' "$mtime" "$size" "$path"
  done
  echo
  if [ "$STATUS" -eq 0 ]; then
    echo "OK: backup age/count policy looks satisfied."
  else
    echo "WARN: backup age/count policy is not satisfied."
  fi
fi

exit "$STATUS"
