#!/usr/bin/env bash
# Path: scripts/security/sasd-ssh-baseline-check.sh
# Purpose: Check important sshd baseline settings without changing configuration.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: sasd-ssh-baseline-check.sh [CONFIG_FILE]
       sasd-ssh-baseline-check.sh --help

Check selected sshd security settings. Default config file: /etc/ssh/sshd_config
This script does not modify sshd configuration.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

config="${1:-/etc/ssh/sshd_config}"

if [[ ! -r "$config" ]]; then
  echo "ERROR: cannot read $config" >&2
  exit 2
fi

get_effective() {
  local key="$1"
  if command -v sshd >/dev/null 2>&1; then
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

cat <<EOF
# SASD SSH Baseline Check

Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Hostname: $(hostname 2>/dev/null || echo unknown)
Config: $config

| Setting | Status | Actual | Baseline |
| --- | --- | --- | --- |
EOF

check_eq PermitRootLogin no WARN
check_eq PasswordAuthentication no WARN
check_eq PubkeyAuthentication yes WARN
check_eq X11Forwarding no INFO

max_auth="$(get_effective MaxAuthTries || true)"
if [[ -n "$max_auth" && "$max_auth" =~ ^[0-9]+$ && "$max_auth" -le 4 ]]; then
  printf '| MaxAuthTries | OK | %s | expected: <=4 |\n' "$max_auth"
elif [[ -n "$max_auth" ]]; then
  printf '| MaxAuthTries | WARN | %s | expected: <=4 |\n' "$max_auth"
else
  printf '| MaxAuthTries | INFO | not set / default unknown | expected: <=4 |\n'
fi
