#!/usr/bin/env bash
# Path: scripts/logging/sasd-auth-log-report.sh
# Purpose: Summarize authentication-related log activity.
# Date: 2026-06-29
# License: MIT
#
# Why this matters:
#   Failed SSH logins, sudo usage and privilege changes are among the first log
#   sources a Linux administrator should review during routine operations and
#   incident triage.
#
# Exit codes:
#   0 = report generated
#   1 = report generated and suspicious patterns were found
#   3 = unknown / no readable authentication logs

set -uo pipefail

VERSION="0.2.0"
SINCE="today"
LIMIT=20

usage() {
  cat <<'USAGE'
Usage: sasd-auth-log-report.sh [OPTIONS]

Create a Markdown summary of authentication-related log entries.

Options:
      --since VALUE     journalctl time range, default: today
      --limit NUMBER    Number of sample lines per section, default: 20
  -h, --help            Show this help text
      --version         Print version

Examples:
  scripts/logging/sasd-auth-log-report.sh
  scripts/logging/sasd-auth-log-report.sh --since yesterday --limit 50

Notes:
  The script is read-only. Running it as root may reveal more complete log data.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE="${2:-}"
      shift 2
      ;;
    --limit)
      LIMIT="${2:-}"
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

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || (( LIMIT < 1 )); then
  echo "UNKNOWN - --limit must be a positive integer" >&2
  exit 3
fi

collect_logs() {
  # Prefer journalctl on systemd systems because it avoids distribution-specific
  # auth log filenames. Fall back to traditional text files on older systems.
  if command -v journalctl >/dev/null 2>&1; then
    journalctl --since "$SINCE" --no-pager _COMM=sshd _COMM=sudo _COMM=su 2>/dev/null || true
    journalctl --since "$SINCE" --no-pager SYSLOG_IDENTIFIER=sshd SYSLOG_IDENTIFIER=sudo SYSLOG_IDENTIFIER=su 2>/dev/null || true
    return 0
  fi

  found_file=0
  for file in /var/log/auth.log /var/log/secure; do
    if [[ -r "$file" ]]; then
      found_file=1
      cat "$file"
    fi
  done

  if (( found_file == 0 )); then
    return 1
  fi
}

logs="$(collect_logs)" || {
  echo "UNKNOWN - no readable authentication log source found" >&2
  exit 3
}

if [[ -z "$logs" ]]; then
  echo "UNKNOWN - authentication log source is empty or not readable" >&2
  exit 3
fi

count_pattern() {
  local pattern="$1"
  grep -Eic "$pattern" <<<"$logs" || true
}

print_samples() {
  local title="$1"
  local pattern="$2"

  printf '\n## %s\n\n' "$title"
  printf '```text\n'
  grep -Ei "$pattern" <<<"$logs" | tail -n "$LIMIT" || true
  printf '```\n'
}

failed_ssh="$(count_pattern 'Failed password|Invalid user|authentication failure')"
accepted_ssh="$(count_pattern 'Accepted (publickey|password|keyboard-interactive)')"
sudo_usage="$(count_pattern 'sudo:.*COMMAND=')"
su_usage="$(count_pattern 'su:|session opened for user root')"

printf '# Authentication Log Report\n\n'
printf 'Generated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Since: `%s`  \n' "$SINCE"
printf 'Sample limit per section: `%s`\n\n' "$LIMIT"

printf '| Metric | Count |\n'
printf '| --- | ---: |\n'
printf '| Failed SSH/auth attempts | %s |\n' "$failed_ssh"
printf '| Accepted SSH logins | %s |\n' "$accepted_ssh"
printf '| sudo command entries | %s |\n' "$sudo_usage"
printf '| su/root session entries | %s |\n' "$su_usage"

print_samples 'Failed SSH/auth samples' 'Failed password|Invalid user|authentication failure'
print_samples 'Accepted SSH samples' 'Accepted (publickey|password|keyboard-interactive)'
print_samples 'sudo samples' 'sudo:.*COMMAND='
print_samples 'su/root session samples' 'su:|session opened for user root'

if (( failed_ssh > 0 )); then
  exit 1
fi

exit 0
