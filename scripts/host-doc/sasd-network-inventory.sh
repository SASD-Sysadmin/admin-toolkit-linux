#!/usr/bin/env bash
# scripts/host-doc/sasd-network-inventory.sh
# Purpose: Read-only Linux network inventory for host documentation.
# Date: 2026-06-30

set -u

SCRIPT_NAME="sasd-network-inventory"
MAX_LINES=120
SHOW_RESOLV_CONF=1
SHOW_NEIGH=1

usage() {
  cat <<'USAGE'
Usage: sasd-network-inventory.sh [options]

Create a read-only network inventory report for the local host.

Options:
  --max-lines N          Limit long command sections to N lines (default: 120)
  --no-resolv-conf       Do not print /etc/resolv.conf content
  --no-neigh             Do not print neighbor/ARP table
  -h, --help             Show this help

Notes:
  - This script does not change network configuration.
  - It does not contact external services.
  - It can run as a normal user; some optional details may be incomplete.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --max-lines)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-lines requires a value" >&2; exit 2; }
      MAX_LINES="$2"
      shift 2
      ;;
    --no-resolv-conf)
      SHOW_RESOLV_CONF=0
      shift
      ;;
    --no-neigh)
      SHOW_NEIGH=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
 done

case "$MAX_LINES" in
  ''|*[!0-9]*) echo "ERROR: --max-lines must be a positive integer" >&2; exit 2 ;;
  0) echo "ERROR: --max-lines must be greater than zero" >&2; exit 2 ;;
esac

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

first_output_line_or() {
  # Print the first non-empty output line of a command, or a fallback value.
  # Some systemctl queries print a useful state such as "disabled" but still
  # return a non-zero exit code. Using `cmd || echo fallback` would then create
  # multi-line Markdown table cells. This helper keeps table output stable.
  local fallback="$1"
  shift
  local output
  output="$({ "$@" 2>/dev/null || true; } | awk 'NF { print; exit }')"
  if [ -n "$output" ]; then
    printf '%s' "$output"
  else
    printf '%s' "$fallback"
  fi
}

print_code_block() {
  # $1 command label; stdin content
  local title="$1"
  echo "### $title"
  echo
  echo '```text'
  sed -n "1,${MAX_LINES}p"
  echo '```'
  echo
}

run_limited() {
  # $1 title, remaining args command
  local title="$1"
  shift
  echo "### $title"
  echo
  echo '```text'
  "$@" 2>&1 | sed -n "1,${MAX_LINES}p"
  echo '```'
  echo
}

redact_resolv_conf() {
  # Keep useful resolver context, avoid dumping arbitrary comments/options forever.
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*(nameserver|search|domain|options)[[:space:]]/ { print; next }
  ' /etc/resolv.conf 2>/dev/null | sed -n "1,${MAX_LINES}p"
}

HOSTNAME_SHORT="$(hostname 2>/dev/null || printf 'unknown')"
GENERATED="$(date -Is 2>/dev/null || date)"
USER_NAME="$(id -un 2>/dev/null || printf 'unknown')"
EUID_VALUE="$(id -u 2>/dev/null || printf 'unknown')"
PRIVILEGE="non-root"
if [ "$EUID_VALUE" = "0" ]; then
  PRIVILEGE="root"
fi

cat <<EOF_HEADER
# SASD Network Inventory

- Generated: ${GENERATED}
- Host: ${HOSTNAME_SHORT}
- User: ${USER_NAME}
- Effective UID: ${EUID_VALUE}
- Privilege: ${PRIVILEGE}
- Max lines per section: ${MAX_LINES}

> Read-only report. This script does not change network configuration and does
> not contact external services. IP addresses, routes, DNS settings and interface
> names can be sensitive; review before sharing.

EOF_HEADER

cat <<'EOF_SCOPE'
## Completeness note

Most network inventory data is visible without root. Details that depend on
system-specific tooling, namespaces or protected configuration may be incomplete.

EOF_SCOPE

cat <<'EOF_TOOLS'
## Tool detection

| Tool | State | Path |
| --- | --- | --- |
EOF_TOOLS
for tool in ip ss hostname resolvectl systemctl nmcli networkctl ethtool awk sed; do
  if has_cmd "$tool"; then
    printf '| `%s` | `OK` | `%s` |\n' "$tool" "$(command -v "$tool")"
  else
    printf '| `%s` | `MISS` | `not found` |\n' "$tool"
  fi
done

echo

echo "## Hostname and naming"
echo
if has_cmd hostname; then
  echo '| Item | Value |'
  echo '| --- | --- |'
  printf '| Short hostname | `%s` |\n' "$(hostname 2>/dev/null || printf 'unknown')"
  printf '| FQDN hint | `%s` |\n' "$(hostname -f 2>/dev/null || printf 'unavailable')"
  printf '| Domain hint | `%s` |\n' "$(hostname -d 2>/dev/null || printf 'unavailable')"
else
  echo 'INFO: hostname command not found.'
fi

echo

echo "## Interface summary"
echo
if has_cmd ip; then
  run_limited "ip -brief link" ip -brief link show
  run_limited "ip -brief address" ip -brief address show
else
  echo 'INFO: ip command not found; using /sys/class/net fallback.'
  echo
  echo '| Interface | Operstate | MAC hint |'
  echo '| --- | --- | --- |'
  for iface_path in /sys/class/net/*; do
    [ -e "$iface_path" ] || continue
    iface="$(basename "$iface_path")"
    operstate="$(cat "$iface_path/operstate" 2>/dev/null || printf 'unknown')"
    address="$(cat "$iface_path/address" 2>/dev/null || printf 'unknown')"
    printf '| `%s` | `%s` | `%s` |\n' "$iface" "$operstate" "$address"
  done
  echo
fi

echo "## Routing"
echo
if has_cmd ip; then
  run_limited "IPv4 default routes" ip route show default
  run_limited "IPv6 default routes" ip -6 route show default
  run_limited "IPv4 routes" ip route show
  run_limited "IPv6 routes" ip -6 route show
else
  echo 'INFO: ip command not found; route inventory unavailable.'
  echo
fi

if [ "$SHOW_NEIGH" -eq 1 ]; then
  echo "## Neighbor table"
  echo
  if has_cmd ip; then
    run_limited "ip neigh show" ip neigh show
  else
    echo 'INFO: ip command not found; neighbor inventory unavailable.'
    echo
  fi
fi

echo "## DNS resolver context"
echo
if has_cmd resolvectl; then
  run_limited "resolvectl status" resolvectl status
else
  echo 'INFO: resolvectl not found or not available.'
  echo
fi

if [ "$SHOW_RESOLV_CONF" -eq 1 ]; then
  echo "### /etc/resolv.conf selected lines"
  echo
  if [ -r /etc/resolv.conf ]; then
    echo '```text'
    redact_resolv_conf
    echo '```'
  else
    echo 'INFO: /etc/resolv.conf is not readable.'
  fi
  echo
fi

echo "## Network service managers"
echo
if has_cmd systemctl; then
  echo '| Unit | Enabled | Active |'
  echo '| --- | --- | --- |'
  for unit in NetworkManager.service systemd-networkd.service systemd-resolved.service networking.service wicked.service; do
    enabled="$(first_output_line_or unknown systemctl is-enabled "$unit")"
    active="$(first_output_line_or inactive systemctl is-active "$unit")"
    printf '| `%s` | `%s` | `%s` |\n' "$unit" "$enabled" "$active"
  done
else
  echo 'INFO: systemctl not found; service-manager state unavailable.'
fi

echo

if has_cmd nmcli; then
  run_limited "NetworkManager devices" nmcli device status
else
  echo "## NetworkManager devices"
  echo
  echo 'INFO: nmcli not found.'
  echo
fi

if has_cmd networkctl; then
  run_limited "systemd-networkd links" networkctl list --no-pager
else
  echo "## systemd-networkd links"
  echo
  echo 'INFO: networkctl not found.'
  echo
fi

echo "## Interface driver hints"
echo
if has_cmd ethtool && has_cmd ip; then
  echo '| Interface | Driver | Version | Firmware | Bus info |'
  echo '| --- | --- | --- | --- | --- |'
  ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | awk '{print $1}' | sed 's/@.*//' | while IFS= read -r iface; do
    [ -n "$iface" ] || continue
    info="$(ethtool -i "$iface" 2>/dev/null || true)"
    driver="$(printf '%s\n' "$info" | awk -F': ' '/^driver:/ {print $2; exit}')"
    version="$(printf '%s\n' "$info" | awk -F': ' '/^version:/ {print $2; exit}')"
    firmware="$(printf '%s\n' "$info" | awk -F': ' '/^firmware-version:/ {print $2; exit}')"
    bus="$(printf '%s\n' "$info" | awk -F': ' '/^bus-info:/ {print $2; exit}')"
    [ -n "$driver" ] || driver="unavailable"
    [ -n "$version" ] || version="unavailable"
    [ -n "$firmware" ] || firmware="unavailable"
    [ -n "$bus" ] || bus="unavailable"
    printf '| `%s` | `%s` | `%s` | `%s` | `%s` |\n' "$iface" "$driver" "$version" "$firmware" "$bus"
  done | sed -n "1,${MAX_LINES}p"
else
  echo 'INFO: ethtool or ip not found; driver hints unavailable.'
fi

echo
cat <<'EOF_FOOTER'
## Review hints

- Compare interface names, addresses and routes with the expected host role.
- Default routes and DNS search domains can reveal environment details.
- Use `scripts/network/sasd-listening-services-report.sh` for listening sockets.
- Use this report as host documentation, not as proof of firewall or exposure state.
EOF_FOOTER

exit 0
