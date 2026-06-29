#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/security/sasd-permission-risk-report.sh
# Project: admin-toolkit-linux
# Purpose: Produce a compact, read-only permission risk report for sensitive paths.
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# This script is intentionally read-only. It does not chmod, chown, delete,
# quarantine or repair anything. It only inspects metadata and reports findings.
#
# Why this script exists
# ----------------------
# Individual checks such as world-writable scans or SUID reports are useful, but
# they can be noisy. This script focuses on permission risks in places where they
# usually matter most: configuration directories, service directories, optional
# software trees and web/application locations.
#
# The report is deliberately conservative. A finding is not automatically proof of
# compromise. It is a pointer for human review.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_MAX_RESULTS=200
MAX_RESULTS="$DEFAULT_MAX_RESULTS"
FORMAT="markdown"
INCLUDE_HOME=0
ONE_FILE_SYSTEM=1
FULL_OUTPUT=0

# Sensitive-ish default paths. Keep /home out by default because developer
# workstations often contain huge tool caches and symlink forests.
SEARCH_PATHS=("/etc" "/usr/local" "/opt" "/srv" "/var/www")
EXCLUDES=("/proc" "/sys" "/dev" "/run" "/tmp" "/var/tmp" "/mnt" "/media")

usage() {
  cat <<'USAGE'
Usage:
  sasd-permission-risk-report.sh [options]

Options:
  --path PATH              Add a search path. First --path replaces defaults.
  --exclude PATH           Exclude a path prefix. Can be used multiple times.
  --include-home           Also scan /home.
  --max-results N          Limit displayed findings per section. Default: 200.
  --full                   Show all findings.
  --format markdown|text|tsv
                           Output format. Default: markdown.
  --cross-filesystems      Do not pass -xdev to find.
  --one-file-system        Pass -xdev to find. Default.
  -h, --help               Show this help.

Examples:
  ./scripts/security/sasd-permission-risk-report.sh
  ./scripts/security/sasd-permission-risk-report.sh --include-home --max-results 50
  ./scripts/security/sasd-permission-risk-report.sh --path /etc --path /opt --format text

Exit codes:
  0  Report completed. Findings may or may not be present.
  2  Invalid arguments or execution problem.
USAGE
}

log_error() {
  printf 'ERROR: %s\n' "$*" >&2
}

is_uint() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

# Escape Markdown table cells just enough for paths and command output snippets.
md_escape() {
  printf '%s' "$1" | sed 's/|/\\|/g'
}

first_path_option=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      [ "$#" -ge 2 ] || { log_error "--path requires a value"; exit 2; }
      if [ "$first_path_option" -eq 1 ]; then
        SEARCH_PATHS=()
        first_path_option=0
      fi
      SEARCH_PATHS+=("$2")
      shift 2
      ;;
    --exclude)
      [ "$#" -ge 2 ] || { log_error "--exclude requires a value"; exit 2; }
      EXCLUDES+=("$2")
      shift 2
      ;;
    --include-home)
      INCLUDE_HOME=1
      shift
      ;;
    --max-results)
      [ "$#" -ge 2 ] || { log_error "--max-results requires a value"; exit 2; }
      is_uint "$2" || { log_error "--max-results must be a non-negative integer"; exit 2; }
      MAX_RESULTS="$2"
      shift 2
      ;;
    --full)
      FULL_OUTPUT=1
      shift
      ;;
    --format)
      [ "$#" -ge 2 ] || { log_error "--format requires a value"; exit 2; }
      case "$2" in
        markdown|text|tsv) FORMAT="$2" ;;
        *) log_error "unsupported format: $2"; exit 2 ;;
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
      log_error "unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$INCLUDE_HOME" -eq 1 ]; then
  SEARCH_PATHS+=("/home")
fi

# Keep only paths that exist. A missing optional path is not an error.
EXISTING_PATHS=()
for p in "${SEARCH_PATHS[@]}"; do
  if path_exists "$p"; then
    EXISTING_PATHS+=("$p")
  fi
done

HOSTNAME_VALUE="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
GENERATED_AT="$(date -Iseconds)"

make_find_common() {
  # This function prints a safe find command fragment as NUL-separated arguments
  # is hard in POSIX shell. We therefore build commands in the callers with
  # arrays, keeping all paths as individual array elements.
  :
}

run_find() {
  # Arguments after -- are the find expression.
  local -a cmd
  local p exclude
  cmd=(find)
  for p in "${EXISTING_PATHS[@]}"; do
    cmd+=("$p")
  done
  if [ "$ONE_FILE_SYSTEM" -eq 1 ]; then
    cmd+=(-xdev)
  fi
  if [ "${#EXCLUDES[@]}" -gt 0 ]; then
    cmd+=(\()
    local first=1
    for exclude in "${EXCLUDES[@]}"; do
      if [ "$first" -eq 0 ]; then
        cmd+=(-o)
      fi
      cmd+=(-path "$exclude" -o -path "$exclude/*")
      first=0
    done
    cmd+=(\) -prune -o)
  fi
  cmd+=("$@")
  "${cmd[@]}"
}

section_world_writable() {
  run_find \( -type f -o -type d -o -type l \) -perm -0002 \
    -printf '%m\t%u\t%g\t%y\t%p\n' 2>/tmp/sasd-permission-risk-find.err || true
}

section_sensitive_config_writable() {
  local -a files
  files=(
    /etc/crontab
    /etc/sudoers
    /etc/ssh/sshd_config
    /etc/mysql/my.cnf
    /etc/my.cnf
  )
  for f in "${files[@]}"; do
    if path_exists "$f"; then
      # Show files writable by group or other, because those permissions are
      # notable on configuration files even when the owner is root.
      find "$f" \( -perm -0020 -o -perm -0002 \) -printf '%m\t%u\t%g\t%y\t%p\n' 2>/dev/null || true
    fi
  done
  for d in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/systemd/system /etc/sudoers.d /etc/mysql/conf.d /etc/mysql/mariadb.conf.d; do
    if [ -d "$d" ]; then
      find "$d" -maxdepth 1 \( -type f -o -type l \) \( -perm -0020 -o -perm -0002 \) -printf '%m\t%u\t%g\t%y\t%p\n' 2>/dev/null || true
    fi
  done
}

section_suid_sgid() {
  run_find -type f \( -perm -4000 -o -perm -2000 \) -printf '%m\t%u\t%g\t%p\n' 2>/dev/null || true
}

limit_output() {
  if [ "$FULL_OUTPUT" -eq 1 ]; then
    cat
  else
    head -n "$MAX_RESULTS"
  fi
}

count_lines() {
  wc -l | awk '{print $1}'
}

print_table_markdown() {
  local title="$1"
  local header="$2"
  local rows_file="$3"
  local total displayed
  total="$(wc -l < "$rows_file" | awk '{print $1}')"
  displayed="$total"
  if [ "$FULL_OUTPUT" -ne 1 ] && [ "$total" -gt "$MAX_RESULTS" ]; then
    displayed="$MAX_RESULTS"
  fi

  printf '\n## %s\n\n' "$title"
  printf -- '- Total findings: %s\n' "$total"
  printf -- '- Displayed findings: %s\n' "$displayed"
  if [ "$FULL_OUTPUT" -ne 1 ] && [ "$total" -gt "$MAX_RESULTS" ]; then
    printf -- '- Truncated: yes\n'
  else
    printf -- '- Truncated: no\n'
  fi
  printf '\n%b\n' "$header"

  if [ "$total" -eq 0 ]; then
    printf '\nNo matching entries found.\n'
    return
  fi

  limit_output < "$rows_file" | while IFS=$'\t' read -r a b c d e; do
    case "$title" in
      "World-writable entries"|"Writable sensitive configuration entries")
        printf '| `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
          "$(md_escape "$a")" "$(md_escape "$b")" "$(md_escape "$c")" "$(md_escape "$d")" "$(md_escape "$e")"
        ;;
      "SUID/SGID executables")
        printf '| `%s` | `%s` | `%s` | `%s` |\n' \
          "$(md_escape "$a")" "$(md_escape "$b")" "$(md_escape "$c")" "$(md_escape "$d")"
        ;;
    esac
  done
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sasd-permission-risk.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

WORLD_FILE="$TMP_DIR/world.tsv"
SENSITIVE_FILE="$TMP_DIR/sensitive.tsv"
SUID_FILE="$TMP_DIR/suid.tsv"

if [ "${#EXISTING_PATHS[@]}" -eq 0 ]; then
  log_error "none of the selected paths exists"
  exit 2
fi

section_world_writable > "$WORLD_FILE"
section_sensitive_config_writable | sort -u > "$SENSITIVE_FILE"
section_suid_sgid > "$SUID_FILE"

case "$FORMAT" in
  markdown)
    cat <<HEADER
# SASD Permission Risk Report

- Generated: $GENERATED_AT
- Host: $HOSTNAME_VALUE
- Paths: $(printf '`%s` ' "${EXISTING_PATHS[@]}")
- Excludes: $(printf '`%s` ' "${EXCLUDES[@]}")
- One filesystem: $([ "$ONE_FILE_SYSTEM" -eq 1 ] && printf 'yes' || printf 'no')

> This is a read-only metadata report. Findings are review hints, not automatic proof of compromise.
HEADER

    print_table_markdown "Writable sensitive configuration entries" '| Mode | Owner | Group | Type | Path |\n| ---: | --- | --- | --- | --- |' "$SENSITIVE_FILE"
    print_table_markdown "World-writable entries" '| Mode | Owner | Group | Type | Path |\n| ---: | --- | --- | --- | --- |' "$WORLD_FILE"
    print_table_markdown "SUID/SGID executables" '| Mode | Owner | Group | Path |\n| ---: | --- | --- | --- |' "$SUID_FILE"
    ;;
  text)
    printf 'SASD Permission Risk Report\nGenerated: %s\nHost:      %s\n\n' "$GENERATED_AT" "$HOSTNAME_VALUE"
    printf '== Writable sensitive configuration entries ==\n'
    if [ -s "$SENSITIVE_FILE" ]; then limit_output < "$SENSITIVE_FILE"; else printf 'No matching entries found.\n'; fi
    printf '\n== World-writable entries ==\n'
    if [ -s "$WORLD_FILE" ]; then limit_output < "$WORLD_FILE"; else printf 'No matching entries found.\n'; fi
    printf '\n== SUID/SGID executables ==\n'
    if [ -s "$SUID_FILE" ]; then limit_output < "$SUID_FILE"; else printf 'No matching entries found.\n'; fi
    ;;
  tsv)
    printf 'section\tmode\towner\tgroup\ttype_or_path\tpath\n'
    awk -F '\t' 'BEGIN{OFS="\t"}{print "sensitive",$1,$2,$3,$4,$5}' "$SENSITIVE_FILE"
    awk -F '\t' 'BEGIN{OFS="\t"}{print "world_writable",$1,$2,$3,$4,$5}' "$WORLD_FILE"
    awk -F '\t' 'BEGIN{OFS="\t"}{print "suid_sgid",$1,$2,$3,$4,$4}' "$SUID_FILE"
    ;;
esac

exit 0
