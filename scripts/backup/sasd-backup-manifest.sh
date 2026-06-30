#!/usr/bin/env bash
# scripts/backup/sasd-backup-manifest.sh
# Purpose: Create a read-only metadata manifest for visible backup files.
# Project: admin-toolkit-linux
# License: MIT

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
PATHS=()
PATTERN="*"
MAX_FILES=500
MAX_DEPTH=6
ONE_FILE_SYSTEM=1
INCLUDE_HASH=0
FORMAT="tsv"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Options:
  --path PATH              Backup location to include. Can be used multiple times.
  --pattern GLOB           File pattern. Default: *
  --max-files N            Maximum manifest rows. Default: 500
  --max-depth N            Limit find traversal depth. Default: 6
  --hash                   Include SHA-256 hashes. Can be slow on large backups.
  --format tsv|markdown    Output format. Default: tsv
  --cross-filesystems      Allow find to cross filesystem boundaries.
  --one-file-system        Keep find on one filesystem. Default.
  -h, --help               Show this help.

Environment:
  SASD_BACKUP_REVIEW_PATH  Colon-separated fallback paths when --path is omitted.

Examples:
  ./scripts/backup/sasd-backup-manifest.sh --path /backup --pattern '*.tar.gz'
  ./scripts/backup/sasd-backup-manifest.sh --path /backup --hash --max-files 20
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
    --hash)
      INCLUDE_HASH=1
      shift
      ;;
    --format)
      [ "$#" -ge 2 ] || { echo "ERROR: --format requires a value" >&2; exit 2; }
      case "$2" in
        tsv|markdown) FORMAT="$2" ;;
        *) echo "ERROR: --format must be tsv or markdown" >&2; exit 2 ;;
      esac
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
find_opts=()
[ "$ONE_FILE_SYSTEM" -eq 1 ] && find_opts+=("-xdev")

if [ "${#PATHS[@]}" -eq 0 ]; then
  if [ "$FORMAT" = "markdown" ]; then
    cat <<NOPATH
# SASD Backup Manifest

- Generated: $GENERATED_AT
- Host: $HOSTNAME_VALUE
- User: $USER_VALUE
- Effective UID: $EUID_VALUE
- Path: not configured

INFO: no backup location configured. Provide `--path PATH` or `SASD_BACKUP_REVIEW_PATH`.
NOPATH
  else
    printf 'generated_at\thost\tpath\tstatus\n'
    printf '%s\t%s\t%s\t%s\n' "$GENERATED_AT" "$HOSTNAME_VALUE" "not configured" "no backup location configured"
  fi
  exit 0
fi

if [ "$FORMAT" = "markdown" ]; then
  printf '# SASD Backup Manifest\n\n'
  printf -- '- Generated: %s\n' "$GENERATED_AT"
  printf -- '- Host: %s\n' "$HOSTNAME_VALUE"
  printf -- '- User: %s\n' "$USER_VALUE"
  printf -- '- Effective UID: %s\n' "$EUID_VALUE"
  printf -- '- Pattern: `%s`\n' "$PATTERN"
  printf -- '- Max files: %s\n' "$MAX_FILES"
  printf -- '- Include hashes: %s\n\n' "$([ "$INCLUDE_HASH" -eq 1 ] && printf 'yes' || printf 'no')"
  printf '> Read-only manifest. Hashing is optional and can be expensive on large backup files.\n\n'
  if [ "$INCLUDE_HASH" -eq 1 ]; then
    printf '| Modified | Size bytes | SHA-256 | Owner | Group | Mode | Path |\n'
    printf '| --- | ---: | --- | --- | --- | ---: | --- |\n'
  else
    printf '| Modified | Size bytes | Owner | Group | Mode | Path |\n'
    printf '| --- | ---: | --- | --- | ---: | --- |\n'
  fi
else
  if [ "$INCLUDE_HASH" -eq 1 ]; then
    printf 'modified\tsize_bytes\tsha256\towner\tgroup\tmode\tpath\n'
  else
    printf 'modified\tsize_bytes\towner\tgroup\tmode\tpath\n'
  fi
fi

rows=0
for location in "${PATHS[@]}"; do
  [ -e "$location" ] || continue
  while IFS=$'\t' read -r mtime size owner group mode path; do
    [ -n "${path:-}" ] || continue
    hash_value=""
    if [ "$INCLUDE_HASH" -eq 1 ]; then
      if command -v sha256sum >/dev/null 2>&1; then
        hash_value="$(sha256sum -- "$path" 2>/dev/null | awk '{print $1}')"
        [ -z "$hash_value" ] && hash_value="unreadable"
      else
        hash_value="sha256sum-not-found"
      fi
    fi

    if [ "$FORMAT" = "markdown" ]; then
      escaped_path="${path//|/\\|}"
      if [ "$INCLUDE_HASH" -eq 1 ]; then
        printf '| `%s` | %s | `%s` | `%s` | `%s` | `%s` | `%s` |\n' "$mtime" "$size" "$hash_value" "$owner" "$group" "$mode" "$escaped_path"
      else
        printf '| `%s` | %s | `%s` | `%s` | `%s` | `%s` |\n' "$mtime" "$size" "$owner" "$group" "$mode" "$escaped_path"
      fi
    else
      if [ "$INCLUDE_HASH" -eq 1 ]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$mtime" "$size" "$hash_value" "$owner" "$group" "$mode" "$path"
      else
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$mtime" "$size" "$owner" "$group" "$mode" "$path"
      fi
    fi

    rows=$((rows + 1))
    [ "$rows" -ge "$MAX_FILES" ] && break 2
  done < <(find "$location" "${find_opts[@]}" -maxdepth "$MAX_DEPTH" -type f -name "$PATTERN" -printf '%T+\t%s\t%u\t%g\t%m\t%p\n' 2>/dev/null | sort -r)
done

if [ "$rows" -eq 0 ] && [ "$FORMAT" = "markdown" ]; then
  printf '\nINFO: no matching backup files visible.\n'
fi

exit 0
