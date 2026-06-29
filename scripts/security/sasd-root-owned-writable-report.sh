#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/security/sasd-root-owned-writable-report.sh
# Project: admin-toolkit-linux
# Purpose: Report root-owned files/directories writable by group or everyone.
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# Read-only. This script never changes permissions. It reports candidates for
# review where owner=root but group/other write bits are set.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
MAX_RESULTS=300
FULL_OUTPUT=0
FORMAT="markdown"
ONE_FILE_SYSTEM=1
SEARCH_PATHS=("/etc" "/usr/local" "/opt" "/srv" "/var/www")
EXCLUDES=("/proc" "/sys" "/dev" "/run" "/tmp" "/var/tmp" "/mnt" "/media")

usage() {
  cat <<'USAGE'
Usage:
  sasd-root-owned-writable-report.sh [options]

Options:
  --path PATH              Add a search path. First --path replaces defaults.
  --exclude PATH           Exclude a path prefix. Can be used multiple times.
  --max-results N          Limit displayed findings. Default: 300.
  --full                   Show all findings.
  --format markdown|text|tsv
                           Output format. Default: markdown.
  --cross-filesystems      Do not use find -xdev.
  --one-file-system        Use find -xdev. Default.
  -h, --help               Show this help.

Examples:
  ./scripts/security/sasd-root-owned-writable-report.sh
  ./scripts/security/sasd-root-owned-writable-report.sh --path /etc --path /opt
  ./scripts/security/sasd-root-owned-writable-report.sh --format tsv
USAGE
}

log_error() { printf 'ERROR: %s\n' "$*" >&2; }
is_uint() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
md_escape() { printf '%s' "$1" | sed 's/|/\\|/g'; }

first_path_option=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      [ "$#" -ge 2 ] || { log_error "--path requires a value"; exit 2; }
      if [ "$first_path_option" -eq 1 ]; then SEARCH_PATHS=(); first_path_option=0; fi
      SEARCH_PATHS+=("$2")
      shift 2
      ;;
    --exclude)
      [ "$#" -ge 2 ] || { log_error "--exclude requires a value"; exit 2; }
      EXCLUDES+=("$2")
      shift 2
      ;;
    --max-results)
      [ "$#" -ge 2 ] || { log_error "--max-results requires a value"; exit 2; }
      is_uint "$2" || { log_error "--max-results must be numeric"; exit 2; }
      MAX_RESULTS="$2"
      shift 2
      ;;
    --full)
      FULL_OUTPUT=1
      shift
      ;;
    --format)
      [ "$#" -ge 2 ] || { log_error "--format requires a value"; exit 2; }
      case "$2" in markdown|text|tsv) FORMAT="$2" ;; *) log_error "unsupported format: $2"; exit 2 ;; esac
      shift 2
      ;;
    --cross-filesystems) ONE_FILE_SYSTEM=0; shift ;;
    --one-file-system) ONE_FILE_SYSTEM=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

EXISTING_PATHS=()
for p in "${SEARCH_PATHS[@]}"; do
  [ -e "$p" ] || [ -L "$p" ] || continue
  EXISTING_PATHS+=("$p")
done

if [ "${#EXISTING_PATHS[@]}" -eq 0 ]; then
  log_error "none of the selected paths exists"
  exit 2
fi

TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/sasd-root-owned-writable.XXXXXX")"
ERR_FILE="$(mktemp "${TMPDIR:-/tmp}/sasd-root-owned-writable.err.XXXXXX")"
trap 'rm -f "$TMP_FILE" "$ERR_FILE"' EXIT

cmd=(find)
for p in "${EXISTING_PATHS[@]}"; do cmd+=("$p"); done
if [ "$ONE_FILE_SYSTEM" -eq 1 ]; then cmd+=(-xdev); fi
if [ "${#EXCLUDES[@]}" -gt 0 ]; then
  cmd+=(\()
  first=1
  for ex in "${EXCLUDES[@]}"; do
    if [ "$first" -eq 0 ]; then cmd+=(-o); fi
    cmd+=(-path "$ex" -o -path "$ex/*")
    first=0
  done
  cmd+=(\) -prune -o)
fi
cmd+=(\( -type f -o -type d -o -type l \) -user root \( -perm -0020 -o -perm -0002 \) -printf '%m\t%u\t%g\t%y\t%p\n')
"${cmd[@]}" > "$TMP_FILE" 2> "$ERR_FILE" || true

TOTAL="$(wc -l < "$TMP_FILE" | awk '{print $1}')"
DISPLAYED="$TOTAL"
if [ "$FULL_OUTPUT" -ne 1 ] && [ "$TOTAL" -gt "$MAX_RESULTS" ]; then DISPLAYED="$MAX_RESULTS"; fi

limit_output() {
  if [ "$FULL_OUTPUT" -eq 1 ]; then cat; else head -n "$MAX_RESULTS"; fi
}

HOSTNAME_VALUE="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
GENERATED_AT="$(date -Iseconds)"

case "$FORMAT" in
  markdown)
    cat <<HEADER
# SASD Root-owned Writable Report

- Generated: $GENERATED_AT
- Host: $HOSTNAME_VALUE
- Paths: $(printf '`%s` ' "${EXISTING_PATHS[@]}")
- Excludes: $(printf '`%s` ' "${EXCLUDES[@]}")
- Total findings: $TOTAL
- Displayed findings: $DISPLAYED

> This read-only report highlights root-owned entries with group or other write bits set.
HEADER
    if [ -s "$ERR_FILE" ]; then
      printf '\n## Scan warnings\n\n```text\n'
      cat "$ERR_FILE"
      printf '```\n'
    fi
    printf '\n## Findings\n\n'
    if [ "$TOTAL" -eq 0 ]; then
      printf 'No matching entries found.\n'
    else
      printf '| Mode | Owner | Group | Type | Path |\n| ---: | --- | --- | --- | --- |\n'
      limit_output < "$TMP_FILE" | while IFS=$'\t' read -r mode owner group type path; do
        printf '| `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
          "$(md_escape "$mode")" "$(md_escape "$owner")" "$(md_escape "$group")" "$(md_escape "$type")" "$(md_escape "$path")"
      done
      if [ "$FULL_OUTPUT" -ne 1 ] && [ "$TOTAL" -gt "$MAX_RESULTS" ]; then
        printf '\n> Output truncated after %s entries. Use `--full` or adjust `--max-results`.\n' "$MAX_RESULTS"
      fi
    fi
    ;;
  text)
    printf 'SASD Root-owned Writable Report\nGenerated: %s\nHost:      %s\nFindings:  %s\n\n' "$GENERATED_AT" "$HOSTNAME_VALUE" "$TOTAL"
    if [ -s "$ERR_FILE" ]; then printf '== Scan warnings ==\n'; cat "$ERR_FILE"; printf '\n'; fi
    if [ "$TOTAL" -eq 0 ]; then printf 'No matching entries found.\n'; else limit_output < "$TMP_FILE"; fi
    ;;
  tsv)
    printf 'mode\towner\tgroup\ttype\tpath\n'
    limit_output < "$TMP_FILE"
    ;;
esac

exit 0
