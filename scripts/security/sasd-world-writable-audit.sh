#!/usr/bin/env bash
#
# scripts/security/sasd-world-writable-audit.sh
#
# Purpose:
#   Report filesystem entries that are writable by everyone.
#
# Design:
#   - read-only
#   - conservative defaults
#   - safe for local audit/report collection
#   - limits output by default to avoid huge reports on developer systems
#   - ignores symbolic-link permission bits by default because on Linux a
#     symlink often appears as mode 777 even though that mode is not the access
#     control decision for the target object
#
# Important symlink note:
#   Linux commonly displays symlinks as lrwxrwxrwx. Treating that lstat mode as
#   a finding creates large false-positive reports under /etc/rc*.d, /etc/ssl,
#   browser installs, Node.js trees and many package-managed locations. By
#   default this script reports regular files, directories, sockets, FIFOs and
#   device nodes with the world-write bit. Use --include-symlinks only when you
#   explicitly want to inventory symlink metadata as well.
#
# Exit codes:
#   0 - scan completed
#   2 - invalid arguments or execution problem

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
DEFAULT_MAX_RESULTS=500
SEARCH_PATHS=("/")
EXCLUDES=("/proc" "/sys" "/dev" "/run" "/tmp" "/var/tmp" "/mnt" "/media")
MAX_RESULTS="$DEFAULT_MAX_RESULTS"
FULL_OUTPUT=0
ONE_FILE_SYSTEM=1
FORMAT="markdown"
INCLUDE_SYMLINKS=0
PATH_WAS_SET=0

usage() {
  cat <<'USAGE'
Usage:
  sasd-world-writable-audit.sh [options]

Options:
  --path PATH              Add a search path. Can be used multiple times.
                           The first --path replaces the default / path.
  --exclude PATH           Exclude a path prefix. Can be used multiple times.
  --max-results N          Limit displayed findings. Default: 500.
  --full                   Show all findings.
  --format markdown|text|tsv
                           Output format. Default: markdown.
  --include-symlinks       Also list symlink lstat permissions. Off by default
                           because symlink mode 777 is often normal on Linux.
  --cross-filesystems      Do not use find -xdev.
  --one-file-system        Use find -xdev. Default.
  -h, --help               Show this help.

Examples:
  ./scripts/security/sasd-world-writable-audit.sh
  ./scripts/security/sasd-world-writable-audit.sh --path /etc --path /opt
  ./scripts/security/sasd-world-writable-audit.sh --exclude /opt/nodejs --max-results 200
  ./scripts/security/sasd-world-writable-audit.sh --format tsv > /tmp/world-writable.tsv
  ./scripts/security/sasd-world-writable-audit.sh --include-symlinks --max-results 50
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  exit 2
}

is_positive_integer() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]
}

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
        if [[ "$PATH_WAS_SET" -eq 0 ]]; then
          SEARCH_PATHS=()
          PATH_WAS_SET=1
        fi
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
      --format)
        [[ $# -ge 2 ]] || fail "--format requires an argument"
        case "$2" in
          markdown|text|tsv) FORMAT="$2" ;;
          *) fail "unsupported format: $2" ;;
        esac
        shift 2
        ;;
      --include-symlinks)
        INCLUDE_SYMLINKS=1
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
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done
}

build_prune_expression() {
  local expr=()
  local exclude
  for exclude in "${EXCLUDES[@]}"; do
    expr+=( -path "$exclude" -o -path "$exclude/*" -o )
  done
  if [[ "${#expr[@]}" -gt 0 ]]; then
    unset 'expr[${#expr[@]}-1]'
  fi
  printf '%q ' "${expr[@]}"
}

scan_path() {
  local path="$1"
  local result_file="$2"
  local warning_file="$3"
  local -a find_args=()
  local -a type_expr=()

  [[ -e "$path" ]] || {
    echo "WARN: search path does not exist: $path" >>"$warning_file"
    return 0
  }

  find_args=("$path")
  if [[ "$ONE_FILE_SYSTEM" -eq 1 ]]; then
    find_args+=( -xdev )
  fi

  type_expr=( '(' -type f -o -type d -o -type p -o -type s -o -type b -o -type c ')' )
  if [[ "$INCLUDE_SYMLINKS" -eq 1 ]]; then
    type_expr=( '(' -type f -o -type d -o -type p -o -type s -o -type b -o -type c -o -type l ')' )
  fi

  if [[ "${#EXCLUDES[@]}" -gt 0 ]]; then
    local -a prune_expr=()
    local exclude
    for exclude in "${EXCLUDES[@]}"; do
      prune_expr+=( -path "$exclude" -o -path "$exclude/*" -o )
    done
    unset 'prune_expr[${#prune_expr[@]}-1]'
    find "${find_args[@]}" \
      '(' "${prune_expr[@]}" ')' -prune -o \
      '(' "${type_expr[@]}" -perm -0002 -printf '%m\t%u\t%g\t%y\t%p\n' ')' \
      >>"$result_file" 2>>"$warning_file"
  else
    find "${find_args[@]}" \
      '(' "${type_expr[@]}" -perm -0002 -printf '%m\t%u\t%g\t%y\t%p\n' ')' \
      >>"$result_file" 2>>"$warning_file"
  fi
}

sticky_label() {
  local mode="$1"
  if (( 8#$mode & 01000 )); then
    printf 'sticky'
  else
    printf 'no-sticky'
  fi
}

print_header() {
  local generated host paths excludes
  generated="$(date --iso-8601=seconds)"
  host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
  paths="$(printf '`%s` ' "${SEARCH_PATHS[@]}")"
  excludes="$(printf '`%s` ' "${EXCLUDES[@]}")"

  case "$FORMAT" in
    markdown)
      cat <<HEADER
# SASD World-writable Filesystem Audit

- Generated: $generated
- Host: $host
- Paths: ${paths% }
- Excludes: ${excludes% }
- Max shown: $([[ "$FULL_OUTPUT" -eq 1 ]] && echo "unlimited" || echo "$MAX_RESULTS")
- One filesystem: $([[ "$ONE_FILE_SYSTEM" -eq 1 ]] && echo "yes" || echo "no")
- Symlinks included: $([[ "$INCLUDE_SYMLINKS" -eq 1 ]] && echo "yes" || echo "no")

> This read-only report ignores symbolic-link mode bits by default. On Linux,
> symlinks commonly appear as mode 777 even when their targets are not writable
> by everyone. Use --include-symlinks only for symlink metadata inventory.
HEADER
      ;;
    text)
      cat <<HEADER
SASD World-writable Filesystem Audit
Generated: $generated
Host:      $host
Paths:     ${SEARCH_PATHS[*]}
Excludes:  ${EXCLUDES[*]}
Max shown: $([[ "$FULL_OUTPUT" -eq 1 ]] && echo "unlimited" || echo "$MAX_RESULTS")
One FS:    $([[ "$ONE_FILE_SYSTEM" -eq 1 ]] && echo "yes" || echo "no")
Symlinks:  $([[ "$INCLUDE_SYMLINKS" -eq 1 ]] && echo "included" || echo "ignored")
HEADER
      ;;
    tsv)
      printf 'mode\tsticky\towner\tgroup\ttype\tpath\n'
      ;;
  esac
}

print_warnings() {
  local warning_file="$1"
  [[ -s "$warning_file" ]] || return 0

  case "$FORMAT" in
    markdown)
      cat <<'TEXT'

## Scan warnings

Some paths could not be scanned. This is common without root privileges or when files disappear during the scan.

```text
TEXT
      sed 's/[[:cntrl:]]//g' "$warning_file" | head -80
      cat <<'TEXT'
```
TEXT
      ;;
    text)
      echo
      echo "== Scan warnings =="
      sed 's/[[:cntrl:]]//g' "$warning_file" | head -80
      ;;
    tsv)
      ;;
  esac
}

print_summary() {
  local total="$1"
  local displayed="$2"
  local truncated="$3"

  case "$FORMAT" in
    markdown)
      cat <<SUMMARY

## Summary

| Metric | Value |
| --- | ---: |
| Matching entries | $total |
| Displayed entries | $displayed |
| Truncated | $truncated |
SUMMARY
      ;;
    text)
      cat <<SUMMARY

== Summary ==
Matching entries: $total
Displayed entries: $displayed
Truncated: $truncated
SUMMARY
      ;;
    tsv)
      ;;
  esac
}

print_findings() {
  local result_file="$1"
  local limit_file="$2"

  case "$FORMAT" in
    markdown)
      cat <<'TEXT'

## Findings

| Mode | Sticky | Owner | Group | Type | Path |
| ---: | --- | --- | --- | --- | --- |
TEXT
      while IFS=$'\t' read -r mode owner group type path; do
        [[ -n "${mode:-}" ]] || continue
        printf '| `%s` | %s | `%s` | `%s` | `%s` | `%s` |\n' \
          "$(markdown_escape "$mode")" "$(sticky_label "$mode")" \
          "$(markdown_escape "$owner")" "$(markdown_escape "$group")" \
          "$(markdown_escape "$type")" "$(markdown_escape "$path")"
      done <"$limit_file"
      ;;
    text)
      echo
      echo "== Findings =="
      printf '%-6s %-10s %-16s %-16s %-4s %s\n' "Mode" "Sticky" "Owner" "Group" "Type" "Path"
      printf '%-6s %-10s %-16s %-16s %-4s %s\n' "----" "------" "-----" "-----" "----" "----"
      while IFS=$'\t' read -r mode owner group type path; do
        [[ -n "${mode:-}" ]] || continue
        printf '%-6s %-10s %-16s %-16s %-4s %s\n' "$mode" "$(sticky_label "$mode")" "$owner" "$group" "$type" "$path"
      done <"$limit_file"
      ;;
    tsv)
      while IFS=$'\t' read -r mode owner group type path; do
        [[ -n "${mode:-}" ]] || continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$mode" "$(sticky_label "$mode")" "$owner" "$group" "$type" "$path"
      done <"$limit_file"
      ;;
  esac
}

main() {
  parse_args "$@"

  local result_file warning_file limit_file total displayed truncated path
  result_file="$(mktemp)" || exit 2
  warning_file="$(mktemp)" || exit 2
  limit_file="$(mktemp)" || exit 2
  trap "rm -f '$result_file' '$warning_file' '$limit_file'" EXIT

  for path in "${SEARCH_PATHS[@]}"; do
    scan_path "$path" "$result_file" "$warning_file"
  done

  sort -u "$result_file" -o "$result_file"
  total="$(wc -l <"$result_file" | tr -d ' ')"

  if [[ "$FULL_OUTPUT" -eq 1 ]]; then
    cp "$result_file" "$limit_file"
  else
    head -n "$MAX_RESULTS" "$result_file" >"$limit_file"
  fi
  displayed="$(wc -l <"$limit_file" | tr -d ' ')"
  if [[ "$displayed" -lt "$total" ]]; then
    truncated="yes"
  else
    truncated="no"
  fi

  print_header
  print_summary "$total" "$displayed" "$truncated"
  print_warnings "$warning_file"
  print_findings "$result_file" "$limit_file"

  if [[ "$truncated" == "yes" && "$FORMAT" == "markdown" ]]; then
    echo
    echo "> Output truncated after $displayed entries. Use \`--full\` or adjust \`--max-results\`."
  elif [[ "$truncated" == "yes" && "$FORMAT" == "text" ]]; then
    echo
    echo "Output truncated after $displayed entries. Use --full or adjust --max-results."
  fi
}

main "$@"
