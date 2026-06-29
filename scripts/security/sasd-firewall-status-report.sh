#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/security/sasd-firewall-status-report.sh
# Purpose: Report Linux firewall tooling state without changing rules.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# This script is read-only. It does not add, delete, flush or reload firewall
# rules. It only checks common firewall tools and optionally prints limited rule
# output.
#
# Why this matters
# ----------------
# Linux firewall state can be managed through nftables, iptables, ufw,
# firewalld, distribution scripts or container tooling. A report should avoid
# assuming there is only one firewall frontend.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SHOW_RULES="no"
MAX_LINES="160"

show_help() {
    cat <<HELP
Usage: $SCRIPT_NAME [OPTIONS]

Report detected Linux firewall tools and current firewall state.

Options:
  --show-rules       Print limited rule output where supported.
  --max-lines N      Maximum lines per ruleset output. Default: 160.
  -h, --help         Show this help text.

Examples:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --show-rules --max-lines 80

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
        --show-rules)
            SHOW_RULES="yes"
            shift
            ;;
        --max-lines)
            [[ $# -ge 2 ]] || fail "--max-lines requires a number"
            [[ "$2" =~ ^[0-9]+$ ]] || fail "--max-lines must be numeric"
            MAX_LINES="$2"
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

service_state() {
    local unit="$1"
    if command_exists systemctl; then
        printf '%s enabled=%s active=%s\n' \
            "$unit" \
            "$(systemctl is-enabled "$unit" 2>/dev/null || echo unknown)" \
            "$(systemctl is-active "$unit" 2>/dev/null || echo unknown)"
    fi
}

print_limited_command() {
    local label="$1"
    shift

    printf '# %s\n' "$label"
    if "$@" 2>&1 | head -n "$MAX_LINES"; then
        printf '\n'
    else
        printf 'INFO: command failed or is not permitted: %s\n\n' "$label"
    fi
}

printf 'SASD Firewall Status Report\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
printf '\n'

printf '== Tool detection ==\n'
for tool in nft iptables ip6tables ufw firewall-cmd systemctl; do
    if command_exists "$tool"; then
        printf 'OK:   %-14s %s\n' "$tool" "$(command -v "$tool")"
    else
        printf 'MISS: %-14s not found\n' "$tool"
    fi
done
printf '\n'

printf '== Service/frontend state ==\n'
service_state nftables.service
service_state ufw.service
service_state firewalld.service
if command_exists ufw; then
    printf '\n# ufw status\n'
    ufw status verbose 2>&1 || true
fi
if command_exists firewall-cmd; then
    printf '\n# firewalld state\n'
    firewall-cmd --state 2>&1 || true
    firewall-cmd --get-active-zones 2>&1 || true
fi
printf '\n'

printf '== Ruleset summary ==\n'
if command_exists nft; then
    # Listing the ruleset may require root or CAP_NET_ADMIN on some systems.
    rules_count="$(nft list ruleset 2>/dev/null | wc -l | awk '{ print $1 }')"
    printf 'nft ruleset lines: %s\n' "$rules_count"
else
    printf 'nft ruleset lines: unavailable; nft command not found\n'
fi
if command_exists iptables; then
    printf 'iptables filter rules: '
    iptables -S 2>/dev/null | wc -l | awk '{ print $1 }'
else
    printf 'iptables filter rules: unavailable; iptables command not found\n'
fi
if command_exists ip6tables; then
    printf 'ip6tables filter rules: '
    ip6tables -S 2>/dev/null | wc -l | awk '{ print $1 }'
else
    printf 'ip6tables filter rules: unavailable; ip6tables command not found\n'
fi
printf '\n'

if [[ "$SHOW_RULES" == "yes" ]]; then
    printf '== Limited ruleset output ==\n'
    command_exists nft && print_limited_command 'nft list ruleset' nft list ruleset
    command_exists iptables && print_limited_command 'iptables -S' iptables -S
    command_exists ip6tables && print_limited_command 'ip6tables -S' ip6tables -S
else
    printf 'INFO: detailed rules are skipped by default. Use --show-rules to print limited rule output.\n'
fi

exit 0
