#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/packages/sasd-reboot-required-report.sh
# Purpose: Report whether the system indicates that a reboot is required.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# This script is read-only. It checks common distro indicators such as
# /run/reboot-required and, when available, needrestart output.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

printf 'SASD Reboot Required Report\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"

reboot_required="no"

printf '== Reboot indicator files ==\n'
for file in /run/reboot-required /var/run/reboot-required; do
    if [[ -e "$file" ]]; then
        reboot_required="yes"
        printf 'WARN: %s exists\n' "$file"
        if [[ -r "$file" ]]; then
            sed 's/^/  /' "$file" || true
        fi
    else
        printf 'OK:   %s not present\n' "$file"
    fi
done

printf '\n== Packages requesting reboot ==\n'
if [[ -r /run/reboot-required.pkgs ]]; then
    sed 's/^/  /' /run/reboot-required.pkgs
elif [[ -r /var/run/reboot-required.pkgs ]]; then
    sed 's/^/  /' /var/run/reboot-required.pkgs
else
    printf 'INFO: no reboot-required package list found.\n'
fi

printf '\n== needrestart review ==\n'
if command -v needrestart >/dev/null 2>&1; then
    # -b is batch mode. It should be read-only, but output differs by version.
    needrestart -b 2>&1 | sed 's/^/  /' || true
else
    printf 'INFO: needrestart is not installed.\n'
fi

printf '\n== Result ==\n'
if [[ "$reboot_required" == "yes" ]]; then
    printf 'WARN: reboot appears to be required according to distro indicator files.\n'
    exit 1
fi

printf 'OK: no common reboot-required indicator file was found.\n'
exit 0
