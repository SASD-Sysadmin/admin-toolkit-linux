#!/usr/bin/env bash
# scripts/reporting/sasd-run-backup-review.sh
# Purpose: Run a focused read-only backup/restore validation review.
# Project: admin-toolkit-linux
# License: MIT

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
OUTPUT_DIR=""
BACKUP_PATHS=()
PATTERN="*"
MAX_AGE_DAYS="7"
MIN_COUNT="1"
MANIFEST_MAX_FILES="200"
SERVICE="not specified"
RESTORE_TARGET="isolated test system"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Options:
  --output DIR             Output directory. Default: reports/backup-review-TIMESTAMP
  --path PATH              Backup location to review. Can be used multiple times.
  --pattern GLOB           Backup file pattern. Default: *
  --max-age-days N         Maximum expected age for age check. Default: 7
  --min-count N            Minimum expected file count for age check. Default: 1
  --manifest-max-files N   Maximum manifest rows. Default: 200
  --service NAME           Service/application name for restore drill plan.
  --target TEXT            Restore target description. Default: isolated test system
  -h, --help               Show this help.

Environment:
  SASD_BACKUP_REVIEW_PATH  Colon-separated fallback paths when --path is omitted.

Examples:
  ./scripts/reporting/sasd-run-backup-review.sh --path /backup --pattern '*.tar.gz'
  ./scripts/reporting/sasd-run-backup-review.sh --service mariadb --target 'temporary VM'
USAGE
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || { echo "ERROR: --output requires a value" >&2; exit 2; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --path)
      [ "$#" -ge 2 ] || { echo "ERROR: --path requires a value" >&2; exit 2; }
      BACKUP_PATHS+=("$2")
      shift 2
      ;;
    --pattern)
      [ "$#" -ge 2 ] || { echo "ERROR: --pattern requires a value" >&2; exit 2; }
      PATTERN="$2"
      shift 2
      ;;
    --max-age-days)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-age-days requires a value" >&2; exit 2; }
      is_uint "$2" || { echo "ERROR: --max-age-days must be a non-negative integer" >&2; exit 2; }
      MAX_AGE_DAYS="$2"
      shift 2
      ;;
    --min-count)
      [ "$#" -ge 2 ] || { echo "ERROR: --min-count requires a value" >&2; exit 2; }
      is_uint "$2" || { echo "ERROR: --min-count must be a non-negative integer" >&2; exit 2; }
      MIN_COUNT="$2"
      shift 2
      ;;
    --manifest-max-files)
      [ "$#" -ge 2 ] || { echo "ERROR: --manifest-max-files requires a value" >&2; exit 2; }
      is_uint "$2" || { echo "ERROR: --manifest-max-files must be a non-negative integer" >&2; exit 2; }
      MANIFEST_MAX_FILES="$2"
      shift 2
      ;;
    --service)
      [ "$#" -ge 2 ] || { echo "ERROR: --service requires a value" >&2; exit 2; }
      SERVICE="$2"
      shift 2
      ;;
    --target)
      [ "$#" -ge 2 ] || { echo "ERROR: --target requires a value" >&2; exit 2; }
      RESTORE_TARGET="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 2

HOSTNAME_VALUE="$(hostname 2>/dev/null || printf 'unknown')"
GENERATED_AT="$(date -Iseconds 2>/dev/null || date)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null || printf 'unknown-time')"
[ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="reports/backup-review-$TIMESTAMP"
mkdir -p "$OUTPUT_DIR" || exit 2
STATUS_FILE="$OUTPUT_DIR/status.tsv"
INDEX_FILE="$OUTPUT_DIR/INDEX.md"
printf 'status\tscript\toutput\n' > "$STATUS_FILE"

path_args=()
backup_path_label="not configured"
if [ "${#BACKUP_PATHS[@]}" -gt 0 ]; then
  backup_path_label=""
  for path in "${BACKUP_PATHS[@]}"; do
    path_args+=("--path" "$path")
    if [ -z "$backup_path_label" ]; then
      backup_path_label="$path"
    else
      backup_path_label="$backup_path_label:$path"
    fi
  done
elif [ -n "${SASD_BACKUP_REVIEW_PATH:-}" ]; then
  backup_path_label="$SASD_BACKUP_REVIEW_PATH"
fi

run_report() {
  local output_file="$1"
  shift
  local script="$1"
  shift
  local status

  if [ ! -x "$script" ]; then
    {
      printf 'ERROR: script is missing or not executable: %s\n' "$script"
    } > "$OUTPUT_DIR/$output_file"
    status=2
  else
    "$script" "$@" > "$OUTPUT_DIR/$output_file" 2>&1
    status=$?
  fi

  printf '%s\t%s\t%s\n' "$status" "$script" "$output_file" >> "$STATUS_FILE"
}

run_report "01-backup-age-check.md" "scripts/backup/sasd-backup-age-check.sh" "${path_args[@]}" --pattern "$PATTERN" --max-age-days "$MAX_AGE_DAYS" --min-count "$MIN_COUNT"
run_report "02-backup-location-report.md" "scripts/backup/sasd-backup-location-report.sh" "${path_args[@]}" --pattern "$PATTERN" --max-files 80
run_report "03-backup-manifest.tsv" "scripts/backup/sasd-backup-manifest.sh" "${path_args[@]}" --pattern "$PATTERN" --max-files "$MANIFEST_MAX_FILES" --format tsv
run_report "10-restore-drill-plan.md" "scripts/backup/sasd-restore-drill-plan.sh" --system "$HOSTNAME_VALUE" --service "$SERVICE" --backup-path "$backup_path_label" --target "$RESTORE_TARGET"

{
  printf '# SASD Backup Review Collection\n\n'
  printf -- '- Generated: %s\n' "$GENERATED_AT"
  printf -- '- Host: %s\n' "$HOSTNAME_VALUE"
  printf -- '- Repository root: `%s`\n' "$REPO_ROOT"
  printf -- '- Output directory: `%s`\n' "$OUTPUT_DIR"
  printf -- '- Backup path/reference: `%s`\n' "$backup_path_label"
  printf -- '- Pattern: `%s`\n' "$PATTERN"
  printf -- '- Max age days: %s\n' "$MAX_AGE_DAYS"
  printf -- '- Min count: %s\n\n' "$MIN_COUNT"
  printf '> This collection is read-only. It does not restore, copy, delete, mount,\n'
  printf '> rotate, compress or change backup files. It makes backup and restore\n'
  printf '> testability visible for human review.\n\n'

  printf '## Command status\n\n'
  printf '| Status | Script | Output |\n'
  printf '| ---: | --- | --- |\n'
  tail -n +2 "$STATUS_FILE" | while IFS=$'\t' read -r status script output; do
    printf '| %s | `%s` | [`%s`](%s) |\n' "$status" "$script" "$output" "$output"
  done

  printf '\n## Suggested review order\n\n'
  printf '1. Open `01-backup-age-check.md` to see whether recent files are visible.\n'
  printf '2. Open `02-backup-location-report.md` to review path, mount and newest-file context.\n'
  printf '3. Open `03-backup-manifest.tsv` if a lightweight file manifest is useful.\n'
  printf '4. Use `10-restore-drill-plan.md` to plan a non-production restore validation.\n\n'

  printf '## Notes\n\n'
  printf -- '- A visible backup file is not proof of successful restore.\n'
  printf -- '- Reports can expose paths, hostnames and backup naming conventions. Review before sharing.\n'
  printf -- '- Run as root only when needed for completeness; the scripts remain read-only.\n'
} > "$INDEX_FILE"

printf 'Report directory: %s\n' "$OUTPUT_DIR"
printf 'Index: %s\n' "$INDEX_FILE"

exit 0
