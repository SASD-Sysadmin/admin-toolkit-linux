#!/usr/bin/env bash
# scripts/backup/sasd-backup-location-report.sh
# Purpose: Read-only review of configured backup locations.
# Project: admin-toolkit-linux
# License: MIT

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
PATHS=()
PATTERN="*"
MAX_FILES=40
MAX_DEPTH=6
ONE_FILE_SYSTEM=1

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Options:
  --path PATH              Backup location to review. Can be used multiple times.
  --pattern GLOB           File pattern to count/list. Default: *
  --max-files N            Limit displayed file entries. Default: 40
  --max-depth N            Limit find traversal depth. Default: 6
  --cross-filesystems      Allow find to cross filesystem boundaries.
  --one-file-system        Keep find on one filesystem. Default.
  -h, --help               Show this help.

Environment:
  SASD_BACKUP_REVIEW_PATH  Colon-separated fallback paths when --path is omitted.

Examples:
  ./scripts/backup/sasd-backup-location-report.sh --path /backup
  SASD_BACKUP_REVIEW_PATH=/backup:/mnt/nas ./scripts/backup/sasd-backup-location-report.sh
USAGE
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

add_env_paths() {
  local env_value="${SASD_BACKUP_REVIEW_PATH:-}"
  local item
  if [ -n "$env_value" ]; then
    IFS=':' read -r -a env_paths <<< "$env_value"
    for item in "${env_paths[@]}"; do
      [ -n "$item" ] && PATHS+=("$item")
    done
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      [ "$#" -ge 2 ] || { echo "ERROR: --path requires a value" >&2; exit 2; }
      PATHS+=("$2")
      shift 2
      ;;
    --pattern)
      [ "$#" -ge 2 ] || { echo "ERROR: --pattern requires a value" >&2; exit 2; }
      PATTERN="$2"
      shift 2
      ;;
    --max-files)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-files requires a value" >&2; exit 2; }
      is_uint "$2" || { echo "ERROR: --max-files must be a non-negative integer" >&2; exit 2; }
      MAX_FILES="$2"
      shift 2
      ;;
    --max-depth)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-depth requires a value" >&2; exit 2; }
      is_uint "$2" || { echo "ERROR: --max-depth must be a non-negative integer" >&2; exit 2; }
      MAX_DEPTH="$2"
      shift 2
      ;;
    --cross-filesystems)
      ONE_FILE_SYSTEM=0
      shift
      ;;
    --one-file-system)
      ONE_FILE_SYSTEM=1
      shift
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

if [ "${#PATHS[@]}" -eq 0 ]; then
  add_env_paths
fi

HOSTNAME_VALUE="$(hostname 2>/dev/null || printf 'unknown')"
GENERATED_AT="$(date -Iseconds 2>/dev/null || date)"
EUID_VALUE="$(id -u 2>/dev/null || printf 'unknown')"
USER_VALUE="$(id -un 2>/dev/null || printf 'unknown')"
PRIVILEGE="non-root"
[ "$EUID_VALUE" = "0" ] && PRIVILEGE="root"

printf '# SASD Backup Location Report\n\n'
printf -- '- Generated: %s\n' "$GENERATED_AT"
printf -- '- Host: %s\n' "$HOSTNAME_VALUE"
printf -- '- User: %s\n' "$USER_VALUE"
printf -- '- Effective UID: %s\n' "$EUID_VALUE"
printf -- '- Privilege: %s\n' "$PRIVILEGE"
printf -- '- Pattern: `%s`\n' "$PATTERN"
printf -- '- Max files shown per location: %s\n' "$MAX_FILES"
printf -- '- Max depth: %s\n' "$MAX_DEPTH"
printf -- '- One filesystem: %s\n\n' "$([ "$ONE_FILE_SYSTEM" -eq 1 ] && printf 'yes' || printf 'no')"

cat <<'NOTE'
> Read-only report. This script does not mount, unmount, copy, delete, rotate,
> verify, repair or restore backups. It only reviews visible filesystem metadata.
NOTE
printf '\n'

if [ "${#PATHS[@]}" -eq 0 ]; then
  cat <<'NOPATH'
## Result

INFO: no backup location configured.

Provide one or more locations with `--path PATH` or the colon-separated
`SASD_BACKUP_REVIEW_PATH` environment variable.
NOPATH
  exit 0
fi

find_opts=()
[ "$ONE_FILE_SYSTEM" -eq 1 ] && find_opts+=("-xdev")

printf '## Location summary\n\n'
printf '| Path | State | Owner | Group | Mode | Size hint | Files matching pattern | Newest visible match |\n'
printf '| --- | --- | --- | --- | ---: | ---: | ---: | --- |\n'

for location in "${PATHS[@]}"; do
  state="missing"
  owner="-"
  group="-"
  mode="-"
  size_hint="-"
  count="-"
  newest="-"

  if [ -e "$location" ]; then
    state="exists"
    owner="$(stat -c '%U' "$location" 2>/dev/null || printf '?')"
    group="$(stat -c '%G' "$location" 2>/dev/null || printf '?')"
    mode="$(stat -c '%a' "$location" 2>/dev/null || printf '?')"
    size_hint="$(du -sh "$location" 2>/dev/null | awk '{print $1}' || printf '?')"
    count="$(find "$location" "${find_opts[@]}" -maxdepth "$MAX_DEPTH" -type f -name "$PATTERN" 2>/dev/null | wc -l | tr -d ' ')"
    newest="$(find "$location" "${find_opts[@]}" -maxdepth "$MAX_DEPTH" -type f -name "$PATTERN" -printf '%T+ %p\n' 2>/dev/null | sort -r | head -n 1 | sed 's/|/\\|/g')"
    [ -z "$newest" ] && newest="none visible"
  fi

  printf '| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
    "$location" "$state" "$owner" "$group" "$mode" "$size_hint" "$count" "$newest"
done

printf '\n## Mount and filesystem context\n\n'
for location in "${PATHS[@]}"; do
  printf '### `%s`\n\n' "$location"
  if [ ! -e "$location" ]; then
    printf 'MISSING: path does not exist.\n\n'
    continue
  fi

  printf '```text\n'
  if command -v findmnt >/dev/null 2>&1; then
    findmnt -T "$location" 2>/dev/null || printf 'findmnt returned no result.\n'
  else
    df -hP "$location" 2>/dev/null || printf 'df returned no result.\n'
  fi
  printf '```\n\n'
done

printf '## Newest visible matching files\n\n'
for location in "${PATHS[@]}"; do
  printf '### `%s`\n\n' "$location"
  if [ ! -e "$location" ]; then
    printf 'MISSING: path does not exist.\n\n'
    continue
  fi

  tmp_output="$(mktemp)"
  tmp_err="$(mktemp)"
  if find "$location" "${find_opts[@]}" -maxdepth "$MAX_DEPTH" -type f -name "$PATTERN" -printf '%T+\t%s\t%u\t%g\t%m\t%p\n' >"$tmp_output" 2>"$tmp_err"; then
    :
  else
    printf 'INFO: find reported warnings or permission issues.\n\n'
  fi

  if [ -s "$tmp_output" ]; then
    printf '| Modified | Size bytes | Owner | Group | Mode | Path |\n'
    printf '| --- | ---: | --- | --- | ---: | --- |\n'
    sort -r "$tmp_output" | head -n "$MAX_FILES" | while IFS=$'\t' read -r mtime size owner group mode path; do
      printf '| `%s` | %s | `%s` | `%s` | `%s` | `%s` |\n' "$mtime" "$size" "$owner" "$group" "$mode" "${path//|/\\|}"
    done
    printf '\n'
  else
    printf 'INFO: no matching files visible.\n\n'
  fi

  if [ -s "$tmp_err" ]; then
    printf '#### Scan warnings\n\n```text\n'
    sed -n '1,80p' "$tmp_err"
    printf '```\n\n'
  fi

  rm -f "$tmp_output" "$tmp_err"
done

exit 0
