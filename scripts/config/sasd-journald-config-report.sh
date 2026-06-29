#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/config/sasd-journald-config-report.sh
# Purpose: Read and summarize systemd-journald configuration in a safe way.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# This script is read-only. It does not restart journald and does not edit any
# configuration file. It is meant to answer operational questions such as:
#
# - Is journald configured for persistent or volatile storage?
# - Are compression and sealing configured?
# - Are rate limits visible?
# - Are drop-in configuration files present?
#
# The script works best on systemd-based Linux distributions. On WSL, containers,
# or non-systemd systems, some commands or files may be absent; that is reported
# as INFO instead of treated as a hard error.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

CONFIG_MAIN="/etc/systemd/journald.conf"
DROPIN_DIR="/etc/systemd/journald.conf.d"

printf 'SASD Journald Configuration Report\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"

printf '== Configuration sources ==\n'
if [[ -r "$CONFIG_MAIN" ]]; then
    printf 'OK:   readable main config: %s\n' "$CONFIG_MAIN"
else
    printf 'INFO: main config is not readable or not present: %s\n' "$CONFIG_MAIN"
fi

if [[ -d "$DROPIN_DIR" ]]; then
    printf 'OK:   drop-in directory exists: %s\n' "$DROPIN_DIR"
    find "$DROPIN_DIR" -maxdepth 1 -type f -name '*.conf' -printf '      %p\n' 2>/dev/null | sort || true
else
    printf 'INFO: no drop-in directory found: %s\n' "$DROPIN_DIR"
fi

printf '\n== Effective configuration view ==\n'
if command -v systemd-analyze >/dev/null 2>&1; then
    if systemd-analyze cat-config systemd/journald.conf >/tmp/sasd-journald-cat-config.$$ 2>/tmp/sasd-journald-cat-config.err.$$; then
        printf 'Source: systemd-analyze cat-config systemd/journald.conf\n\n'
        awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            { print }
        ' /tmp/sasd-journald-cat-config.$$
    else
        printf 'INFO: systemd-analyze cat-config did not return an effective config.\n'
        sed 's/^/      /' /tmp/sasd-journald-cat-config.err.$$ 2>/dev/null || true
    fi
    rm -f /tmp/sasd-journald-cat-config.$$ /tmp/sasd-journald-cat-config.err.$$
else
    printf 'INFO: systemd-analyze is not available. Falling back to file parsing.\n'
fi

printf '\n== Key setting review ==\n'

# collect_value prints the last uncommented occurrence of a journald setting from
# the main file and drop-ins. This is not a perfect systemd parser, but it gives a
# useful read-only review even when systemd-analyze is unavailable.
collect_value() {
    local key="$1"
    local files=()

    [[ -r "$CONFIG_MAIN" ]] && files+=("$CONFIG_MAIN")
    if [[ -d "$DROPIN_DIR" ]]; then
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find "$DROPIN_DIR" -maxdepth 1 -type f -name '*.conf' -print0 2>/dev/null | sort -z)
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        return 1
    fi

    awk -F= -v wanted="$key" '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
            left=$1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", left)
            if (tolower(left) == tolower(wanted)) {
                value=$0
                sub(/^[^=]*=/, "", value)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                found=value
            }
        }
        END {
            if (found != "") {
                print found
            }
        }
    ' "${files[@]}"
}

review_key() {
    local key="$1"
    local note="$2"
    local value
    value="$(collect_value "$key" 2>/dev/null || true)"
    if [[ -n "$value" ]]; then
        printf '%-24s %-20s %s\n' "$key" "$value" "$note"
    else
        printf '%-24s %-20s %s\n' "$key" "not set" "$note"
    fi
}

review_key "Storage" "persistent keeps logs across reboots; auto depends on /var/log/journal"
review_key "Compress" "compression is usually desirable"
review_key "Seal" "forward secure sealing can help tamper evidence when available"
review_key "SplitMode" "controls per-user journal splitting"
review_key "RateLimitIntervalSec" "rate limiting protects against log floods"
review_key "RateLimitBurst" "burst size for rate limiting"
review_key "SystemMaxUse" "disk cap for persistent system journal"
review_key "RuntimeMaxUse" "disk cap for volatile runtime journal"
review_key "MaxRetentionSec" "maximum retention time"
review_key "ForwardToSyslog" "whether journald forwards to syslog"

printf '\n== Journal directory state ==\n'
if [[ -d /var/log/journal ]]; then
    printf 'OK:   /var/log/journal exists; persistent journals may be enabled.\n'
    du -sh /var/log/journal 2>/dev/null | sed 's/^/      /' || true
else
    printf 'INFO: /var/log/journal does not exist; journald may use volatile storage unless configured otherwise.\n'
fi

exit 0
