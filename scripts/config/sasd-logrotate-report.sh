#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/config/sasd-logrotate-report.sh
# Purpose: Summarize logrotate configuration and visible rotation policies.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# This script is read-only. By default, it does not execute log rotation. It only
# reads configuration files and, when available, optionally asks logrotate for a
# debug plan. The logrotate debug mode (-d) is designed not to perform rotations.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
CONFIG_MAIN="/etc/logrotate.conf"
CONFIG_DIR="/etc/logrotate.d"
SHOW_DEBUG="no"

show_help() {
    cat <<HELP
Usage: $SCRIPT_NAME [OPTIONS]

Summarize Linux logrotate configuration.

Options:
  --debug-plan   Include 'logrotate -d' output. This is read-only but can be long.
  -h, --help     Show this help text.
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug-plan)
            SHOW_DEBUG="yes"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            printf 'ERROR: unknown option: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

printf 'SASD Logrotate Configuration Report\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"

printf '== Configuration sources ==\n'
if [[ -r "$CONFIG_MAIN" ]]; then
    printf 'OK:   readable main config: %s\n' "$CONFIG_MAIN"
else
    printf 'WARN: main config is not readable or not present: %s\n' "$CONFIG_MAIN"
fi

if [[ -d "$CONFIG_DIR" ]]; then
    printf 'OK:   config directory exists: %s\n' "$CONFIG_DIR"
else
    printf 'WARN: config directory is not present: %s\n' "$CONFIG_DIR"
fi

printf '\n== Main policy lines ==\n'
if [[ -r "$CONFIG_MAIN" ]]; then
    awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        { print }
    ' "$CONFIG_MAIN" | sed 's/^/  /'
else
    printf '  not available\n'
fi

printf '\n== Drop-in files ==\n'
if [[ -d "$CONFIG_DIR" ]]; then
    find "$CONFIG_DIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort | while IFS= read -r file; do
        path="$CONFIG_DIR/$file"
        owner="$(stat -c '%U:%G' "$path" 2>/dev/null || echo '?')"
        mode="$(stat -c '%a' "$path" 2>/dev/null || echo '?')"
        printf '%-40s owner=%-15s mode=%s\n' "$file" "$owner" "$mode"
    done
else
    printf 'No drop-in directory found.\n'
fi

printf '\n== Pattern review ==\n'
review_pattern() {
    local label="$1"
    local regex="$2"
    local count
    count="$(grep -RIE -- "$regex" "$CONFIG_MAIN" "$CONFIG_DIR" 2>/dev/null | wc -l | tr -d ' ')"
    printf '%-24s %s matching line(s)\n' "$label" "$count"
}

review_pattern "compress" '^[[:space:]]*compress\b'
review_pattern "missingok" '^[[:space:]]*missingok\b'
review_pattern "notifempty" '^[[:space:]]*notifempty\b'
review_pattern "copytruncate" '^[[:space:]]*copytruncate\b'
review_pattern "postrotate" '^[[:space:]]*postrotate\b'
review_pattern "su directive" '^[[:space:]]*su[[:space:]]+'
review_pattern "create directive" '^[[:space:]]*create\b'

printf '\n== Package-style summary ==\n'
if [[ -d "$CONFIG_DIR" ]]; then
    find "$CONFIG_DIR" -maxdepth 1 -type f -print 2>/dev/null | sort | while IFS= read -r file; do
        printf '\n# %s\n' "$file"
        awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            NR <= 80 { print "  " $0 }
            NR == 81 { print "  ... output truncated after 80 non-empty/non-comment lines ..." }
        ' "$file" 2>/dev/null || true
    done
fi

if [[ "$SHOW_DEBUG" == "yes" ]]; then
    printf '\n== logrotate debug plan ==\n'
    if command -v logrotate >/dev/null 2>&1 && [[ -r "$CONFIG_MAIN" ]]; then
        logrotate -d "$CONFIG_MAIN" 2>&1 | sed 's/^/  /'
    else
        printf '  INFO: logrotate command or main config not available.\n'
    fi
fi

exit 0
