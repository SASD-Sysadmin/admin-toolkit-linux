#!/usr/bin/env bash
# Path: scripts/security/sasd-ssh-baseline-check.sh
# Purpose: Report important sshd configuration settings.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"

usage() {
  cat <<'EOF'
Usage: sasd-ssh-baseline-check.sh [--help]

Report selected SSH daemon baseline settings from /etc/ssh/sshd_config.
Set SSHD_CONFIG=/path/to/file to check another file.
No system changes are made.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

printf '# SSH Baseline Check\n\nGenerated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Config file: `%s`\n\n' "$SSHD_CONFIG"

if [[ ! -r "$SSHD_CONFIG" ]]; then
  echo "ERROR: cannot read $SSHD_CONFIG" >&2
  exit 3
fi

keys=(
  PermitRootLogin
  PasswordAuthentication
  PubkeyAuthentication
  ChallengeResponseAuthentication
  KbdInteractiveAuthentication
  X11Forwarding
  AllowUsers
  AllowGroups
  DenyUsers
  DenyGroups
)

printf '| Setting | Configured value |\n'
printf '| --- | --- |\n'

for key in "${keys[@]}"; do
  value="$(awk -v key="$key" 'tolower($1) == tolower(key) { value=$0 } END { print value }' "$SSHD_CONFIG")"
  if [[ -z "$value" ]]; then
    value="not explicitly configured"
  fi
  printf '| `%s` | `%s` |\n' "$key" "$value"
done

printf '\n## Effective configuration if available\n\n'
printf '```text\n'
if command -v sshd >/dev/null 2>&1; then
  sshd -T 2>/dev/null | grep -Ei '^(permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|allowusers|allowgroups|denyusers|denygroups) ' || true
else
  echo 'sshd command not available'
fi
printf '```\n'
