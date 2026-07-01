#!/usr/bin/env bash
# Path: scripts/reporting/sasd-run-profile-review.sh
# Purpose: Run a role-profile based read-only review collection.
# Date: 2026-06-30
# License: MIT
#
# This collector is an overlay around existing read-only reports. It does not
# configure services, create users, create backups, mount filesystems or modify
# monitored files. Selected host roles define expectations for review.

set -uo pipefail

VERSION="0.1.0"
PROFILE="generic"
OUTPUT_DIR=""
SINCE="today"
MAX_LINES="100"
LIST_PROFILES=false
RUN_HOST_OVERRIDE=""
RUN_MONITORING_OVERRIDE=""
RUN_LOGGING_OVERRIDE=""
RUN_FIM_OVERRIDE=""
RUN_BACKUP_OVERRIDE=""
RUN_DATABASE_OVERRIDE=""
GENERATED_AT="$(date -Is)"
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)"

usage() {
  cat <<'USAGE'
Usage: sasd-run-profile-review.sh [OPTIONS]

Run a read-only review collection based on a host role profile. Profiles define
which existing collectors/checks are relevant for a role such as generic,
workstation, web-server, database-server or backup-host.

Options:
  --profile NAME|FILE       Profile name below profiles/ or explicit profile file
                            (default: generic)
  --output DIR              Output directory, default: reports/profile-review-<profile>-<timestamp>
  --since VALUE             Logging review time range, default: today
  --max-lines N             Long-section limit passed to host inventory, default: 100
  --list-profiles           List available profiles and exit
  --no-host-inventory       Skip host inventory collector
  --no-monitoring           Skip monitoring collector
  --no-logging              Skip logging collector
  --no-fim                  Skip FIM review collector
  --no-backup-review        Skip backup review collector
  --no-database-inventory   Skip database inventory scripts
  -h, --help                Show this help text
  --version                 Print version

Examples:
  scripts/reporting/sasd-run-profile-review.sh --profile generic --output reports/profile-generic
  scripts/reporting/sasd-run-profile-review.sh --profile database-server --output reports/profile-db
  scripts/reporting/sasd-run-profile-review.sh --profile profiles/web-server.conf

Notes:
  Role profiles express expectations. A CRITICAL/WARNING/UNKNOWN check result is
  a finding for review, not proof of compromise and not automatically a collector
  failure.
USAGE
}

is_true() {
  case "${1,,}" in
    true|yes|1|on) return 0 ;;
    *) return 1 ;;
  esac
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

safe_name() {
  local value="$1"
  value="${value//\//_}"
  value="${value// /_}"
  value="${value//[^A-Za-z0-9._-]/_}"
  printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --since)
      SINCE="${2:-}"
      shift 2
      ;;
    --max-lines)
      MAX_LINES="${2:-}"
      shift 2
      ;;
    --list-profiles)
      LIST_PROFILES=true
      shift
      ;;
    --no-host-inventory)
      RUN_HOST_OVERRIDE="false"
      shift
      ;;
    --no-monitoring)
      RUN_MONITORING_OVERRIDE="false"
      shift
      ;;
    --no-logging)
      RUN_LOGGING_OVERRIDE="false"
      shift
      ;;
    --no-fim)
      RUN_FIM_OVERRIDE="false"
      shift
      ;;
    --no-backup-review)
      RUN_BACKUP_OVERRIDE="false"
      shift
      ;;
    --no-database-inventory)
      RUN_DATABASE_OVERRIDE="false"
      shift
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

if ! is_uint "$MAX_LINES" || (( MAX_LINES < 1 )); then
  echo "UNKNOWN - --max-lines must be a positive integer" >&2
  exit 3
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROFILE_DIR="$REPO_ROOT/profiles"

if $LIST_PROFILES; then
  if [[ ! -d "$PROFILE_DIR" ]]; then
    echo "No profiles directory found: $PROFILE_DIR" >&2
    exit 3
  fi
  find "$PROFILE_DIR" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' | sed 's/\.conf$//' | sort
  exit 0
fi

if [[ -f "$PROFILE" ]]; then
  PROFILE_FILE="$PROFILE"
elif [[ -f "$PROFILE_DIR/$PROFILE.conf" ]]; then
  PROFILE_FILE="$PROFILE_DIR/$PROFILE.conf"
else
  echo "UNKNOWN - profile not found: $PROFILE" >&2
  echo "Use --list-profiles to show available profiles." >&2
  exit 3
fi

profile_value() {
  local key="$1"
  awk -v key="$key" '
    BEGIN { FS="=" }
    /^[[:space:]]*($|#)/ { next }
    {
      k=$1
      sub(/^[[:space:]]+/, "", k)
      sub(/[[:space:]]+$/, "", k)
      if (k == key) {
        $1=""
        sub(/^=/, "")
        sub(/^[[:space:]]+/, "")
        sub(/[[:space:]]+$/, "")
        print
        exit
      }
    }
  ' "$PROFILE_FILE"
}

split_pipe() {
  local value="$1"
  local -n target_ref="$2"
  target_ref=()
  [[ -z "$value" ]] && return 0
  local old_ifs="$IFS"
  IFS='|'
  read -r -a target_ref <<< "$value"
  IFS="$old_ifs"
}

PROFILE_ID="$(profile_value PROFILE_ID)"
PROFILE_NAME="$(profile_value PROFILE_NAME)"
PROFILE_DESCRIPTION="$(profile_value PROFILE_DESCRIPTION)"
RUN_HOST_INVENTORY="$(profile_value RUN_HOST_INVENTORY)"
RUN_MONITORING="$(profile_value RUN_MONITORING)"
RUN_LOGGING="$(profile_value RUN_LOGGING)"
RUN_FIM="$(profile_value RUN_FIM)"
RUN_BACKUP_REVIEW="$(profile_value RUN_BACKUP_REVIEW)"
RUN_DATABASE_INVENTORY="$(profile_value RUN_DATABASE_INVENTORY)"
DISK_PATHS_RAW="$(profile_value DISK_PATHS)"
EXPECTED_SERVICES_RAW="$(profile_value EXPECTED_SERVICES)"
FIM_PATHS_RAW="$(profile_value FIM_PATHS)"
BACKUP_PATHS_RAW="$(profile_value BACKUP_PATHS)"
PROFILE_NOTES="$(profile_value NOTES)"

[[ -n "$RUN_HOST_OVERRIDE" ]] && RUN_HOST_INVENTORY="$RUN_HOST_OVERRIDE"
[[ -n "$RUN_MONITORING_OVERRIDE" ]] && RUN_MONITORING="$RUN_MONITORING_OVERRIDE"
[[ -n "$RUN_LOGGING_OVERRIDE" ]] && RUN_LOGGING="$RUN_LOGGING_OVERRIDE"
[[ -n "$RUN_FIM_OVERRIDE" ]] && RUN_FIM="$RUN_FIM_OVERRIDE"
[[ -n "$RUN_BACKUP_OVERRIDE" ]] && RUN_BACKUP_REVIEW="$RUN_BACKUP_OVERRIDE"
[[ -n "$RUN_DATABASE_OVERRIDE" ]] && RUN_DATABASE_INVENTORY="$RUN_DATABASE_OVERRIDE"

if [[ -z "$PROFILE_ID" ]] || [[ ! "$PROFILE_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "UNKNOWN - profile has invalid PROFILE_ID: $PROFILE_ID" >&2
  exit 3
fi

split_pipe "$DISK_PATHS_RAW" DISK_PATHS
split_pipe "$EXPECTED_SERVICES_RAW" EXPECTED_SERVICES
split_pipe "$FIM_PATHS_RAW" FIM_PATHS
split_pipe "$BACKUP_PATHS_RAW" BACKUP_PATHS

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$REPO_ROOT/reports/profile-review-${PROFILE_ID}-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUTPUT_DIR"
STATUS_FILE="$OUTPUT_DIR/status.tsv"
INDEX_FILE="$OUTPUT_DIR/INDEX.md"
PROFILE_SUMMARY="$OUTPUT_DIR/profile-summary.md"
: > "$STATUS_FILE"
printf 'status\tscript\toutput\n' > "$STATUS_FILE"

STATUS_ROWS=""
COMMAND_COUNT=0

append_status() {
  local status="$1"
  local script="$2"
  local output="$3"
  printf '%s\t%s\t%s\n' "$status" "$script" "$output" >> "$STATUS_FILE"
  STATUS_ROWS+="| $status | \`$script\` | [$output]($output) |"$'\n'
}

run_command() {
  local script_label="$1"
  local output_name="$2"
  shift 2
  local output_path="$OUTPUT_DIR/$output_name"
  "$@" > "$output_path" 2>&1
  local status=$?
  append_status "$status" "$script_label" "$output_name"
  COMMAND_COUNT=$((COMMAND_COUNT + 1))
  return 0
}

filter_existing_paths() {
  local -n input_ref="$1"
  local -n existing_ref="$2"
  local -n missing_ref="$3"
  existing_ref=()
  missing_ref=()
  local item
  for item in "${input_ref[@]}"; do
    [[ -z "$item" ]] && continue
    if [[ -e "$item" ]]; then
      existing_ref+=("$item")
    else
      missing_ref+=("$item")
    fi
  done
}

FIM_EXISTING=()
FIM_MISSING=()
BACKUP_EXISTING=()
BACKUP_MISSING=()
filter_existing_paths FIM_PATHS FIM_EXISTING FIM_MISSING
filter_existing_paths BACKUP_PATHS BACKUP_EXISTING BACKUP_MISSING

write_list_md() {
  local title="$1"
  shift
  printf '### %s\n\n' "$title"
  if [[ $# -eq 0 ]]; then
    printf 'None configured.\n\n'
    return 0
  fi
  local item
  for item in "$@"; do
    printf -- '- `%s`\n' "$item"
  done
  printf '\n'
}

{
  echo "# SASD Role Profile Summary"
  echo
  echo "- Generated: $GENERATED_AT"
  echo "- Host: $HOSTNAME_SHORT"
  echo "- Repository root: \`$REPO_ROOT\`"
  echo "- Profile file: \`$PROFILE_FILE\`"
  echo "- Profile ID: \`$PROFILE_ID\`"
  echo "- Profile name: ${PROFILE_NAME:-unknown}"
  echo "- Description: ${PROFILE_DESCRIPTION:-not provided}"
  echo
  echo "> Read-only profile overlay. This file records expectations and selected"
  echo "> collectors. It does not configure the host."
  echo
  echo "## Collector switches"
  echo
  echo "| Area | Enabled |"
  echo "| --- | --- |"
  echo "| Host inventory | \`$RUN_HOST_INVENTORY\` |"
  echo "| Monitoring | \`$RUN_MONITORING\` |"
  echo "| Logging | \`$RUN_LOGGING\` |"
  echo "| FIM | \`$RUN_FIM\` |"
  echo "| Backup review | \`$RUN_BACKUP_REVIEW\` |"
  echo "| Database inventory | \`$RUN_DATABASE_INVENTORY\` |"
  echo
  write_list_md "Disk/inode paths" "${DISK_PATHS[@]}"
  write_list_md "Expected services" "${EXPECTED_SERVICES[@]}"
  write_list_md "Configured FIM paths" "${FIM_PATHS[@]}"
  write_list_md "Existing FIM paths used" "${FIM_EXISTING[@]}"
  write_list_md "Missing FIM paths skipped" "${FIM_MISSING[@]}"
  write_list_md "Configured backup paths" "${BACKUP_PATHS[@]}"
  write_list_md "Existing backup paths used" "${BACKUP_EXISTING[@]}"
  write_list_md "Missing backup paths" "${BACKUP_MISSING[@]}"
  echo "## Notes"
  echo
  echo "${PROFILE_NOTES:-No profile notes provided.}"
} > "$PROFILE_SUMMARY"

append_status "0" "profile-summary" "profile-summary.md"

HOST_COLLECTOR="$REPO_ROOT/scripts/reporting/sasd-run-host-inventory.sh"
MONITORING_COLLECTOR="$REPO_ROOT/scripts/reporting/sasd-run-monitoring-review.sh"
LOGGING_COLLECTOR="$REPO_ROOT/scripts/reporting/sasd-run-logging-review.sh"
FIM_COLLECTOR="$REPO_ROOT/scripts/reporting/sasd-run-fim-review.sh"
BACKUP_COLLECTOR="$REPO_ROOT/scripts/reporting/sasd-run-backup-review.sh"
MARIADB_INVENTORY="$REPO_ROOT/scripts/database/sasd-mariadb-inventory.sh"
POSTGRESQL_INVENTORY="$REPO_ROOT/scripts/database/sasd-postgresql-inventory.sh"

if is_true "$RUN_HOST_INVENTORY" && [[ -x "$HOST_COLLECTOR" ]]; then
  run_command "scripts/reporting/sasd-run-host-inventory.sh" "10-host-inventory.log" \
    "$HOST_COLLECTOR" --output "$OUTPUT_DIR/10-host-inventory" --max-lines "$MAX_LINES"
fi

if is_true "$RUN_MONITORING" && [[ -x "$MONITORING_COLLECTOR" ]]; then
  MONITORING_PATH="/"
  if [[ ${#DISK_PATHS[@]} -gt 0 ]] && [[ -n "${DISK_PATHS[0]}" ]]; then
    MONITORING_PATH="${DISK_PATHS[0]}"
  fi
  MONITORING_CMD=("$MONITORING_COLLECTOR" --path "$MONITORING_PATH" --output "$OUTPUT_DIR/20-monitoring")
  for service in "${EXPECTED_SERVICES[@]}"; do
    [[ -z "$service" ]] && continue
    MONITORING_CMD+=(--service "$service")
  done
  run_command "scripts/reporting/sasd-run-monitoring-review.sh" "20-monitoring.log" "${MONITORING_CMD[@]}"
fi

if is_true "$RUN_LOGGING" && [[ -x "$LOGGING_COLLECTOR" ]]; then
  run_command "scripts/reporting/sasd-run-logging-review.sh" "30-logging.log" \
    "$LOGGING_COLLECTOR" --since "$SINCE" --output "$OUTPUT_DIR/30-logging"
fi

if is_true "$RUN_FIM" && [[ -x "$FIM_COLLECTOR" ]] && [[ ${#FIM_EXISTING[@]} -gt 0 ]]; then
  FIM_CMD=("$FIM_COLLECTOR" --output "$OUTPUT_DIR/40-fim")
  for path in "${FIM_EXISTING[@]}"; do
    FIM_CMD+=(--path "$path")
  done
  run_command "scripts/reporting/sasd-run-fim-review.sh" "40-fim.log" "${FIM_CMD[@]}"
fi

if is_true "$RUN_BACKUP_REVIEW" && [[ -x "$BACKUP_COLLECTOR" ]] && [[ ${#BACKUP_EXISTING[@]} -gt 0 ]]; then
  run_command "scripts/reporting/sasd-run-backup-review.sh" "50-backup.log" \
    "$BACKUP_COLLECTOR" --path "${BACKUP_EXISTING[0]}" --output "$OUTPUT_DIR/50-backup"
fi

if is_true "$RUN_DATABASE_INVENTORY"; then
  if [[ -x "$MARIADB_INVENTORY" ]]; then
    run_command "scripts/database/sasd-mariadb-inventory.sh" "60-mariadb-inventory.md" "$MARIADB_INVENTORY"
  fi
  if [[ -x "$POSTGRESQL_INVENTORY" ]]; then
    run_command "scripts/database/sasd-postgresql-inventory.sh" "61-postgresql-inventory.md" "$POSTGRESQL_INVENTORY"
  fi
fi

{
  echo "# SASD Role Profile Review Collection"
  echo
  echo "- Generated: $GENERATED_AT"
  echo "- Host: $HOSTNAME_SHORT"
  echo "- Repository root: \`$REPO_ROOT\`"
  echo "- Output directory: \`$OUTPUT_DIR\`"
  echo "- Profile: \`$PROFILE_ID\`"
  echo "- Profile file: \`$PROFILE_FILE\`"
  echo "- Commands recorded: $COMMAND_COUNT"
  echo
  echo "> This collection is read-only. Role profiles express review expectations;"
  echo "> they do not apply configuration, install packages or create backups."
  echo
  echo "## Command status"
  echo
  echo "| Status | Script | Output |"
  echo "| ---: | --- | --- |"
  printf '%s' "$STATUS_ROWS"
  echo
  echo "## Suggested review order"
  echo
  echo "1. Open \`profile-summary.md\` to confirm the selected host role."
  echo "2. Review host inventory before treating findings as role-specific problems."
  echo "3. Review monitoring status for disk, inode, reboot and expected services."
  echo "4. Review logging, FIM, backup and database outputs only where enabled by the profile."
  echo "5. Treat missing expected paths/services as review items, not automatic remediation instructions."
  echo
  echo "## Notes"
  echo
  echo "- This collector intentionally reuses existing read-only scripts."
  echo "- Profiles are conservative defaults and should be adjusted for real environments."
  echo "- Use elevated privileges only when needed for completeness; scripts remain read-only."
  echo "- Generated reports may contain hostnames, paths, usernames, service names and hashes."
} > "$INDEX_FILE"

echo "Report directory: $OUTPUT_DIR"
echo "Index: $INDEX_FILE"
