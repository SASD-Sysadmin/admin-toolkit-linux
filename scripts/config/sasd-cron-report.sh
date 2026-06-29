#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/config/sasd-cron-report.sh
# Purpose: Report cron configuration, cron drop-ins and user crontab metadata.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# This script is read-only. It does not install cron jobs, edit crontabs, reload
# services or change permissions. It only reports files and visible schedules.
#
# Why this matters
# ----------------
# Cron is often overlooked during host reviews. Old cron jobs can start backups,
# cleanup tasks, database jobs, sync jobs or forgotten maintenance commands. A
# good operations review should make cron activity visible without immediately
# trying to judge whether every job is allowed.
#
# Privacy note
# ------------
# Cron commands may contain paths, usernames, application names or environment
# details. Review output before sharing it outside the system owner/admin team.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SHOW_CONTENT="yes"
SHOW_USER_CRONTABS="metadata"

show_help() {
    cat <<HELP
Usage: $SCRIPT_NAME [OPTIONS]

Report cron configuration and cron job locations.

Options:
  --no-content              Do not print visible cron command lines.
  --user-crontabs MODE      How to handle user crontabs below spool dirs.
                            MODE can be: none, metadata, content
                            Default: metadata
  -h, --help                Show this help text.

Examples:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --no-content
  ./$SCRIPT_NAME --user-crontabs content

Exit codes:
  0  Report completed.
  2  Invalid arguments.
HELP
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-content)
            SHOW_CONTENT="no"
            shift
            ;;
        --user-crontabs)
            [[ $# -ge 2 ]] || fail "--user-crontabs requires none, metadata or content"
            case "$2" in
                none|metadata|content) SHOW_USER_CRONTABS="$2" ;;
                *) fail "invalid --user-crontabs mode: $2" ;;
            esac
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

print_header() {
    printf 'SASD Cron Report\n'
    printf 'Generated: %s\n' "$(date -Is)"
    printf 'Host:      %s\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
    printf '\n'
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

file_meta() {
    local path="$1"
    if [[ -e "$path" ]]; then
        if stat -c '%n owner=%U:%G mode=%a size=%s bytes mtime=%y' "$path" 2>/dev/null; then
            return 0
        fi
        ls -ld "$path" 2>/dev/null || true
    else
        printf 'MISSING: %s\n' "$path"
    fi
}

print_visible_cron_lines() {
    local file="$1"

    if [[ "$SHOW_CONTENT" != "yes" ]]; then
        printf 'CONTENT-SKIPPED: %s\n' "$file"
        return 0
    fi

    if [[ ! -r "$file" ]]; then
        printf 'UNREADABLE: %s\n' "$file"
        return 0
    fi

    # Print non-empty, non-comment lines. This keeps the report focused on
    # actual schedules while preserving the original line text.
    awk '
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*#/ { next }
        { print }
    ' "$file" 2>/dev/null || true
}

print_header

printf '== Cron service state ==\n'
if command_exists systemctl; then
    for unit in cron.service crond.service; do
        if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
            printf '%-20s enabled=%s active=%s\n' \
                "$unit" \
                "$(systemctl is-enabled "$unit" 2>/dev/null || echo unknown)" \
                "$(systemctl is-active "$unit" 2>/dev/null || echo unknown)"
        fi
    done
else
    printf 'INFO: systemctl not available.\n'
fi
printf '\n'

printf '== System cron files and directories ==\n'
for path in /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    file_meta "$path"
done
printf '\n'

printf '== /etc/crontab visible schedules ==\n'
if [[ -f /etc/crontab ]]; then
    print_visible_cron_lines /etc/crontab
else
    printf 'INFO: /etc/crontab not present.\n'
fi
printf '\n'

printf '== /etc/cron.d files ==\n'
if [[ -d /etc/cron.d ]]; then
    find /etc/cron.d -maxdepth 1 -type f -print 2>/dev/null | sort | while IFS= read -r file; do
        file_meta "$file"
        print_visible_cron_lines "$file" | sed 's/^/  /'
    done
else
    printf 'INFO: /etc/cron.d not present.\n'
fi
printf '\n'

printf '== Periodic cron directories ==\n'
for dir in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    printf '# %s\n' "$dir"
    if [[ -d "$dir" ]]; then
        find "$dir" -mindepth 1 -maxdepth 1 -type f -o -type l 2>/dev/null | sort | while IFS= read -r item; do
            file_meta "$item"
        done
    else
        printf 'INFO: directory not present.\n'
    fi
    printf '\n'
done

printf '== User crontab spool review ==\n'
case "$SHOW_USER_CRONTABS" in
    none)
        printf 'INFO: user crontab review disabled by option.\n'
        ;;
    metadata|content)
        found="no"
        for spool in /var/spool/cron/crontabs /var/spool/cron; do
            [[ -d "$spool" ]] || continue
            found="yes"
            printf '# %s\n' "$spool"
            find "$spool" -mindepth 1 -maxdepth 1 -type f 2>/dev/null | sort | while IFS= read -r file; do
                file_meta "$file"
                if [[ "$SHOW_USER_CRONTABS" == "content" ]]; then
                    print_visible_cron_lines "$file" | sed 's/^/  /'
                else
                    printf '  CONTENT-SKIPPED: use --user-crontabs content to print visible lines.\n'
                fi
            done
        done
        if [[ "$found" == "no" ]]; then
            printf 'INFO: no common user crontab spool directory found.\n'
        fi
        ;;
esac

exit 0
