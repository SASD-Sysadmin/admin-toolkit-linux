#!/usr/bin/env bash
#
# scripts/reporting/sasd-findings-summary.sh
#
# Purpose:
#   Generate a compact, read-only triage summary for common Linux admin findings.
#
# Safety:
#   Read-only. The script never changes files, services or permissions.
#
# Symlink policy:
#   The script evaluates effective target permissions for symlinks where possible.
#   Symlink lstat mode 777 alone is not reported as HIGH.

set -u
set -o pipefail

ROWS_FILE="$(mktemp)" || exit 2
trap "rm -f '$ROWS_FILE'" EXIT

markdown_escape() { local v="${1:-}"; v="${v//|/\\|}"; printf '%s' "$v"; }

add_row() {
  local severity="$1" area="$2" finding="$3" evidence="$4" next_step="$5"
  printf '%s\t%s\t%s\t%s\t%s\n' "$severity" "$area" "$finding" "$evidence" "$next_step" >>"$ROWS_FILE"
}

mode_has_other_write() {
  local mode="$1"
  [[ "$mode" =~ ^[0-7]+$ ]] || return 1
  (( 8#$mode & 00002 ))
}

mode_has_group_write() {
  local mode="$1"
  [[ "$mode" =~ ^[0-7]+$ ]] || return 1
  (( 8#$mode & 00020 ))
}

effective_stat() {
  local path="$1"
  local mode owner group resolved note

  [[ -e "$path" || -L "$path" ]] || return 1

  if [[ -L "$path" ]]; then
    resolved="$(readlink -f -- "$path" 2>/dev/null || true)"
    note="symlink"
    if [[ -z "$resolved" || ! -e "$resolved" ]]; then
      printf 'dangling\t-\t-\t%s\t%s\n' "$note" "${resolved:--}"
      return 0
    fi
    mode="$(stat -Lc '%a' -- "$path" 2>/dev/null || echo '-')"
    owner="$(stat -Lc '%U' -- "$path" 2>/dev/null || echo '-')"
    group="$(stat -Lc '%G' -- "$path" 2>/dev/null || echo '-')"
  else
    resolved="$path"
    note="direct"
    mode="$(stat -c '%a' -- "$path" 2>/dev/null || echo '-')"
    owner="$(stat -c '%U' -- "$path" 2>/dev/null || echo '-')"
    group="$(stat -c '%G' -- "$path" 2>/dev/null || echo '-')"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$mode" "$owner" "$group" "$note" "$resolved"
}

check_sensitive_path() {
  local path="$1" area="$2" label="$3" high_text="$4"
  local row mode owner group note resolved
  row="$(effective_stat "$path")" || return 0
  IFS=$'\t' read -r mode owner group note resolved <<<"$row"

  if [[ "$mode" == "dangling" ]]; then
    add_row "WARN" "$area" "$label is a dangling symlink" "$path target missing" "Review package ownership and expected target."
    return 0
  fi

  if mode_has_other_write "$mode"; then
    add_row "HIGH" "$area" "$high_text" "$path effective_mode=$mode owner=$owner:$group link=$note target=$resolved" "Review immediately; do not chmod blindly on production."
  elif mode_has_group_write "$mode"; then
    add_row "WARN" "$area" "$label is group-writable" "$path effective_mode=$mode owner=$owner:$group link=$note target=$resolved" "Confirm whether the owning group and write access are intended."
  fi
}

check_scheduling_permissions() {
  local entry
  for entry in /etc/crontab /etc/cron.d/* /etc/cron.hourly/* /etc/cron.daily/* /etc/cron.weekly/* /etc/cron.monthly/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    check_sensitive_path "$entry" "scheduling" "Cron entry" "Cron entry target is writable by everyone"
  done
}

check_database_configs() {
  local entry
  for entry in /etc/mysql/my.cnf /etc/mysql/mariadb.cnf /etc/mysql/conf.d/* /etc/mysql/mariadb.conf.d/* /etc/postgresql/*/*/postgresql.conf /etc/postgresql/*/*/pg_hba.conf; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    check_sensitive_path "$entry" "database" "Database configuration path" "Database configuration target is writable by everyone"
  done
}

check_system_config_permissions() {
  local entry
  for entry in /etc/sudoers /etc/sudoers.d/* /etc/ssh/sshd_config /etc/systemd/system/*.service /etc/systemd/system/*.timer; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    check_sensitive_path "$entry" "permissions" "Sensitive system configuration path" "Sensitive system configuration target is writable by everyone"
  done
}

check_accounts() {
  local normal_min=1000
  local user _pass uid _gid _gecos _home shell
  while IFS=: read -r user _pass uid _gid _gecos _home shell; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    if [[ "$uid" -lt "$normal_min" && "$uid" -ne 0 ]]; then
      case "$shell" in
        /bin/bash|/bin/sh|/usr/bin/bash|/usr/bin/sh|/bin/zsh|/usr/bin/zsh|/bin/fish|/usr/bin/fish)
          add_row "WARN" "accounts" "System account has an interactive shell" "$user uid=$uid shell=$shell" "Confirm whether the service account needs shell access."
          ;;
      esac
    fi
  done </etc/passwd
}

check_firewall() {
  if command -v nft >/dev/null 2>&1; then
    local line_count
    line_count="$(nft list ruleset 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
    if [[ "${line_count:-0}" -eq 0 ]]; then
      add_row "WARN" "firewall" "nft is installed but no ruleset is visible" "nft ruleset lines=0" "Decide whether the host role requires local firewall rules."
    fi
  elif ! command -v ufw >/dev/null 2>&1 && ! command -v firewall-cmd >/dev/null 2>&1 && ! command -v iptables >/dev/null 2>&1; then
    add_row "INFO" "firewall" "No common firewall frontend was detected" "nft/iptables/ufw/firewalld not found" "Often acceptable on containers or WSL; review for servers."
  fi
}

check_auditd() {
  if ! command -v auditctl >/dev/null 2>&1; then
    add_row "INFO" "audit" "auditd tools are not installed" "auditctl not found" "Often acceptable on WSL/dev hosts; review for servers."
  fi
}

check_network_listeners() {
  command -v ss >/dev/null 2>&1 || return 0
  local count
  count="$(ss -H -tuln 2>/dev/null | awk '$5 !~ /^127\./ && $5 !~ /^\[::1\]/ && $5 !~ /^localhost/ { c++ } END { print c+0 }')"
  if [[ "${count:-0}" -gt 0 ]]; then
    add_row "WARN" "network" "Listening sockets are bound beyond loopback" "count=$count" "Compare listeners with the host role and firewall policy."
  fi
}

check_ssh() {
  if [[ ! -r /etc/ssh/sshd_config ]]; then
    add_row "INFO" "ssh" "OpenSSH server configuration not readable or absent" "/etc/ssh/sshd_config" "Normal on WSL/containers or hosts without openssh-server."
  fi
}

print_report() {
  local generated host
  generated="$(date --iso-8601=seconds)"
  host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"

  cat <<HEADER
# SASD Findings Summary

- Generated: $generated
- Host: $host

> Read-only triage summary. This is not an automatic remediation plan. Validate each finding before changing a system. Symlink mode bits are not treated as direct HIGH findings; effective target permissions are evaluated where possible.

| Severity | Area | Finding | Evidence | Suggested next step |
| --- | --- | --- | --- | --- |
HEADER

  if [[ ! -s "$ROWS_FILE" ]]; then
    echo "| \`INFO\` | \`summary\` | No predefined findings matched | default checks completed | Review detailed reports for environment-specific context. |"
    return 0
  fi

  awk -F'\t' '
    BEGIN { order["HIGH"]=1; order["WARN"]=2; order["INFO"]=3 }
    { print order[$1] "\t" $0 }
  ' "$ROWS_FILE" | sort -t $'\t' -k1,1n -k3,3 -k4,4 | cut -f2- | \
  while IFS=$'\t' read -r severity area finding evidence next_step; do
    printf '| `%s` | `%s` | %s | `%s` | %s |\n' \
      "$(markdown_escape "$severity")" "$(markdown_escape "$area")" \
      "$(markdown_escape "$finding")" "$(markdown_escape "$evidence")" "$(markdown_escape "$next_step")"
  done
}

main() {
  check_scheduling_permissions
  check_database_configs
  check_system_config_permissions
  check_accounts
  check_firewall
  check_auditd
  check_network_listeners
  check_ssh
  print_report
}

main "$@"
