#!/usr/bin/env bash
# Path: scripts/monitoring/check_certificate_expiry.sh
# Purpose: Monitoring plugin: check TLS certificate expiration.
# Date: 2026-06-29
# License: MIT

set -uo pipefail

VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: check_certificate_expiry.sh HOST [PORT] [WARNING_DAYS]

Check the remote TLS certificate expiration date.
Default PORT: 443
Default WARNING_DAYS: 30
Exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--version" ]]; then echo "$VERSION"; exit 0; fi

host="${1:-}"
port="${2:-443}"
warning_days="${3:-30}"

if [[ -z "$host" ]]; then
  echo "UNKNOWN - host missing"
  exit 3
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "UNKNOWN - openssl not available"
  exit 3
fi

if ! [[ "$warning_days" =~ ^[0-9]+$ ]]; then
  echo "UNKNOWN - WARNING_DAYS must be numeric"
  exit 3
fi

end_date="$(echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null \
  | openssl x509 -noout -enddate 2>/dev/null \
  | sed 's/^notAfter=//')"

if [[ -z "$end_date" ]]; then
  echo "CRITICAL - could not read certificate from $host:$port"
  exit 2
fi

if ! end_epoch="$(date -d "$end_date" +%s 2>/dev/null)"; then
  echo "UNKNOWN - could not parse certificate date: $end_date"
  exit 3
fi
now_epoch="$(date +%s)"
remaining_days=$(( (end_epoch - now_epoch) / 86400 ))

if (( remaining_days < 0 )); then
  echo "CRITICAL - certificate for $host:$port expired ${remaining_days#-} days ago ($end_date)"
  exit 2
fi

if (( remaining_days <= warning_days )); then
  echo "WARNING - certificate for $host:$port expires in $remaining_days days ($end_date)"
  exit 1
fi

echo "OK - certificate for $host:$port expires in $remaining_days days ($end_date)"
exit 0
