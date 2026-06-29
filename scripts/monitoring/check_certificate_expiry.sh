#!/usr/bin/env bash
# Path: scripts/monitoring/check_certificate_expiry.sh
# Purpose: Monitoring-style TLS certificate expiry check.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: check_certificate_expiry.sh HOST [PORT] [WARNING_DAYS]

Check TLS certificate expiry with openssl.
Default PORT: 443
Default WARNING_DAYS: 30
Exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
EOF
}

host="${1:-}"
port="${2:-443}"
warning_days="${3:-30}"

if [[ "$host" == "--help" || "$host" == "-h" || -z "$host" ]]; then
  usage
  [[ -z "$host" ]] && exit 3 || exit 0
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "UNKNOWN - openssl is not available"
  exit 3
fi

not_after="$(echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')"

if [[ -z "$not_after" ]]; then
  echo "UNKNOWN - could not read certificate for $host:$port"
  exit 3
fi

expiry_epoch="$(date -d "$not_after" +%s 2>/dev/null || true)"
now_epoch="$(date +%s)"

if [[ -z "$expiry_epoch" ]]; then
  echo "UNKNOWN - could not parse certificate date: $not_after"
  exit 3
fi

days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

if (( days_left < 0 )); then
  echo "CRITICAL - certificate for $host:$port expired ${days_left#-} days ago"
  exit 2
fi

if (( days_left <= warning_days )); then
  echo "WARNING - certificate for $host:$port expires in $days_left days ($not_after)"
  exit 1
fi

echo "OK - certificate for $host:$port expires in $days_left days ($not_after)"
exit 0
