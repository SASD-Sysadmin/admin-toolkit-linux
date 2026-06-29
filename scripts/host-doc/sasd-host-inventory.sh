#!/usr/bin/env bash
# Path: scripts/host-doc/sasd-host-inventory.sh
# Purpose: Collect read-only Linux host inventory information.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: sasd-host-inventory.sh [--help] [--version]

Collect a read-only Markdown inventory of the current Linux host.
No system changes are made.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

command_exists() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n## %s\n\n' "$1"; }
code_block() { printf '```text\n'; cat; printf '```\n'; }
value_or_unknown() { local value="${1:-}"; [[ -n "$value" ]] && printf '%s' "$value" || printf 'unknown'; }

hostname_short="$(hostname 2>/dev/null || true)"
hostname_fqdn="$(hostname -f 2>/dev/null || true)"
os_name="unknown"
os_version="unknown"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  os_name="${PRETTY_NAME:-${NAME:-unknown}}"
  os_version="${VERSION_ID:-unknown}"
fi

cat <<EOF
# SASD Host Inventory

| Key | Value |
| --- | --- |
| Generated UTC | $(date -u '+%Y-%m-%d %H:%M:%S UTC') |
| Hostname | $(value_or_unknown "$hostname_short") |
| FQDN | $(value_or_unknown "$hostname_fqdn") |
| OS | ${os_name} |
| OS Version | ${os_version} |
| Kernel | $(uname -r 2>/dev/null || echo unknown) |
| Architecture | $(uname -m 2>/dev/null || echo unknown) |
| User | $(id -un 2>/dev/null || echo unknown) |
EOF

section "Uptime"
(uptime 2>/dev/null || true) | code_block

section "CPU"
if command_exists lscpu; then
  lscpu | sed -n '1,25p' | code_block
else
  grep -m1 'model name' /proc/cpuinfo 2>/dev/null | code_block
fi

section "Memory"
if command_exists free; then
  free -h | code_block
else
  grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo 2>/dev/null | code_block
fi

section "Block Devices"
if command_exists lsblk; then
  lsblk -e7 -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL 2>/dev/null | code_block
else
  echo "lsblk not available" | code_block
fi

section "Filesystems"
df -hT 2>/dev/null | code_block

section "Network Addresses"
if command_exists ip; then
  ip -brief address 2>/dev/null | code_block
else
  hostname -I 2>/dev/null | code_block
fi

section "Routes"
if command_exists ip; then
  ip route 2>/dev/null | code_block
else
  echo "ip command not available" | code_block
fi

section "DNS Resolver"
if [[ -r /etc/resolv.conf ]]; then
  sed -n '1,80p' /etc/resolv.conf | code_block
else
  echo "/etc/resolv.conf not readable" | code_block
fi

section "Time Status"
if command_exists timedatectl; then
  timedatectl 2>/dev/null | code_block
else
  date | code_block
fi

section "Service Summary"
if command_exists systemctl; then
  {
    echo "Failed units:"
    systemctl --failed --no-pager 2>/dev/null || true
    echo
    echo "Enabled service count:"
    systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null | tail -n 1 || true
  } | code_block
else
  echo "systemctl not available" | code_block
fi
