#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/config/sasd-systemd-timers-report.sh
# Purpose: Report systemd timers and their next/last run state.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# This script is read-only. It calls systemctl list commands and, when possible,
# prints timer unit file metadata. It does not enable, disable, start or stop
# timers.
#
# Why this matters
# ----------------
# On modern Linux systems, systemd timers often replace cron jobs. They can run
# backups, cleanup tasks, package refreshes, certificate renewal, log rotation or
# application maintenance. An operations report should make them visible.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SHOW_UNIT_FILES="yes"
MAX_CAT_LINES="80"

show_help() {
    cat <<HELP
Usage: $SCRIPT_NAME [OPTIONS]

Report systemd timer state and timer unit files.

Options:
  --no-unit-files       Do not show timer unit-file snippets.
  --max-cat-lines N     Maximum lines to show per unit file. Default: 80.
  -h, --help            Show this help text.

Examples:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --max-cat-lines 30

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
        --no-unit-files)
            SHOW_UNIT_FILES="no"
            shift
            ;;
        --max-cat-lines)
            [[ $# -ge 2 ]] || fail "--max-cat-lines requires a number"
            [[ "$2" =~ ^[0-9]+$ ]] || fail "--max-cat-lines must be numeric"
            MAX_CAT_LINES="$2"
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

printf 'SASD Systemd Timers Report\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
printf '\n'

if ! command_exists systemctl; then
    printf 'INFO: systemctl not available. This may be normal in minimal containers.\n'
    exit 0
fi

printf '== System manager state ==\n'
printf 'System state: %s\n' "$(systemctl is-system-running 2>/dev/null || echo unknown)"
printf '\n'

printf '== Active and known timers ==\n'
systemctl list-timers --all --no-pager 2>/dev/null || printf 'INFO: cannot list systemd timers.\n'
printf '\n'

printf '== Timer unit files ==\n'
systemctl list-unit-files --type=timer --no-pager 2>/dev/null || printf 'INFO: cannot list timer unit files.\n'
printf '\n'

printf '== Failed timer/service units ==\n'
systemctl --failed --type=timer --type=service --no-pager 2>/dev/null || printf 'INFO: cannot list failed units.\n'
printf '\n'

if [[ "$SHOW_UNIT_FILES" == "yes" ]]; then
    printf '== Timer unit file snippets ==\n'
    systemctl list-unit-files --type=timer --no-legend --no-pager 2>/dev/null \
        | awk '{ print $1 }' \
        | sort \
        | while IFS= read -r unit; do
            [[ -n "$unit" ]] || continue
            printf '# %s\n' "$unit"
            if systemctl cat "$unit" --no-pager 2>/dev/null | head -n "$MAX_CAT_LINES"; then
                printf '\n'
            else
                printf 'INFO: cannot read unit file.\n\n'
            fi
        done
else
    printf 'INFO: timer unit-file snippets skipped by option.\n'
fi

exit 0
