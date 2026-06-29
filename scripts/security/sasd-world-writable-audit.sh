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
#
# Notes:
#   World-writable paths are not automatically vulnerabilities. Temporary
#   directories and certain runtime directories can be expected. The value of
#   this script is to make such paths visible and reviewable.
#
# Exit codes:
#   0 - scan completed
#   2 - invalid arguments or execution problem

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"

DEFAULT_MAX_RESULTS=500

# Default search path. The user may replace this with one or more --path values.
SEARCH_PATHS=("/")

# Prune pseudo/volatile paths by default. This keeps the report useful and avoids
# huge output from WSL mounts, procfs/sysfs, device nodes and temp directories.
EXCLUDES=(
  "/proc"
  "/sys"
  "/dev"
  "/run"
  "/tmp"
  "/var/tmp"
  "/mnt"
  "/media"
)

MAX_RESULTS="$DEFAULT_MAX_RESULTS"
FULL_OUTPUT=0
ONE_FILE_SYSTEM=1
FORMAT="markdown"

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
  --cross-filesystems      Do not use find -xdev.
  --one-file-system        Use find -xdev. Default.
  -h, --help               Show this help.

Examples:
  ./scripts/security/sasd-world-writable-audit.sh
  ./scripts/security/sasd-world-writable-audit.sh --path /etc --path /opt
  ./scripts/security/sasd-world-writable-audit.sh --exclude /opt/nodejs --max-results 200
  ./scripts/security/sasd-world-writable-audit.sh --format tsv > /tmp/world-writable.tsv

Notes:
  This script is read-only. It does not change permissions.
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

is_positive_integer() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

# Tracks whether --path has already replaced the default search path.
custom_paths_started=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      [ "$#" -ge 2 ] || die "--path requires a value"
      if [ "$custom_paths_started" -eq 0 ]; then
        SEARCH_PATHS=()
        custom_paths_started=1
      fi
      SEARCH_PATHS+=("$2")
      shift 2
      ;;
    --exclude)
      [ "$#" -ge 2 ] || die "--exclude requires a value"
      EXCLUDES+=("$2")
      shift 2
      ;;
    --max-results)
      [ "$#" -ge 2 ] || die "--max-results requires a value"
      is_positive_integer "$2" || die "--max-results must be a positive integer"
      MAX_RESULTS="$2"
      FULL_OUTPUT=0
      shift 2
      ;;
    --full)
      FULL_OUTPUT=1
      shift
      ;;
    --format)
      [ "$#" -ge 2 ] || die "--format requires a value"
      case "$2" in
        markdown|text|tsv)
          FORMAT="$2"
          ;;
        *)
          die "unsupported --format value: $2"
          ;;
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
      die "unknown argument: $1"
      ;;
  esac
done

for path in "${SEARCH_PATHS[@]}"; do
  [ -e "$path" ] || die "search path does not exist: $path"
done

timestamp="$(date -Iseconds 2>/dev/null || date)"
host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"

tmp_results="$(mktemp)"
tmp_errors="$(mktemp)"
cleanup() {
  rm -f "$tmp_results" "$tmp_errors"
}
trap cleanup EXIT

# Build find command as an array to preserve paths with spaces.
find_cmd=(find)
for path in "${SEARCH_PATHS[@]}"; do
  find_cmd+=("$path")
done

if [ "$ONE_FILE_SYSTEM" -eq 1 ]; then
  find_cmd+=(-xdev)
fi

# Build prune expression:
#   ( -path EX1 -o -path EX1/* -o -path EX2 -o -path EX2/* ... ) -prune -o ...
#
# We match both the exact path and everything below it.
if [ "${#EXCLUDES[@]}" -gt 0 ]; then
  find_cmd+=( \( )
  first=1
  for exclude in "${EXCLUDES[@]}"; do
    if [ "$first" -eq 0 ]; then
      find_cmd+=( -o )
    fi
    find_cmd+=( -path "$exclude" -o -path "$exclude/*" )
    first=0
  done
  find_cmd+=( \) -prune -o )
fi

# GNU find -printf is intentionally used because this toolkit currently targets
# Linux and not portable POSIX Unix. It keeps the script simple and efficient.
find_cmd+=(
  -perm -0002
  -printf '%m\t%u\t%g\t%y\t%p\n'
)

# Do not let permission errors destroy the report. They are collected separately.
if ! "${find_cmd[@]}" > "$tmp_results" 2> "$tmp_errors"; then
  # find may return non-zero for permission errors. We still produce the report,
  # but mention the condition below.
  find_failed=1
else
  find_failed=0
fi

total_count="$(wc -l < "$tmp_results" | tr -d ' ')"
if [ "$FULL_OUTPUT" -eq 1 ]; then
  display_count="$total_count"
else
  display_count="$MAX_RESULTS"
fi

sticky_state() {
  # Mode is provided as a numeric permission string such as 777, 1777, 2775.
  # The sticky bit is represented by the thousands digit 1, 3, 5 or 7.
  local mode="$1"
  if [[ "$mode" =~ ^[0-9]{4,}$ ]]; then
    case "${mode:0:1}" in
      1|3|5|7) echo "sticky"; return ;;
    esac
  fi
  echo "no-sticky"
}

print_header_text() {
  cat <<EOF
SASD World-writable Filesystem Audit
Generated: $timestamp
Host:      $host
Paths:     ${SEARCH_PATHS[*]}
Excludes:  ${EXCLUDES[*]}
Max shown: $([ "$FULL_OUTPUT" -eq 1 ] && echo "full" || echo "$MAX_RESULTS")
One FS:    $([ "$ONE_FILE_SYSTEM" -eq 1 ] && echo "yes" || echo "no")

EOF
}

print_markdown() {
  cat <<EOF
# SASD World-writable Filesystem Audit

- Generated: $timestamp
- Host: $host
- Paths: \`${SEARCH_PATHS[*]}\`
- Excludes: \`${EXCLUDES[*]}\`
- Max shown: $([ "$FULL_OUTPUT" -eq 1 ] && echo "full" || echo "$MAX_RESULTS")
- One filesystem: $([ "$ONE_FILE_SYSTEM" -eq 1 ] && echo "yes" || echo "no")

EOF

  echo "## Summary"
  echo
  echo "| Metric | Value |"
  echo "| --- | ---: |"
  echo "| Matching entries | $total_count |"
  if [ "$FULL_OUTPUT" -eq 0 ] && [ "$total_count" -gt "$MAX_RESULTS" ]; then
    echo "| Displayed entries | $MAX_RESULTS |"
    echo "| Truncated | yes |"
  else
    echo "| Displayed entries | $total_count |"
    echo "| Truncated | no |"
  fi
  echo

  if [ "$find_failed" -ne 0 ] || [ -s "$tmp_errors" ]; then
    echo "## Scan warnings"
    echo
    echo "Some paths could not be scanned. This is common without root privileges or when files disappear during the scan."
    echo
    echo '```text'
    head -40 "$tmp_errors"
    echo '```'
    echo
  fi

  echo "## Findings"
  echo
  if [ "$total_count" -eq 0 ]; then
    echo "No world-writable entries were found in the selected scope."
    return
  fi

  echo "| Mode | Sticky | Owner | Group | Type | Path |"
  echo "| ---: | --- | --- | --- | --- | --- |"

  head -n "$display_count" "$tmp_results" | while IFS=$'\t' read -r mode owner group ftype path; do
    sticky="$(sticky_state "$mode")"
    # Escape pipe characters for Markdown table safety.
    safe_path="${path//|/\\|}"
    safe_owner="${owner//|/\\|}"
    safe_group="${group//|/\\|}"
    echo "| \`$mode\` | $sticky | \`$safe_owner\` | \`$safe_group\` | \`$ftype\` | \`$safe_path\` |"
  done

  if [ "$FULL_OUTPUT" -eq 0 ] && [ "$total_count" -gt "$MAX_RESULTS" ]; then
    echo
    echo "> Output truncated after $MAX_RESULTS entries. Use \`--full\` or adjust \`--max-results\`."
  fi
}

print_text() {
  print_header_text

  echo "== Summary =="
  echo "Matching entries: $total_count"
  if [ "$FULL_OUTPUT" -eq 0 ] && [ "$total_count" -gt "$MAX_RESULTS" ]; then
    echo "Displayed entries: $MAX_RESULTS"
    echo "Truncated: yes"
  else
    echo "Displayed entries: $total_count"
    echo "Truncated: no"
  fi
  echo

  if [ "$find_failed" -ne 0 ] || [ -s "$tmp_errors" ]; then
    echo "== Scan warnings =="
    head -40 "$tmp_errors"
    echo
  fi

  echo "== Findings =="
  if [ "$total_count" -eq 0 ]; then
    echo "No world-writable entries were found in the selected scope."
    return
  fi

  printf '%-6s %-10s %-16s %-16s %-4s %s\n' "Mode" "Sticky" "Owner" "Group" "Type" "Path"
  printf '%-6s %-10s %-16s %-16s %-4s %s\n' "----" "------" "-----" "-----" "----" "----"

  head -n "$display_count" "$tmp_results" | while IFS=$'\t' read -r mode owner group ftype path; do
    sticky="$(sticky_state "$mode")"
    printf '%-6s %-10s %-16s %-16s %-4s %s\n' "$mode" "$sticky" "$owner" "$group" "$ftype" "$path"
  done

  if [ "$FULL_OUTPUT" -eq 0 ] && [ "$total_count" -gt "$MAX_RESULTS" ]; then
    echo
    echo "Output truncated after $MAX_RESULTS entries. Use --full or adjust --max-results."
  fi
}

print_tsv() {
  echo -e "mode\tsticky\towner\tgroup\ttype\tpath"
  if [ "$total_count" -eq 0 ]; then
    return
  fi

  head -n "$display_count" "$tmp_results" | while IFS=$'\t' read -r mode owner group ftype path; do
    sticky="$(sticky_state "$mode")"
    echo -e "${mode}\t${sticky}\t${owner}\t${group}\t${ftype}\t${path}"
  done
}

case "$FORMAT" in
  markdown)
    print_markdown
    ;;
  text)
    print_text
    ;;
  tsv)
    print_tsv
    ;;
esac

exit 0
