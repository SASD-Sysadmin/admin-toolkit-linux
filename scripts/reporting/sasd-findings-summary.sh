#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/reporting/sasd-findings-summary.sh
# Project: admin-toolkit-linux
# Purpose: Generate a compact read-only findings summary from local host state.
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# Read-only. This script does not fix findings. It intentionally avoids automatic
# remediation. The output is a triage aid for administrators.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

FORMAT="markdown"
MAX_ITEMS=40
SHOW_INFO=1

usage() {
  cat <<'USAGE'
Usage:
  sasd-findings-summary.sh [options]

Options:
  --format markdown|text|tsv  Output format. Default: markdown.
  --max-items N               Limit findings per dynamic section. Default: 40.
  --no-info                   Hide informational findings.
  -h, --help                  Show this help.

Examples:
  ./scripts/reporting/sasd-findings-summary.sh
  ./scripts/reporting/sasd-findings-summary.sh --format tsv
USAGE
}

log_error() { printf 'ERROR: %s\n' "$*" >&2; }
is_uint() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
md_escape() { printf '%s' "$1" | sed 's/|/\\|/g'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --format)
      [ "$#" -ge 2 ] || { log_error "--format requires a value"; exit 2; }
      case "$2" in markdown|text|tsv) FORMAT="$2" ;; *) log_error "unsupported format: $2"; exit 2 ;; esac
      shift 2 ;;
    --max-items)
      [ "$#" -ge 2 ] || { log_error "--max-items requires a value"; exit 2; }
      is_uint "$2" || { log_error "--max-items must be numeric"; exit 2; }
      MAX_ITEMS="$2"; shift 2 ;;
    --no-info) SHOW_INFO=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/sasd-findings-summary.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

add_finding() {
  # Fields: severity, area, finding, evidence, next_step
  local severity="$1"
  local area="$2"
  local finding="$3"
  local evidence="$4"
  local next_step="$5"
  if [ "$severity" = "INFO" ] && [ "$SHOW_INFO" -eq 0 ]; then
    return
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$severity" "$area" "$finding" "$evidence" "$next_step" >> "$TMP_FILE"
}

file_mode() {
  stat -c '%a' "$1" 2>/dev/null || printf 'unknown'
}

file_owner() {
  stat -c '%U:%G' "$1" 2>/dev/null || printf 'unknown'
}

is_world_writable() {
  [ -e "$1" ] || [ -L "$1" ] || return 1
  find "$1" -maxdepth 0 -perm -0002 -print -quit 2>/dev/null | grep -q .
}

is_group_writable() {
  [ -e "$1" ] || [ -L "$1" ] || return 1
  find "$1" -maxdepth 0 -perm -0020 -print -quit 2>/dev/null | grep -q .
}

# High-value configuration checks discovered by prior audit runs on developer
# systems and common servers. Do not repair here; only report.
for item in \
  /etc/crontab \
  /etc/cron.d \
  /etc/cron.hourly \
  /etc/cron.daily \
  /etc/cron.weekly \
  /etc/cron.monthly \
  /etc/mysql/my.cnf \
  /etc/my.cnf \
  /etc/ssh/sshd_config \
  /etc/sudoers; do
  if [ -e "$item" ] || [ -L "$item" ]; then
    if is_world_writable "$item"; then
      add_finding "HIGH" "permissions" "Sensitive path is world-writable" "$item mode=$(file_mode "$item") owner=$(file_owner "$item")" "Review ownership and permissions; do not chmod blindly on production."
    elif is_group_writable "$item"; then
      add_finding "WARN" "permissions" "Sensitive path is group-writable" "$item mode=$(file_mode "$item") owner=$(file_owner "$item")" "Confirm group membership and whether group write is intended."
    fi
  fi
done

# Cron files are executable and can run as root. World-writable entries here are
# especially suspicious and deserve a compact summary.
for dir in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
  [ -d "$dir" ] || continue
  count=0
  while IFS= read -r -d '' file; do
    add_finding "HIGH" "scheduling" "Cron entry is writable by everyone" "$file mode=$(file_mode "$file") owner=$(file_owner "$file")" "Review file contents, origin package and permissions."
    count=$((count + 1))
    [ "$count" -ge "$MAX_ITEMS" ] && break
  done < <(find "$dir" -maxdepth 1 \( -type f -o -type l \) -perm -0002 -print0 2>/dev/null | sort -z)
done

# Listening services bound to all interfaces or non-loopback addresses. This is
# not automatically wrong, but it is a firewall/exposure review item.
if command -v ss >/dev/null 2>&1; then
  any_count="$(ss -H -tuln 2>/dev/null | awk '$5 !~ /^(127\.0\.0\.1|\[::1\]|::1)/ {c++} END{print c+0}')"
  if [ "$any_count" -gt 0 ]; then
    add_finding "WARN" "network" "Listening sockets are bound beyond loopback" "count=$any_count" "Compare listeners with the host role and firewall policy."
  else
    add_finding "INFO" "network" "No non-loopback listening sockets detected" "ss -tuln" "No action required unless expected services are missing."
  fi
else
  add_finding "INFO" "network" "Cannot inspect listening sockets" "ss not installed" "Install iproute2/ss on systems where this check matters."
fi

# Firewall state. A workstation, WSL instance or isolated lab host may not need a
# full local firewall. Servers normally should have an explicit policy.
if command -v nft >/dev/null 2>&1; then
  nft_lines="$(nft list ruleset 2>/dev/null | wc -l | awk '{print $1}')"
  if [ "$nft_lines" -eq 0 ]; then
    add_finding "WARN" "firewall" "nft is installed but no ruleset is visible" "nft ruleset lines=0" "Decide whether the host role requires local firewall rules."
  else
    add_finding "INFO" "firewall" "nft ruleset is visible" "nft ruleset lines=$nft_lines" "Review rules separately if this host is exposed."
  fi
elif command -v iptables >/dev/null 2>&1; then
  add_finding "INFO" "firewall" "iptables is installed" "iptables command available" "Review iptables rules with dedicated firewall report."
else
  add_finding "WARN" "firewall" "No common local firewall tool detected" "nft/iptables not found" "Confirm whether firewalling is handled elsewhere."
fi

# auditd state.
if command -v auditctl >/dev/null 2>&1; then
  add_finding "INFO" "audit" "auditctl is installed" "auditctl=$(command -v auditctl)" "Review auditd status and rules for server workloads."
else
  add_finding "INFO" "audit" "auditd tools are not installed" "auditctl not found" "Often acceptable on WSL/dev hosts; review for servers."
fi

# SSH daemon config presence.
if [ -r /etc/ssh/sshd_config ]; then
  add_finding "INFO" "ssh" "OpenSSH server configuration is readable" "/etc/ssh/sshd_config" "Run the SSH baseline report for detailed settings."
else
  add_finding "INFO" "ssh" "OpenSSH server configuration not readable or absent" "/etc/ssh/sshd_config" "Normal on WSL/containers or hosts without openssh-server."
fi

# System/service accounts with interactive shells.
if [ -r /etc/passwd ]; then
  awk -F: '($3 < 1000 && $1 != "root" && $7 !~ /(nologin|false|sync|shutdown|halt)$/) {print $1 " uid=" $3 " shell=" $7}' /etc/passwd |
    head -n "$MAX_ITEMS" |
    while IFS= read -r line; do
      add_finding "WARN" "accounts" "System account has an interactive shell" "$line" "Confirm whether the service account needs shell access."
    done
fi

# Known database config paths with broad permissions.
for item in /etc/mysql/my.cnf /etc/postgresql /etc/postgresql-common; do
  if [ -e "$item" ] || [ -L "$item" ]; then
    if is_world_writable "$item"; then
      add_finding "HIGH" "database" "Database configuration path is world-writable" "$item mode=$(file_mode "$item") owner=$(file_owner "$item")" "Review immediately; database config should not be writable by everyone."
    fi
  fi
done

HOSTNAME_VALUE="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
GENERATED_AT="$(date -Iseconds)"

severity_order() {
  awk -F '\t' 'BEGIN{OFS="\t"}
    $1=="HIGH"{p=1}
    $1=="WARN"{p=2}
    $1=="INFO"{p=3}
    {print p,$0}' "$TMP_FILE" | sort -t $'\t' -k1,1n -k3,3 -k4,4 | cut -f2-
}

case "$FORMAT" in
  markdown)
    cat <<HEADER
# SASD Findings Summary

- Generated: $GENERATED_AT
- Host: $HOSTNAME_VALUE

> Read-only triage summary. This is not an automatic remediation plan. Validate each finding before changing a system.

| Severity | Area | Finding | Evidence | Suggested next step |
| --- | --- | --- | --- | --- |
HEADER
    if [ ! -s "$TMP_FILE" ]; then
      printf '| INFO | general | No findings generated | local checks | No action required |\n'
    else
      severity_order | while IFS=$'\t' read -r sev area finding evidence next_step; do
        printf '| `%s` | `%s` | %s | `%s` | %s |\n' \
          "$(md_escape "$sev")" "$(md_escape "$area")" "$(md_escape "$finding")" "$(md_escape "$evidence")" "$(md_escape "$next_step")"
      done
    fi
    ;;
  text)
    printf 'SASD Findings Summary\nGenerated: %s\nHost:      %s\n\n' "$GENERATED_AT" "$HOSTNAME_VALUE"
    if [ ! -s "$TMP_FILE" ]; then
      printf 'INFO general No findings generated local checks No action required\n'
    else
      severity_order | while IFS=$'\t' read -r sev area finding evidence next_step; do
        printf '%-5s %-12s %s | %s | %s\n' "$sev" "$area" "$finding" "$evidence" "$next_step"
      done
    fi
    ;;
  tsv)
    printf 'severity\tarea\tfinding\tevidence\tnext_step\n'
    severity_order
    ;;
esac

exit 0
