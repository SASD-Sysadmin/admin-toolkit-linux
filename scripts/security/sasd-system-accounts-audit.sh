#!/usr/bin/env bash
# Path: scripts/security/sasd-system-accounts-audit.sh
# Purpose: Report system accounts that have an interactive login shell.
# Date: 2026-06-29
# License: MIT
#
# Why this matters:
#   Service and system accounts should usually not be interactive login accounts.
#   An unexpected shell such as /bin/bash on a low-UID service account can be a
#   sign of weak hardening, legacy configuration, or a compromised account.
#
# Exit codes:
#   0 = no suspicious system accounts found
#   1 = at least one system account has an interactive shell
#   3 = unknown / required file not readable

set -uo pipefail

VERSION="0.2.0"
PASSWD_FILE="/etc/passwd"
LOGIN_DEFS="/etc/login.defs"
UID_MIN_FALLBACK=1000

usage() {
  cat <<'USAGE'
Usage: sasd-system-accounts-audit.sh [OPTIONS]

Report system accounts with interactive shells.

Options:
      --passwd FILE      passwd-compatible file to inspect, default: /etc/passwd
      --uid-min NUMBER   first normal user UID, default: read from /etc/login.defs or 1000
  -h, --help             Show this help text
      --version          Print version

Notes:
  The script is read-only. It does not lock, delete or modify accounts.
USAGE
}

UID_MIN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --passwd)
      PASSWD_FILE="${2:-}"
      shift 2
      ;;
    --uid-min)
      UID_MIN="${2:-}"
      shift 2
      ;;
    --version)
      echo "$VERSION"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN - unsupported argument: $1" >&2
      usage >&2
      exit 3
      ;;
  esac
done

if [[ ! -r "$PASSWD_FILE" ]]; then
  echo "UNKNOWN - cannot read passwd file: $PASSWD_FILE" >&2
  exit 3
fi

if [[ -z "$UID_MIN" ]]; then
  if [[ -r "$LOGIN_DEFS" ]]; then
    UID_MIN="$(awk '$1 == "UID_MIN" {print $2; exit}' "$LOGIN_DEFS" 2>/dev/null || true)"
  fi
  UID_MIN="${UID_MIN:-$UID_MIN_FALLBACK}"
fi

if ! [[ "$UID_MIN" =~ ^[0-9]+$ ]]; then
  echo "UNKNOWN - UID_MIN is not numeric: $UID_MIN" >&2
  exit 3
fi

printf '# System Accounts Audit\n\n'
printf 'Generated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Passwd file: `%s`  \n' "$PASSWD_FILE"
printf 'Normal users start at UID: `%s`\n\n' "$UID_MIN"
printf '| Finding | User | UID | GID | Home | Shell |\n'
printf '| --- | --- | ---: | ---: | --- | --- |\n'

found=0

# Shells that are normally non-interactive. The list intentionally includes
# absolute paths and common service placeholders used by Linux distributions.
is_noninteractive_shell() {
  case "$1" in
    ''|/usr/sbin/nologin|/sbin/nologin|/bin/false|/usr/bin/false|/bin/sync|/sbin/shutdown|/sbin/halt)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while IFS=: read -r user _password uid gid _gecos home shell; do
  # Skip malformed rows; /etc/passwd should not have them, but audit tools should
  # be defensive when they may inspect test fixtures.
  [[ "$uid" =~ ^[0-9]+$ ]] || continue

  # Root is intentionally excluded from this finding. Root usually has an
  # interactive shell; that is a separate hardening policy decision.
  [[ "$user" == "root" ]] && continue

  if (( uid < UID_MIN )) && ! is_noninteractive_shell "$shell"; then
    printf '| SYSTEM_ACCOUNT_WITH_LOGIN_SHELL | `%s` | %s | %s | `%s` | `%s` |\n' \
      "$user" "$uid" "$gid" "$home" "$shell"
    found=1
  fi
done < "$PASSWD_FILE"

if (( found == 0 )); then
  printf '| OK | No system accounts with interactive shells found |  |  |  |  |\n'
fi

exit "$found"
