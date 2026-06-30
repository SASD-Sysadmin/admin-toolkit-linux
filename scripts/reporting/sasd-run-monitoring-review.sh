#!/usr/bin/env bash
# Path: scripts/reporting/sasd-run-monitoring-review.sh
# Purpose: Run a focused read-only monitoring review collection.
# Date: 2026-06-30
# License: MIT

set -uo pipefail

OUTPUT_DIR=""
CHECK_PATH="/"
DISK_WARNING=80
DISK_CRITICAL=90
INODE_WARNING=80
INODE_CRITICAL=90
CERT_HOST=""
CERT_PORT=443
CERT_WARNING_DAYS=30
SERVICES=()
GENERATED_AT="$(date -Is)"
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)"

usage() {
  cat <<'USAGE'
Usage: sasd-run-monitoring-review.sh [OPTIONS]

Run a focused read-only monitoring review. The collector wraps monitoring-style
checks, records their exit status and keeps going so WARNING/CRITICAL results do
not stop the review.

Options:
  --output DIR              Output directory, default: reports/monitoring-review-<timestamp>
  --path PATH               Path/mount for disk and inode checks, default: /
  --disk-warning PERCENT    Disk warning threshold, default: 80
  --disk-critical PERCENT   Disk critical threshold, default: 90
  --inode-warning PERCENT   Inode warning threshold, default: 80
  --inode-critical PERCENT  Inode critical threshold, default: 90
  --service SERVICE         Add a systemd service check. Can be used multiple times.
  --cert-host HOST          Add a TLS certificate expiry check for HOST.
  --cert-port PORT          TLS certificate port, default: 443
  --cert-warning-days DAYS  Certificate warning threshold, default: 30
  -h, --help                Show this help text

Examples:
  scripts/reporting/sasd-run-monitoring-review.sh --output reports/monitoring-local
  scripts/reporting/sasd-run-monitoring-review.sh --path /var --service cron.service
  scripts/reporting/sasd-run-monitoring-review.sh --cert-host example.org --cert-port 443
USAGE
}

is_uint() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_percent() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 0 && "$1" <= 100 ))
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --path)
      CHECK_PATH="${2:-}"
      shift 2
      ;;
    --disk-warning)
      DISK_WARNING="${2:-}"
      shift 2
      ;;
    --disk-critical)
      DISK_CRITICAL="${2:-}"
      shift 2
      ;;
    --inode-warning)
      INODE_WARNING="${2:-}"
      shift 2
      ;;
    --inode-critical)
      INODE_CRITICAL="${2:-}"
      shift 2
      ;;
    --service)
      SERVICES+=("${2:-}")
      shift 2
      ;;
    --cert-host)
      CERT_HOST="${2:-}"
      shift 2
      ;;
    --cert-port)
      CERT_PORT="${2:-}"
      shift 2
      ;;
    --cert-warning-days)
      CERT_WARNING_DAYS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unsupported argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$CHECK_PATH" ]]; then
  echo "ERROR: --path must not be empty" >&2
  exit 2
fi

if ! is_percent "$DISK_WARNING" || ! is_percent "$DISK_CRITICAL" || (( DISK_WARNING >= DISK_CRITICAL )); then
  echo "ERROR: disk thresholds must be integers with warning < critical" >&2
  exit 2
fi

if ! is_percent "$INODE_WARNING" || ! is_percent "$INODE_CRITICAL" || (( INODE_WARNING >= INODE_CRITICAL )); then
  echo "ERROR: inode thresholds must be integers with warning < critical" >&2
  exit 2
fi

if ! is_uint "$CERT_PORT" || ! is_uint "$CERT_WARNING_DAYS"; then
  echo "ERROR: certificate port and warning days must be unsigned integers" >&2
  exit 2
fi

for service in "${SERVICES[@]}"; do
  if [[ -z "$service" ]]; then
    echo "ERROR: --service must not be empty" >&2
    exit 2
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$REPO_ROOT/reports/monitoring-review-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUTPUT_DIR"
STATUS_FILE="$OUTPUT_DIR/status.tsv"
INDEX_FILE="$OUTPUT_DIR/INDEX.md"
: > "$STATUS_FILE"
printf 'status\tscript\toutput\n' >> "$STATUS_FILE"

status_rows=""

append_status_row() {
  local status="$1"
  local script="$2"
  local output="$3"

  printf '%s\t%s\t%s\n' "$status" "$script" "$output" >> "$STATUS_FILE"
  status_rows+="| ${status} | \`$script\` | [\`$output\`]($output) |"$'\n'
}

run_plugin() {
  local title="$1"
  local output_file="$2"
  local script_rel="$3"
  shift 3

  local script_path="$REPO_ROOT/$script_rel"
  local output_path="$OUTPUT_DIR/$output_file"
  local status=3
  local command_display="$script_rel"
  local arg
  for arg in "$@"; do
    command_display+=" $(printf '%q' "$arg")"
  done

  if [[ ! -x "$script_path" ]]; then
    {
      printf '# %s\n\n' "$title"
      printf -- '- Generated: %s\n' "$(date -Is)"
      printf -- '- Host: %s\n' "$HOSTNAME_SHORT"
      printf -- '- Command: `%s`\n\n' "$command_display"
      printf 'UNKNOWN - script is not executable or missing: %s\n' "$script_rel"
    } > "$output_path"
    append_status_row 3 "$script_rel" "$output_file"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  (cd "$REPO_ROOT" && "$script_path" "$@") > "$tmp" 2>&1
  status=$?

  {
    printf '# %s\n\n' "$title"
    printf -- '- Generated: %s\n' "$(date -Is)"
    printf -- '- Host: %s\n' "$HOSTNAME_SHORT"
    printf -- '- Command: `%s`\n' "$command_display"
    printf -- '- Exit status: `%s`\n\n' "$status"
    printf '> Monitoring-style exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN.\n\n'
    printf '```text\n'
    cat "$tmp"
    printf '\n```\n'
  } > "$output_path"

  rm -f "$tmp"
  append_status_row "$status" "$script_rel" "$output_file"
  return 0
}

run_plugin "SASD Disk Usage Check" "01-disk-usage.md" \
  "scripts/monitoring/check_disk_usage.sh" \
  --path "$CHECK_PATH" --warning "$DISK_WARNING" --critical "$DISK_CRITICAL"

run_plugin "SASD Inode Usage Check" "02-inode-usage.md" \
  "scripts/monitoring/check_inodes.sh" \
  --path "$CHECK_PATH" --warning "$INODE_WARNING" --critical "$INODE_CRITICAL"

run_plugin "SASD Reboot Required Check" "03-reboot-required.md" \
  "scripts/monitoring/check_reboot_required.sh"

service_index=1
for service in "${SERVICES[@]}"; do
  output_file="$(printf '10-service-%02d.md' "$service_index")"
  run_plugin "SASD Service Active Check: $service" "$output_file" \
    "scripts/monitoring/check_service_active.sh" "$service"
  service_index=$((service_index + 1))
done

if [[ -n "$CERT_HOST" ]]; then
  run_plugin "SASD Certificate Expiry Check: $CERT_HOST:$CERT_PORT" "20-certificate-expiry.md" \
    "scripts/monitoring/check_certificate_expiry.sh" "$CERT_HOST" "$CERT_PORT" "$CERT_WARNING_DAYS"
fi

{
  cat <<EOF_INDEX
# SASD Monitoring Review Collection

- Generated: $GENERATED_AT
- Host: $HOSTNAME_SHORT
- Repository root: \`$REPO_ROOT\`
- Output directory: \`$OUTPUT_DIR\`
- Disk/inode path: \`$CHECK_PATH\`
- Disk thresholds: warning=$DISK_WARNING critical=$DISK_CRITICAL
- Inode thresholds: warning=$INODE_WARNING critical=$INODE_CRITICAL

> This collection is read-only. It wraps monitoring-style checks and records
> their exit status for human review. WARNING and CRITICAL results are findings,
> not collector failures.

## Command status

| Status | Script | Output |
| ---: | --- | --- |
${status_rows}
## Suggested review order

1. Review disk and inode checks together; byte exhaustion and inode exhaustion are different failure modes.
2. Review reboot-required status for maintenance planning.
3. Review optional service checks for host-role expectations.
4. Review optional certificate checks only when you intentionally contacted the selected endpoint.

## Notes

- Monitoring-style checks are intentionally small and predictable.
- Exit status 1 or 2 is useful signal, not a shell execution failure.
- Certificate checks contact the configured host and are therefore optional.
- Service checks are optional because this generic repository should not assume a host role.
EOF_INDEX
} > "$INDEX_FILE"

printf 'Report directory: %s\n' "$OUTPUT_DIR"
printf 'Index: %s\n' "$INDEX_FILE"
exit 0
