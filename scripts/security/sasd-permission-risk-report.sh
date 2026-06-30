#!/usr/bin/env bash
#
# scripts/security/sasd-permission-risk-report.sh
#
# Purpose:
#   Produce a compact read-only permission risk report for common sensitive
#   configuration, scheduling and service locations.
#
# Safety:
#   The script only reads filesystem metadata. It does not change permissions.
#
# Symlink policy:
#   Symlink mode bits are not treated as direct findings. When a sensitive path
#   is a symlink, the script evaluates the resolved target where possible and
#   prints the symlink relation separately.

set -u
set -o pipefail

MAX_RESULTS=500
FULL_OUTPUT=0
ONE_FILE_SYSTEM=1
SEARCH_PATHS=("/etc" "/usr/local" "/opt" "/srv" "/var/www")
EXCLUDES=("/proc" "/sys" "/dev" "/run" "/tmp" "/var/tmp" "/mnt" "/media")
PATH_WAS_SET=0

usage() {
  cat <<'USAGE'
Usage:
  sasd-permission-risk-report.sh [options]

Options:
  --path PATH              Add a search path for broad scans. Can be used multiple times.
                           The first --path replaces the defaults.
  --exclude PATH           Exclude a path prefix. Can be used multiple times.
  --max-results N          Limit displayed broad-scan findings. Default: 500.
  --full                   Show all broad-scan findings.
  --cross-filesystems      Do not use find -xdev.
  --one-file-system        Use find -xdev. Default.
  -h, --help               Show help.

Examples:
  ./scripts/security/sasd-permission-risk-report.sh
  ./scripts/security/sasd-permission-risk-report.sh --path /etc --max-results 100
USAGE
}

fail() { echo "ERROR: $*" >&2; exit 2; }
is_positive_integer() { [[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]; }
markdown_escape() { local v="${1:-}"; v="${v//|/\\|}"; printf '%s' "$v"; }

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

mode_has_group_or_other_write() {
  local mode="$1"
  [[ "$mode" =~ ^[0-7]+$ ]] || return 1
  (( 8#$mode & 00022 ))
}

mode_has_other_write() {
  local mode="$1"
  [[ "$mode" =~ ^[0-7]+$ ]] || return 1
  (( 8#$mode & 00002 ))
}

stat_effective() {
  local path="$1"
  local link_note="direct" resolved="$path" mode owner group type

  if [[ -L "$path" ]]; then
    resolved="$(readlink -f -- "$path" 2>/dev/null || true)"
    link_note="symlink"
    if [[ -z "$resolved" || ! -e "$resolved" ]]; then
      printf 'dangling\t-\t-\t-\t%s\t%s\n' "$link_note" "${resolved:--}"
      return 0
    fi
    mode="$(stat -Lc '%a' -- "$path" 2>/dev/null || echo '-')"
    owner="$(stat -Lc '%U' -- "$path" 2>/dev/null || echo '-')"
    group="$(stat -Lc '%G' -- "$path" 2>/dev/null || echo '-')"
    type="$(stat -Lc '%F' -- "$path" 2>/dev/null || echo '-')"
  else
    [[ -e "$path" ]] || return 1
    mode="$(stat -c '%a' -- "$path" 2>/dev/null || echo '-')"
    owner="$(stat -c '%U' -- "$path" 2>/dev/null || echo '-')"
    group="$(stat -c '%G' -- "$path" 2>/dev/null || echo '-')"
    type="$(stat -c '%F' -- "$path" 2>/dev/null || echo '-')"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$mode" "$owner" "$group" "$type" "$link_note" "$resolved"
}

add_sensitive_path() {
  local path="$1" label="$2" sensitive_file="$3" symlink_file="$4"
  local row mode owner group type note resolved

  [[ -e "$path" || -L "$path" ]] || return 0
  row="$(stat_effective "$path")" || return 0
  IFS=$'\t' read -r mode owner group type note resolved <<<"$row"

  if [[ "$note" == "symlink" || "$mode" == "dangling" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$path" "$mode" "$owner" "$group" "$note" "$resolved" >>"$symlink_file"
  fi

  if [[ "$mode" != "dangling" && "$mode" != "-" ]] && mode_has_group_or_other_write "$mode"; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$path" "$mode" "$owner" "$group" "$note" "$resolved" >>"$sensitive_file"
  fi
}

collect_sensitive_paths() {
  local sensitive_file="$1" symlink_file="$2"
  local entry

  for entry in /etc/crontab /etc/cron.d/* /etc/cron.hourly/* /etc/cron.daily/* /etc/cron.weekly/* /etc/cron.monthly/*; do
    [[ -e "$entry" || -L "$entry" ]] && add_sensitive_path "$entry" "scheduling" "$sensitive_file" "$symlink_file"
  done
  for entry in /etc/mysql/my.cnf /etc/mysql/mariadb.cnf /etc/mysql/conf.d/* /etc/mysql/mariadb.conf.d/*; do
    [[ -e "$entry" || -L "$entry" ]] && add_sensitive_path "$entry" "database" "$sensitive_file" "$symlink_file"
  done
  for entry in /etc/systemd/system/* /etc/systemd/system/*.service /etc/systemd/system/*.timer /etc/sudoers /etc/sudoers.d/* /etc/ssh/sshd_config /etc/ssh/ssh_config; do
    [[ -e "$entry" || -L "$entry" ]] && add_sensitive_path "$entry" "system-config" "$sensitive_file" "$symlink_file"
  done
}

scan_world_writable_non_symlinks() {
  local result_file="$1" warning_file="$2" path exclude
  local -a prune_expr=()
  for exclude in "${EXCLUDES[@]}"; do
    prune_expr+=( -path "$exclude" -o -path "$exclude/*" -o )
  done
  [[ "${#prune_expr[@]}" -gt 0 ]] && unset 'prune_expr[${#prune_expr[@]}-1]'

  for path in "${SEARCH_PATHS[@]}"; do
    [[ -e "$path" ]] || { echo "WARN: search path does not exist: $path" >>"$warning_file"; continue; }
    local -a base=("$path")
    [[ "$ONE_FILE_SYSTEM" -eq 1 ]] && base+=( -xdev )

    if [[ "${#prune_expr[@]}" -gt 0 ]]; then
      find "${base[@]}" \
        '(' "${prune_expr[@]}" ')' -prune -o \
        '(' '(' -type f -o -type d ')' -perm -0002 -printf '%m\t%u\t%g\t%y\t%p\n' ')' \
        >>"$result_file" 2>>"$warning_file"
    else
      find "${base[@]}" \
        '(' '(' -type f -o -type d ')' -perm -0002 -printf '%m\t%u\t%g\t%y\t%p\n' ')' \
        >>"$result_file" 2>>"$warning_file"
    fi
  done
}

collect_suid_sgid() {
  local out_file="$1" warning_file="$2" path exclude
  local -a prune_expr=()
  for exclude in "${EXCLUDES[@]}"; do
    prune_expr+=( -path "$exclude" -o -path "$exclude/*" -o )
  done
  [[ "${#prune_expr[@]}" -gt 0 ]] && unset 'prune_expr[${#prune_expr[@]}-1]'

  for path in "${SEARCH_PATHS[@]}"; do
    [[ -e "$path" ]] || continue
    local -a base=("$path")
    [[ "$ONE_FILE_SYSTEM" -eq 1 ]] && base+=( -xdev )
    if [[ "${#prune_expr[@]}" -gt 0 ]]; then
      find "${base[@]}" '(' "${prune_expr[@]}" ')' -prune -o \
        '(' -type f '(' -perm -4000 -o -perm -2000 ')' -printf '%m\t%u\t%g\t%p\n' ')' \
        >>"$out_file" 2>>"$warning_file"
    else
      find "${base[@]}" '(' -type f '(' -perm -4000 -o -perm -2000 ')' -printf '%m\t%u\t%g\t%p\n' ')' \
        >>"$out_file" 2>>"$warning_file"
    fi
  done
}

print_limited_table() {
  local source_file="$1" max="$2" full="$3" header="$4" row_kind="$5"
  local total displayed limit_file truncated
  limit_file="$(mktemp)" || exit 2
  total="$(wc -l <"$source_file" | tr -d ' ')"
  if [[ "$full" -eq 1 ]]; then cp "$source_file" "$limit_file"; else head -n "$max" "$source_file" >"$limit_file"; fi
  displayed="$(wc -l <"$limit_file" | tr -d ' ')"
  [[ "$displayed" -lt "$total" ]] && truncated="yes" || truncated="no"

  echo
  echo "## $header"
  echo
  echo "- Total findings: $total"
  echo "- Displayed findings: $displayed"
  echo "- Truncated: $truncated"
  echo

  case "$row_kind" in
    sensitive)
      echo "| Area | Path | Effective mode | Owner | Group | Link note | Resolved target |"
      echo "| --- | --- | ---: | --- | --- | --- | --- |"
      while IFS=$'\t' read -r area path mode owner group note resolved; do
        [[ -n "${area:-}" ]] || continue
        printf '| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
          "$(markdown_escape "$area")" "$(markdown_escape "$path")" "$(markdown_escape "$mode")" \
          "$(markdown_escape "$owner")" "$(markdown_escape "$group")" "$(markdown_escape "$note")" "$(markdown_escape "$resolved")"
      done <"$limit_file"
      ;;
    world)
      echo "| Mode | Owner | Group | Type | Path |"
      echo "| ---: | --- | --- | --- | --- |"
      while IFS=$'\t' read -r mode owner group type path; do
        [[ -n "${mode:-}" ]] || continue
        printf '| `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
          "$(markdown_escape "$mode")" "$(markdown_escape "$owner")" "$(markdown_escape "$group")" "$(markdown_escape "$type")" "$(markdown_escape "$path")"
      done <"$limit_file"
      ;;
    suid)
      echo "| Mode | Owner | Group | Path |"
      echo "| ---: | --- | --- | --- |"
      while IFS=$'\t' read -r mode owner group path; do
        [[ -n "${mode:-}" ]] || continue
        printf '| `%s` | `%s` | `%s` | `%s` |\n' \
          "$(markdown_escape "$mode")" "$(markdown_escape "$owner")" "$(markdown_escape "$group")" "$(markdown_escape "$path")"
      done <"$limit_file"
      ;;
  esac

  if [[ "$truncated" == "yes" ]]; then
    echo
    echo "> Output truncated after $displayed entries. Use \`--full\` or adjust \`--max-results\`."
  fi

  rm -f "$limit_file"
}

main() {
  parse_args "$@"

  local sensitive symlinks world warnings suid generated host paths excludes
  sensitive="$(mktemp)" || exit 2
  symlinks="$(mktemp)" || exit 2
  world="$(mktemp)" || exit 2
  warnings="$(mktemp)" || exit 2
  suid="$(mktemp)" || exit 2
  trap "rm -f '$sensitive' '$symlinks' '$world' '$warnings' '$suid'" EXIT

  collect_sensitive_paths "$sensitive" "$symlinks"
  sort -u "$sensitive" -o "$sensitive"
  sort -u "$symlinks" -o "$symlinks"
  scan_world_writable_non_symlinks "$world" "$warnings"
  sort -u "$world" -o "$world"
  collect_suid_sgid "$suid" "$warnings"
  sort -u "$suid" -o "$suid"

  generated="$(date --iso-8601=seconds)"
  host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
  paths="$(printf '`%s` ' "${SEARCH_PATHS[@]}")"
  excludes="$(printf '`%s` ' "${EXCLUDES[@]}")"

  cat <<HEADER
# SASD Permission Risk Report

- Generated: $generated
- Host: $host
- Paths: ${paths% }
- Excludes: ${excludes% }
- One filesystem: $([[ "$ONE_FILE_SYSTEM" -eq 1 ]] && echo "yes" || echo "no")

> This is a read-only metadata report. Findings are review hints, not automatic proof of compromise. Symlink mode bits are not treated as direct permission findings; target metadata is evaluated where possible.
HEADER

  print_limited_table "$sensitive" "$MAX_RESULTS" "$FULL_OUTPUT" "Writable sensitive configuration entries" "sensitive"

  echo
  echo "## Sensitive symlink review"
  echo
  echo "- Total symlinks: $(wc -l <"$symlinks" | tr -d ' ')"
  echo
  echo "| Area | Link path | Target mode/state | Owner | Group | Link note | Resolved target |"
  echo "| --- | --- | ---: | --- | --- | --- | --- |"
  head -n "$MAX_RESULTS" "$symlinks" | while IFS=$'\t' read -r area path mode owner group note resolved; do
    [[ -n "${area:-}" ]] || continue
    printf '| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |\n' \
      "$(markdown_escape "$area")" "$(markdown_escape "$path")" "$(markdown_escape "$mode")" \
      "$(markdown_escape "$owner")" "$(markdown_escape "$group")" "$(markdown_escape "$note")" "$(markdown_escape "$resolved")"
  done

  print_limited_table "$world" "$MAX_RESULTS" "$FULL_OUTPUT" "World-writable regular files and directories" "world"
  print_limited_table "$suid" "$MAX_RESULTS" "$FULL_OUTPUT" "SUID/SGID executables" "suid"

  if [[ -s "$warnings" ]]; then
    echo
    echo "## Scan warnings"
    echo
    echo '```text'
    sed 's/[[:cntrl:]]//g' "$warnings" | head -80
    echo '```'
  fi
}

main "$@"
