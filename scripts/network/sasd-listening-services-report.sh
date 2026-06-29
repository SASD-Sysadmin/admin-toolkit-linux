#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/network/sasd-listening-services-report.sh
# Purpose: Produce a human-readable report of listening TCP/UDP services.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# This script is read-only. It does not scan remote hosts. It only reports local
# listening sockets using ss(8) or netstat(8) when available.
#
# Difference to sasd-open-ports-audit.sh:
# - open-ports-audit shows raw socket information for audit completeness
# - this report adds a small classification: loopback-only vs. non-loopback bind
# -----------------------------------------------------------------------------

set -u
set -o pipefail

printf 'SASD Listening Services Report\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"

if command -v ss >/dev/null 2>&1; then
    printf 'Source: ss -H -tulpen\n\n'
    raw_output="$(ss -H -tulpen 2>/dev/null || true)"
elif command -v netstat >/dev/null 2>&1; then
    printf 'Source: netstat -tulpen\n\n'
    raw_output="$(netstat -tulpen 2>/dev/null | tail -n +3 || true)"
else
    printf 'ERROR: neither ss nor netstat is available.\n' >&2
    exit 2
fi

if [[ -z "$raw_output" ]]; then
    printf 'INFO: no listening sockets were reported or permissions are insufficient.\n'
    exit 0
fi

printf '== Summary ==\n'
printf '%s\n' "$raw_output" | awk '
    BEGIN { tcp=0; udp=0; loop=0; public=0 }
    {
        proto=$1
        local=$5
        if (proto ~ /^tcp/) tcp++
        if (proto ~ /^udp/) udp++
        if (local ~ /127\.0\.0\.1:/ || local ~ /\[::1\]:/ || local ~ /^localhost:/) {
            loop++
        } else {
            public++
        }
    }
    END {
        printf "TCP listeners:          %d\n", tcp
        printf "UDP listeners:          %d\n", udp
        printf "Loopback-only binds:    %d\n", loop
        printf "Non-loopback/any binds: %d\n", public
    }
'

printf '\n== Listening sockets ==\n'
printf '%-6s %-8s %-30s %-12s %s\n' "Proto" "State" "Local" "Bind" "Process/User"
printf '%-6s %-8s %-30s %-12s %s\n' "-----" "-----" "-----" "----" "------------"

printf '%s\n' "$raw_output" | while IFS= read -r line; do
    # ss output usually: proto state recv-q send-q local peer process...
    proto="$(awk '{print $1}' <<< "$line")"
    state="$(awk '{print $2}' <<< "$line")"
    local_addr="$(awk '{print $5}' <<< "$line")"

    bind_class="non-loopback"
    if [[ "$local_addr" =~ 127\.0\.0\.1: || "$local_addr" =~ \[::1\]: || "$local_addr" =~ ^localhost: ]]; then
        bind_class="loopback"
    elif [[ "$local_addr" =~ 0\.0\.0\.0: || "$local_addr" =~ \[::\]: || "$local_addr" =~ \*: ]]; then
        bind_class="any"
    fi

    process="$(sed -E 's/^([^[:space:]]+[[:space:]]+){6}//' <<< "$line")"
    [[ "$process" == "$line" ]] && process=""

    printf '%-6s %-8s %-30s %-12s %s\n' "$proto" "$state" "$local_addr" "$bind_class" "$process"
done

printf '\n== Review hints ==\n'
printf -- '- Any/0.0.0.0/[::] listeners are reachable from more interfaces than loopback-only services.\n'
printf -- '- Loopback services can still matter when local users, web apps, or port forwards are involved.\n'
printf -- '- This script does not decide whether a service is allowed; compare output with your host role.\n'

exit 0
