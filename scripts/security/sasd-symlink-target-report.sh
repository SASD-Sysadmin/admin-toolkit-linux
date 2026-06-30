#!/usr/bin/env bash
#
# scripts/security/sasd-symlink-target-report.sh
#
# Purpose:
#   Inspect symbolic links in selected sensitive locations and show where they
#   point. This helps avoid false positives from symlink mode bits such as 777.
#
# Safety:
#   Read-only. The script does not change links, targets or permissions.

set -u
set -o pipefail

SEARCH_PATHS=("/etc/cron.d" "/etc/cron.daily" "/etc/cron.hourly" "/etc/cron.weekly" "/etc/cron.monthly" "/etc/systemd/system" "/etc/rc0.d" "/etc/rc1.d" "/etc/rc2.d" "/etc/rc3.d" "/etc/rc4.d" "/etc/rc5.d" "/etc/rc6.d" "/etc/mysql" "/etc/ssl/certs")
MAX_RESULTS=300
FULL_OUTPUT=0
PATH_WAS_SET=0

usage() {
  cat <<'USAGE'
Usage:
  sasd-symlink-target-report.sh [options]

Options:
  --path PATH        Add a path to inspect. Can be used multiple times.
                     The first --path replaces the default paths.
  --max-results N   Limit displayed symlinks. Default: 300.
  --full            Show all symlinks.
  -h, --help        Show help.

Examples:
  ./scripts/security/sasd-symlink-target-report.sh
  ./scripts/security/sasd-symlink-target-report.sh --path /etc/mysql --path /etc/cron.daily
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
      -h|--help)
        usage
        exit 0
        ;;
      *) fail "unknown argument: $1" ;;
    esac
  done
}

link_row() {
  local link_path="$1"
  local link_mode link_owner link_group raw_target resolved target_state target_mode target_owner target_group target_type

  link_mode="$(stat -c '%a' -- "$link_path" 2>/dev/null || echo '?')"
  link_owner="$(stat -c '%U' -- "$link_path" 2>/dev/null || echo '?')"
  link_group="$(stat -c '%G' -- "$link_path" 2>/dev/null || echo '?')"
  raw_target="$(readlink -- "$link_path" 2>/dev/null || echo '?')"
  resolved="$(readlink -f -- "$link_path" 2>/dev/null || true)"

  if [[ -n "$resolved" && -e "$resolved" ]]; then
    target_state="exists"
    target_mode="$(stat -Lc '%a' -- "$link_path" 2>/dev/null || echo '?')"
    target_owner="$(stat -Lc '%U' -- "$link_path" 2>/dev/null || echo '?')"
    target_group="$(stat -Lc '%G' -- "$link_path" 2>/dev/null || echo '?')"
    target_type="$(stat -Lc '%F' -- "$link_path" 2>/dev/null || echo '?')"
  else
    target_state="missing"
    target_mode="-"
    target_owner="-"
    target_group="-"
    target_type="-"
    resolved="-"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$link_mode" "$link_owner" "$link_group" "$link_path" "$raw_target" "$target_state" \
    "$target_mode" "$target_owner" "$target_group" "$target_type" "$resolved"
}

main() {
  parse_args "$@"

  local generated host rows_file total displayed truncated path link
  rows_file="$(mktemp)" || exit 2
  trap "rm -f '$rows_file'" EXIT
  total=0
  displayed=0

  for path in "${SEARCH_PATHS[@]}"; do
    [[ -e "$path" || -L "$path" ]] || continue

    if [[ -L "$path" ]]; then
      total=$((total + 1))
      if [[ "$FULL_OUTPUT" -eq 1 || "$displayed" -lt "$MAX_RESULTS" ]]; then
        link_row "$path" >>"$rows_file"
        displayed=$((displayed + 1))
      fi
    elif [[ -d "$path" ]]; then
      while IFS= read -r -d '' link; do
        total=$((total + 1))
        if [[ "$FULL_OUTPUT" -eq 1 || "$displayed" -lt "$MAX_RESULTS" ]]; then
          link_row "$link" >>"$rows_file"
          displayed=$((displayed + 1))
        fi
      done < <(find "$path" -xdev -type l -print0 2>/dev/null)
    fi
  done

  if [[ "$displayed" -lt "$total" ]]; then
    truncated="yes"
  else
    truncated="no"
  fi

  generated="$(date --iso-8601=seconds)"
  host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"

  cat <<HEADER
# SASD Symlink Target Report

- Generated: $generated
- Host: $host
- Total symlinks: $total
- Displayed symlinks: $displayed
- Truncated: $truncated

> This report separates symlink metadata from target metadata. A symlink mode such as 777 is usually not the effective permission of the target object on Linux.

## Symlinks

| Link mode | Link owner | Link group | Link path | Raw target | Target state | Target mode | Target owner | Target group | Target type | Resolved target |
| ---: | --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- |
HEADER

  while IFS=$'\t' read -r link_mode link_owner link_group link_path raw_target target_state target_mode target_owner target_group target_type resolved; do
    [[ -n "${link_mode:-}" ]] || continue
    printf '| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
      "$(markdown_escape "$link_mode")" "$(markdown_escape "$link_owner")" "$(markdown_escape "$link_group")" \
      "$(markdown_escape "$link_path")" "$(markdown_escape "$raw_target")" "$(markdown_escape "$target_state")" \
      "$(markdown_escape "$target_mode")" "$(markdown_escape "$target_owner")" "$(markdown_escape "$target_group")" \
      "$(markdown_escape "$target_type")" "$(markdown_escape "$resolved")"
  done <"$rows_file"

  if [[ "$truncated" == "yes" ]]; then
    echo
    echo "> Output truncated after $displayed entries. Use \`--full\` or adjust \`--max-results\`."
  fi
}

main "$@"
