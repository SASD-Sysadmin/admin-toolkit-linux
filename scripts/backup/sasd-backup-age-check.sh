#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/backup/sasd-backup-age-check.sh
# Purpose: Check whether a backup directory contains recent backup files.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# This script is read-only. It does not create, delete, rotate, compress or upload
# backups. It only checks file timestamps and reports whether the newest matching
# file is recent enough for a simple operational policy.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
BACKUP_PATH=""
PATTERN="*"
MAX_AGE_DAYS="1"
MIN_COUNT="1"

show_help() {
    cat <<HELP
Usage: $SCRIPT_NAME --path DIR [OPTIONS]

Check whether a backup directory contains recent files.

Required:
  --path DIR          Directory that contains backup files.

Options:
  --pattern GLOB      File name pattern to match. Default: *
  --max-age-days N    Newest matching file must be no older than N days.
                      Default: 1
  --min-count N       Require at least N matching files. Default: 1
  -h, --help          Show this help text.

Examples:
  ./$SCRIPT_NAME --path /backup/mysql --pattern '*.sql.gz' --max-age-days 1
  ./$SCRIPT_NAME --path /srv/backups --min-count 7 --max-age-days 2

Exit codes:
  0  Backup age/count policy looks OK.
  1  Warning: no recent enough backup or too few matching files.
  2  Usage error or unreadable path.
HELP
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            [[ $# -ge 2 ]] || fail "--path requires a directory argument"
            BACKUP_PATH="$2"
            shift 2
            ;;
        --pattern)
            [[ $# -ge 2 ]] || fail "--pattern requires a glob argument"
            PATTERN="$2"
            shift 2
            ;;
        --max-age-days)
            [[ $# -ge 2 ]] || fail "--max-age-days requires a numeric argument"
            [[ "$2" =~ ^[0-9]+$ ]] || fail "--max-age-days must be numeric"
            MAX_AGE_DAYS="$2"
            shift 2
            ;;
        --min-count)
            [[ $# -ge 2 ]] || fail "--min-count requires a numeric argument"
            [[ "$2" =~ ^[0-9]+$ ]] || fail "--min-count must be numeric"
            MIN_COUNT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
done

[[ -n "$BACKUP_PATH" ]] || fail "--path is required"
[[ -d "$BACKUP_PATH" ]] || fail "backup path is not a directory: $BACKUP_PATH"
[[ -r "$BACKUP_PATH" ]] || fail "backup path is not readable: $BACKUP_PATH"

printf 'SASD Backup Age Check\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"
printf 'Path:      %s\n' "$BACKUP_PATH"
printf 'Pattern:   %s\n' "$PATTERN"
printf 'Max age:   %s day(s)\n' "$MAX_AGE_DAYS"
printf 'Min count: %s\n\n' "$MIN_COUNT"

# GNU find is expected in this Linux-focused repository. We use epoch timestamps
# because they are easy to compare and can be formatted later.
mapfile -t matches < <(find "$BACKUP_PATH" -type f -name "$PATTERN" -printf '%T@\t%s\t%p\n' 2>/dev/null | sort -nr)
count="${#matches[@]}"

printf 'Matching files: %s\n' "$count"
if (( count == 0 )); then
    printf 'WARN: no matching backup files found.\n'
    exit 1
fi

newest_line="${matches[0]}"
newest_epoch="$(cut -f1 <<< "$newest_line")"
newest_size="$(cut -f2 <<< "$newest_line")"
newest_path="$(cut -f3- <<< "$newest_line")"
now_epoch="$(date +%s)"
newest_epoch_int="${newest_epoch%.*}"
age_seconds=$(( now_epoch - newest_epoch_int ))
age_days=$(( age_seconds / 86400 ))
threshold_seconds=$(( MAX_AGE_DAYS * 86400 ))

printf 'Newest file:    %s\n' "$newest_path"
printf 'Newest size:    %s bytes\n' "$newest_size"
printf 'Newest mtime:   %s\n' "$(date -d "@$newest_epoch_int" -Is 2>/dev/null || echo "$newest_epoch")"
printf 'Newest age:     %s second(s), approx. %s day(s)\n\n' "$age_seconds" "$age_days"

printf '== Newest matching files ==\n'
printf '%s\n' "${matches[@]:0:10}" | while IFS=$'\t' read -r epoch size path; do
    epoch_int="${epoch%.*}"
    printf '%s  %12s  %s\n' "$(date -d "@$epoch_int" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || echo "$epoch")" "$size" "$path"
done

status=0
if (( count < MIN_COUNT )); then
    printf '\nWARN: matching file count %s is below required minimum %s.\n' "$count" "$MIN_COUNT"
    status=1
fi

if (( age_seconds > threshold_seconds )); then
    printf '\nWARN: newest backup is older than allowed threshold.\n'
    status=1
fi

if (( status == 0 )); then
    printf '\nOK: backup age/count policy looks satisfied.\n'
else
    printf '\nReview backup job, destination, retention policy and restore tests.\n'
fi

exit "$status"
