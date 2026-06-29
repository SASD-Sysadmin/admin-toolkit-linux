#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/reporting/sasd-run-readonly-checks.sh
# Project: admin-toolkit-linux
# Purpose: Run a curated set of read-only checks and write report files.
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# This collector only calls scripts that are designed to be read-only. It writes
# output files into a report directory. It does not modify system configuration.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
OUTPUT_DIR=""
INCLUDE_SUMMARY=0

usage() {
  cat <<'USAGE'
Usage:
  sasd-run-readonly-checks.sh [options]

Options:
  --output DIR        Write reports to DIR.
  --include-summary   Also run verbose admin/security summary reports.
  -h, --help          Show this help.

Examples:
  ./scripts/reporting/sasd-run-readonly-checks.sh
  ./scripts/reporting/sasd-run-readonly-checks.sh --output ./reports/dev102-test
  ./scripts/reporting/sasd-run-readonly-checks.sh --include-summary
USAGE
}

log_error() { printf 'ERROR: %s\n' "$*" >&2; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || { log_error "--output requires a value"; exit 2; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --include-summary)
      INCLUDE_SUMMARY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOSTNAME_VALUE="$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
STAMP="$(date +%Y%m%d-%H%M%S)"
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$REPO_ROOT/reports/${HOSTNAME_VALUE}-${STAMP}"
fi

mkdir -p "$OUTPUT_DIR" || { log_error "cannot create output directory: $OUTPUT_DIR"; exit 2; }
STATUS_FILE="$OUTPUT_DIR/status.tsv"
INDEX_FILE="$OUTPUT_DIR/INDEX.md"
: > "$STATUS_FILE"
printf 'status\tscript\toutput\n' > "$STATUS_FILE"

run_report() {
  local output_file="$1"
  local script="$2"
  shift 2
  local rel_script="${script#$REPO_ROOT/}"
  local status

  if [ ! -x "$script" ]; then
    printf '127\t%s\t%s\n' "$rel_script" "$output_file" >> "$STATUS_FILE"
    {
      printf 'ERROR: script not executable or missing: %s\n' "$rel_script"
    } > "$OUTPUT_DIR/$output_file"
    return
  fi

  set +e
  "$script" "$@" > "$OUTPUT_DIR/$output_file" 2>&1
  status=$?
  set -e 2>/dev/null || true
  printf '%s\t%s\t%s\n' "$status" "$rel_script" "$output_file" >> "$STATUS_FILE"
}

# Host documentation
run_report "01-host-inventory.md"             "$REPO_ROOT/scripts/host-doc/sasd-host-inventory.sh"
run_report "02-service-inventory.md"          "$REPO_ROOT/scripts/host-doc/sasd-service-inventory.sh"
run_report "03-package-inventory.md"          "$REPO_ROOT/scripts/host-doc/sasd-package-inventory.sh"

# Filesystem and backup/reliability
run_report "10-disk-usage.md"                 "$REPO_ROOT/scripts/filesystem/sasd-disk-usage-report.sh"
run_report "11-deleted-open-files.md"         "$REPO_ROOT/scripts/filesystem/sasd-deleted-open-files.sh"
run_report "12-backup-age-check.md"           "$REPO_ROOT/scripts/backup/sasd-backup-age-check.sh" --path "$REPO_ROOT" --pattern '*.md' --max-age-days 90

# Configuration and scheduling
run_report "20-sshd-config.md"                "$REPO_ROOT/scripts/config/sasd-sshd-config-report.sh"
run_report "21-sudoers.md"                    "$REPO_ROOT/scripts/config/sasd-sudoers-report.sh"
run_report "22-journald-config.md"            "$REPO_ROOT/scripts/config/sasd-journald-config-report.sh"
run_report "23-logrotate.md"                  "$REPO_ROOT/scripts/config/sasd-logrotate-report.sh"
run_report "24-cron.md"                       "$REPO_ROOT/scripts/config/sasd-cron-report.sh"
run_report "25-systemd-timers.md"             "$REPO_ROOT/scripts/config/sasd-systemd-timers-report.sh"
run_report "26-browser-repos.md"              "$REPO_ROOT/scripts/config/sasd-browser-repo-report.sh"

# Network and security controls
run_report "30-open-ports.md"                 "$REPO_ROOT/scripts/security/sasd-open-ports-audit.sh"
run_report "31-listening-services.md"         "$REPO_ROOT/scripts/network/sasd-listening-services-report.sh"
run_report "32-ssh-baseline.md"               "$REPO_ROOT/scripts/security/sasd-ssh-baseline-check.sh"
run_report "33-system-accounts.md"            "$REPO_ROOT/scripts/security/sasd-system-accounts-audit.sh"
run_report "34-account-baseline.tsv"          "$REPO_ROOT/scripts/accounts/sasd-account-baseline.sh"
run_report "35-suid-sgid.md"                  "$REPO_ROOT/scripts/security/sasd-suid-sgid-audit.sh"
run_report "36-world-writable.md"             "$REPO_ROOT/scripts/security/sasd-world-writable-audit.sh"
run_report "37-sensitive-files.md"            "$REPO_ROOT/scripts/security/sasd-sensitive-files-check.sh"
run_report "38-permission-risk.md"            "$REPO_ROOT/scripts/security/sasd-permission-risk-report.sh"
run_report "39-root-owned-writable.md"        "$REPO_ROOT/scripts/security/sasd-root-owned-writable-report.sh"
run_report "42-firewall-status.md"            "$REPO_ROOT/scripts/security/sasd-firewall-status-report.sh"
run_report "43-auditd-status.md"              "$REPO_ROOT/scripts/security/sasd-auditd-status-report.sh"

# Logs and package state
run_report "40-journal-errors.md"             "$REPO_ROOT/scripts/logging/sasd-journal-errors.sh"
run_report "41-auth-log.md"                   "$REPO_ROOT/scripts/logging/sasd-auth-log-report.sh"
run_report "50-update-status.md"              "$REPO_ROOT/scripts/packages/sasd-update-status-report.sh"
run_report "51-reboot-required.md"            "$REPO_ROOT/scripts/packages/sasd-reboot-required-report.sh"

# Database inventories
run_report "80-mariadb-inventory.md"          "$REPO_ROOT/scripts/database/sasd-mariadb-inventory.sh"
run_report "81-postgresql-inventory.md"       "$REPO_ROOT/scripts/database/sasd-postgresql-inventory.sh"

# Compact findings summary is intentionally included by default. It is compact
# and avoids duplicating large child reports.
run_report "89-findings-summary.md"           "$REPO_ROOT/scripts/reporting/sasd-findings-summary.sh"

# Verbose summaries are useful but can duplicate large amounts of output. Keep
# them opt-in so smoke tests and normal collection remain reviewable.
if [ "$INCLUDE_SUMMARY" -eq 1 ]; then
  run_report "90-admin-summary.md"            "$REPO_ROOT/scripts/reporting/sasd-admin-summary.sh"
  run_report "91-security-summary.md"         "$REPO_ROOT/scripts/reporting/sasd-security-summary.sh"
fi

GENERATED_AT="$(date -Iseconds)"
{
  cat <<HEADER
# SASD Read-only Check Collection

- Generated: $GENERATED_AT
- Host: $HOSTNAME_VALUE
- Repository root: \`$REPO_ROOT\`
- Output directory: \`$OUTPUT_DIR\`

> This collection was generated by read-only toolkit scripts. Review all output
> before sharing it publicly because reports can contain hostnames, usernames,
> package names, IP addresses, paths or other environment details.

## Command status

| Status | Script | Output |
| ---: | --- | --- |
HEADER
  tail -n +2 "$STATUS_FILE" | while IFS=$'\t' read -r status script output; do
    printf '| %s | `%s` | [`%s`](%s) |\n' "$status" "$script" "$output" "$output"
  done
  cat <<'FOOTER'

## Notes

- Exit status 0 usually means OK or informational output.
- Exit status 1 can mean findings were detected by an audit script.
- Exit status 2 or higher usually means an execution problem or missing prerequisite.
- Verbose summary reports are excluded by default to avoid duplicated output. Use `--include-summary` when wanted.
- Review each report before sharing it outside your environment.
FOOTER
} > "$INDEX_FILE"

printf 'Report directory: %s\n' "$OUTPUT_DIR"
printf 'Index: %s\n' "$INDEX_FILE"

exit 0
