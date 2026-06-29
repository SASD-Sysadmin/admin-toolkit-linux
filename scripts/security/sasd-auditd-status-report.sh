#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/security/sasd-auditd-status-report.sh
# Purpose: Report Linux auditd/auditctl state and basic audit rule visibility.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# This script is read-only. It does not load audit rules, change auditd config or
# restart auditd. It only reports whether audit tooling appears to be present and
# readable.
#
# Why this matters
# ----------------
# auditd can be important for security monitoring, compliance evidence and host
# investigation. On developer systems, WSL and containers it may be absent; that
# should be an INFO result, not a hard failure.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SHOW_RULES="yes"
MAX_RULES="120"

show_help() {
    cat <<HELP
Usage: $SCRIPT_NAME [OPTIONS]

Report auditd and auditctl state.

Options:
  --no-rules       Do not print auditctl -l rules.
  --max-rules N    Maximum audit rules to print. Default: 120.
  -h, --help       Show this help text.

Examples:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --no-rules

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
        --no-rules)
            SHOW_RULES="no"
            shift
            ;;
        --max-rules)
            [[ $# -ge 2 ]] || fail "--max-rules requires a number"
            [[ "$2" =~ ^[0-9]+$ ]] || fail "--max-rules must be numeric"
            MAX_RULES="$2"
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

file_meta() {
    local path="$1"
    if [[ -e "$path" ]]; then
        stat -c '%n owner=%U:%G mode=%a size=%s bytes mtime=%y' "$path" 2>/dev/null || ls -ld "$path" 2>/dev/null || true
    else
        printf 'MISSING: %s\n' "$path"
    fi
}

printf 'SASD Auditd Status Report\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
printf '\n'

printf '== Tool detection ==\n'
for tool in auditctl ausearch aureport auditd systemctl; do
    if command_exists "$tool"; then
        printf 'OK:   %-10s %s\n' "$tool" "$(command -v "$tool")"
    else
        printf 'MISS: %-10s not found\n' "$tool"
    fi
done
printf '\n'

printf '== Service state ==\n'
if command_exists systemctl; then
    printf 'auditd.service enabled=%s active=%s\n' \
        "$(systemctl is-enabled auditd.service 2>/dev/null || echo unknown)" \
        "$(systemctl is-active auditd.service 2>/dev/null || echo unknown)"
else
    printf 'INFO: systemctl not available.\n'
fi
printf '\n'

printf '== Configuration files ==\n'
for path in /etc/audit/auditd.conf /etc/audit/rules.d /etc/audit/audit.rules; do
    file_meta "$path"
done
printf '\n'

printf '== auditctl status ==\n'
if command_exists auditctl; then
    auditctl -s 2>&1 || printf 'INFO: auditctl status failed. Root/CAP_AUDIT_CONTROL may be required.\n'
else
    printf 'INFO: auditctl not installed.\n'
fi
printf '\n'

printf '== audit rules ==\n'
if [[ "$SHOW_RULES" == "no" ]]; then
    printf 'INFO: audit rule output disabled by option.\n'
elif command_exists auditctl; then
    auditctl -l 2>&1 | head -n "$MAX_RULES" || printf 'INFO: auditctl rule listing failed.\n'
else
    printf 'INFO: auditctl not installed.\n'
fi

exit 0
