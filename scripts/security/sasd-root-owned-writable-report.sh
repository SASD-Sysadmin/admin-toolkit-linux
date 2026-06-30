#!/usr/bin/env bash
#
# scripts/security/sasd-root-owned-writable-report.sh
#
# Purpose:
#   Report root-owned regular files and directories that are writable by group
#   or others in sensitive locations.
#
# Safety:
#   Read-only. This script never changes permissions.
#
# Symlink policy:
#   Symbolic-link mode bits are ignored by default. Linux commonly presents
#   symlinks as mode 777. The access control decision is made on the target,
#   not on the symlink itself. Use sasd-symlink-target-report.sh to inspect
#   symlink targets in a controlled way.

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SEARCH_PATHS=("/etc" "/usr/local" "/opt" "/srv" "/var/www")
EXCLUDES=("/proc" "/sys" "/dev" "/run" "/tmp" "/var/tmp" "/mnt" "/media")
MAX_RESULTS=500
FULL_OUTPUT=0
ONE_FILE_SYSTEM=1
PATH_WAS_SET=0
INCLUDE_SYMLINK_TARGETS=0

usage() {
  cat <<'USAGE'
Usage:
  sasd-root-owned-writable-report.sh [options]

Options:
  --path PATH                 Add a search path. Can be used multiple times.
                              The first --path replaces the defaults.
  --exclude PATH              Exclude a path prefix. Can be used multiple times.
  --max-results N             Limit displayed findings. Default: 500.
  --full                      Show all findings.
  --include-symlink-targets   Follow symlinks while scanning. Off by default.
  --cross-filesystems         Do not use find -xdev.
  --one-file-system           Use find -xdev. Default.
  -h, --help                  Show this help.

Examples:
  ./scripts/security/sasd-root-owned-writable-report.sh
  ./scripts/security/sasd-root-owned-writable-report.sh --path /etc --max-results 100
USAGE
}

fail() { echo "ERROR: $*" >&2; exit 2; }

is_positive_integer() { [[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]; }

markdown_escape() {
  local value="${1:-}"
  value="${value//|/\\|}"
  printf '%s' "$value"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)
        [[ $# -ge 2 ]] || fail "--path requires an argument"
        if [[ "$PATH_WAS_SET" -eq 0 ]]; then SEARCH_PATHS=(); PATH_WAS_SET=1; fi
        SEARCH_PATHS+=("$2")
        shift 2
        ;;
      --exclude)
        [[ $# -ge 2 ]] || fail "--exclude requires an argument"
        EXCLUDES+=("$2")
        shift 2
        ;;
      --max-results)
        [[ $# -ge 2 ]] || fail "--max-results requires an argument"
        is_positive_integer "$2" || fail "--max-results must be a positive integer"
        MAX_RESULTS="$2"
        shift 2
        ;;
      --full)
        FULL_OUTPUT=1
        shift
        ;;
      --include-symlink-targets)
        INCLUDE_SYMLINK_TARGETS=1
        shift
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
      *) fail "unknown argument: $1" ;;
    esac
  done
}

scan_path() {
  local path="$1" result_file="$2" warning_file="$3"
  local -a base=("$path")
  local -a prune_expr=()
  local exclude

  [[ -e "$path" ]] || { echo "WARN: search path does not exist: $path" >>"$warning_file"; return 0; }
  [[ "$INCLUDE_SYMLINK_TARGETS" -eq 1 ]] && base=(-L "$path")
  [[ "$ONE_FILE_SYSTEM" -eq 1 ]] && base+=( -xdev )

  for exclude in "${EXCLUDES[@]}"; do
    prune_expr+=( -path "$exclude" -o -path "$exclude/*" -o )
  done
  [[ "${#prune_expr[@]}" -gt 0 ]] && unset 'prune_expr[${#prune_expr[@]}-1]'

  if [[ "${#prune_expr[@]}" -gt 0 ]]; then
    find "${base[@]}" \
      '(' "${prune_expr[@]}" ')' -prune -o \
      '(' '(' -type f -o -type d ')' -user 0 '(' -perm -002 -o -perm -020 ')' -printf '%m\t%u\t%g\t%y\t%p\n' ')' \
      >>"$result_file" 2>>"$warning_file"
  else
    find "${base[@]}" \
      '(' '(' -type f -o -type d ')' -user 0 '(' -perm -002 -o -perm -020 ')' -printf '%m\t%u\t%g\t%y\t%p\n' ')' \
      >>"$result_file" 2>>"$warning_file"
  fi
}

main() {
  parse_args "$@"

  local result_file warning_file limit_file total displayed truncated generated host paths excludes path
  result_file="$(mktemp)" || exit 2
  warning_file="$(mktemp)" || exit 2
  limit_file="$(mktemp)" || exit 2
  trap "rm -f '$result_file' '$warning_file' '$limit_file'" EXIT

  for path in "${SEARCH_PATHS[@]}"; do
    scan_path "$path" "$result_file" "$warning_file"
  done

  sort -u "$result_file" -o "$result_file"
  total="$(wc -l <"$result_file" | tr -d ' ')"
  if [[ "$FULL_OUTPUT" -eq 1 ]]; then cp "$result_file" "$limit_file"; else head -n "$MAX_RESULTS" "$result_file" >"$limit_file"; fi
  displayed="$(wc -l <"$limit_file" | tr -d ' ')"
  [[ "$displayed" -lt "$total" ]] && truncated="yes" || truncated="no"

  generated="$(date --iso-8601=seconds)"
  host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
  paths="$(printf '`%s` ' "${SEARCH_PATHS[@]}")"
  excludes="$(printf '`%s` ' "${EXCLUDES[@]}")"

  cat <<HEADER
# SASD Root-owned Writable Report

- Generated: $generated
- Host: $host
- Paths: ${paths% }
- Excludes: ${excludes% }
- Total findings: $total
- Displayed findings: $displayed
- Truncated: $truncated
- Symlink targets followed: $([[ "$INCLUDE_SYMLINK_TARGETS" -eq 1 ]] && echo "yes" || echo "no")

> This read-only report highlights root-owned regular files and directories with group or other write bits set. Symlink mode bits are ignored by default to avoid Linux symlink false positives.
HEADER

  if [[ -s "$warning_file" ]]; then
    cat <<'WARN'

## Scan warnings

```text
WARN
    sed 's/[[:cntrl:]]//g' "$warning_file" | head -80
    cat <<'WARN'
```
WARN
  fi

  cat <<'TABLE'

## Findings

| Mode | Owner | Group | Type | Path |
| ---: | --- | --- | --- | --- |
TABLE
  while IFS=$'\t' read -r mode owner group type entry_path; do
    [[ -n "${mode:-}" ]] || continue
    printf '| `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
      "$(markdown_escape "$mode")" "$(markdown_escape "$owner")" "$(markdown_escape "$group")" \
      "$(markdown_escape "$type")" "$(markdown_escape "$entry_path")"
  done <"$limit_file"

  if [[ "$truncated" == "yes" ]]; then
    echo
    echo "> Output truncated after $displayed entries. Use \`--full\` or adjust \`--max-results\`."
  fi
}

main "$@"
