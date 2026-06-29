#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/packages/sasd-update-status-report.sh
# Purpose: Report available package updates without modifying package state.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# This script is read-only by default. It does not run apt update, dnf update,
# zypper refresh, pacman -Syu, or install anything. It only inspects the package
# manager's current cache/state.
#
# For Debian/Ubuntu, the report is based on apt list --upgradable and apt-get -s
# upgrade. The cache may be stale if apt update has not been run recently.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

printf 'SASD Package Update Status Report\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown-host)"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if command_exists apt && command_exists apt-get; then
    printf 'Package manager: apt\n\n'
    printf '== Upgradable packages ==\n'
    # apt emits a warning about CLI stability; for reporting this is acceptable,
    # but we discard stderr to avoid noisy output.
    upgradable="$(apt list --upgradable 2>/dev/null | tail -n +2 || true)"
    if [[ -z "$upgradable" ]]; then
        printf 'OK: no upgradable packages reported by current apt cache.\n'
    else
        count="$(printf '%s\n' "$upgradable" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
        printf 'Upgradable package count: %s\n\n' "$count"
        printf '%s\n' "$upgradable" | sed 's/^/  /'
    fi

    printf '\n== Simulated upgrade summary ==\n'
    if apt-get -s upgrade >/tmp/sasd-apt-sim.$$ 2>/tmp/sasd-apt-sim.err.$$; then
        grep -E '^(Inst|Conf|Remv) ' /tmp/sasd-apt-sim.$$ | sed 's/^/  /' || true
        summary="$(grep -E '^[0-9]+ upgraded,' /tmp/sasd-apt-sim.$$ || true)"
        [[ -n "$summary" ]] && printf '\n  %s\n' "$summary"
    else
        printf 'WARN: apt-get -s upgrade failed.\n'
        sed 's/^/  /' /tmp/sasd-apt-sim.err.$$ 2>/dev/null || true
    fi
    rm -f /tmp/sasd-apt-sim.$$ /tmp/sasd-apt-sim.err.$$
    exit 0
fi

if command_exists dnf; then
    printf 'Package manager: dnf\n\n'
    printf '== Check update output ==\n'
    dnf check-update 2>&1 | sed 's/^/  /'
    status=${PIPESTATUS[0]}
    # dnf returns 100 when updates are available.
    if [[ $status -eq 0 || $status -eq 100 ]]; then
        exit 0
    fi
    exit $status
fi

if command_exists yum; then
    printf 'Package manager: yum\n\n'
    printf '== Check update output ==\n'
    yum check-update 2>&1 | sed 's/^/  /'
    status=${PIPESTATUS[0]}
    if [[ $status -eq 0 || $status -eq 100 ]]; then
        exit 0
    fi
    exit $status
fi

if command_exists zypper; then
    printf 'Package manager: zypper\n\n'
    printf '== List updates output ==\n'
    zypper --non-interactive list-updates 2>&1 | sed 's/^/  /'
    exit 0
fi

if command_exists pacman; then
    printf 'Package manager: pacman\n\n'
    if command_exists checkupdates; then
        printf '== checkupdates output ==\n'
        checkupdates 2>&1 | sed 's/^/  /'
    else
        printf 'INFO: checkupdates is not installed. Avoiding pacman -Sy because it changes sync state.\n'
    fi
    exit 0
fi

printf 'INFO: no supported package manager found.\n'
exit 0
