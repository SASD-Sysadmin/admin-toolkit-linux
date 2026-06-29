#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# File: scripts/security/sasd-ssh-baseline-check.sh
# Purpose: Check selected sshd baseline settings without changing configuration.
#
# The script is read-only and safe for lab systems. It tries to report useful
# information even when openssh-server is not installed. This matters on WSL,
# containers and minimal hosts where /etc/ssh/sshd_config may not exist.
#
# Typical usage:
#   ./scripts/security/sasd-ssh-baseline-check.sh
#   ./scripts/security/sasd-ssh-baseline-check.sh /path/to/sshd_config
#

set -o nounset
set -o pipefail

VERSION="0.1.1"

usage() {
  cat <<'USAGE'
Usage: sasd-ssh-baseline-check.sh [CONFIG_FILE]
       sasd-ssh-baseline-check.sh --help
       sasd-ssh-baseline-check.sh --version

Check selected sshd security settings. Default config file: /etc/ssh/sshd_config
This script does not modify sshd configuration.

Exit codes:
  0  Report created. Findings are expressed in the report body.
  1  Invalid arguments.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

config="${1:-/etc/ssh/sshd_config}"
missing_config="false"

# OpenSSH server is not installed on every Linux system. On WSL or containers this
# is common and should not make a wrapper report look broken. We still report the
# missing source clearly so the operator can decide whether it matters.
if [[ ! -r "$config" ]]; then
  missing_config="true"
fi

get_effective() {
  local key="$1"

  if [[ "$missing_config" == "true" ]]; then
    return 1
  fi

  if command -v sshd >/dev/null 2>&1 && sshd -T -f "$config" >/dev/null 2>&1; then
    sshd -T -f "$config" 2>/dev/null | awk -v k="${key,,}" '$1 == k {print $2; exit}'
  else
    awk -v k="${key,,}" '
      /^[[:space:]]*#/ {next}
      NF >= 2 { low=tolower($1); if (low == k) {print $2; found=1} }
      END { if (!found) exit 1 }
    ' "$config" 2>/dev/null | tail -n 1
  fi
}

check_eq() {
  local key="$1" expected="$2" severity="$3" actual

  if [[ "$missing_config" == "true" ]]; then
    printf '| %s | INFO | config not readable / not present | expected: %s |\n' "$key" "$expected"
    return 0
  fi

  actual="$(get_effective "$key" || true)"
  if [[ -z "$actual" ]]; then
    printf '| %s | INFO | not set / default unknown | expected: %s |\n' "$key" "$expected"
    return 0
  fi
  if [[ "$actual" == "$expected" ]]; then
    printf '| %s | OK | %s | expected: %s |\n' "$key" "$actual" "$expected"
  else
    printf '| %s | %s | %s | expected: %s |\n' "$key" "$severity" "$actual" "$expected"
  fi
}

cat <<REPORT
# SASD SSH Baseline Check

Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname 2>/dev/null || echo unknown)
Config: $config
REPORT

if [[ "$missing_config" == "true" ]]; then
  cat <<'NOTE'

> Note: The configured sshd_config file is not readable or not present.
> This can be normal on WSL, containers or systems without openssh-server.
NOTE
fi

cat <<'TABLE'

| Setting | Status | Actual | Baseline |
| --- | --- | --- | --- |
TABLE

check_eq PermitRootLogin no WARN
check_eq PasswordAuthentication no WARN
check_eq PubkeyAuthentication yes WARN
check_eq X11Forwarding no INFO

if [[ "$missing_config" == "true" ]]; then
  printf '| MaxAuthTries | INFO | config not readable / not present | expected: <=4 |\n'
else
  max_auth="$(get_effective MaxAuthTries || true)"
  if [[ -n "$max_auth" && "$max_auth" =~ ^[0-9]+$ && "$max_auth" -le 4 ]]; then
    printf '| MaxAuthTries | OK | %s | expected: <=4 |\n' "$max_auth"
  elif [[ -n "$max_auth" ]]; then
    printf '| MaxAuthTries | WARN | %s | expected: <=4 |\n' "$max_auth"
  else
    printf '| MaxAuthTries | INFO | not set / default unknown | expected: <=4 |\n'
  fi
fi
