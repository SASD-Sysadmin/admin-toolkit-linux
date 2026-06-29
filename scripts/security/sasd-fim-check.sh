#!/usr/bin/env bash
# Path: scripts/security/sasd-fim-check.sh
# Purpose: Compare current files against a sasd-fim-baseline.sh baseline.
# Date: 2026-06-29
# License: MIT
#
# Why this matters:
#   A small file integrity check is useful for lab systems, small servers and
#   incident triage. It is not a replacement for a full FIM platform, but it makes
#   unexpected changes visible in a transparent and reviewable way.
#
# Exit codes:
#   0 = all baseline entries still match
#   1 = at least one file changed or is missing
#   3 = unknown / invalid arguments / required command missing

set -uo pipefail

VERSION="0.2.0"
BASELINE=""

usage() {
  cat <<'USAGE'
Usage: sasd-fim-check.sh --baseline FILE

Compare current files against a baseline created by sasd-fim-baseline.sh.

Options:
      --baseline FILE   Baseline TSV file to check
  -h, --help            Show this help text
      --version         Print version

Examples:
  scripts/security/sasd-fim-check.sh --baseline baseline.tsv

Notes:
  The script is read-only. It does not repair or modify monitored files.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline)
      BASELINE="${2:-}"
      shift 2
      ;;
    --version)
      echo "$VERSION"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN - unsupported argument: $1" >&2
      usage >&2
      exit 3
      ;;
  esac
done

if [[ -z "$BASELINE" ]]; then
  echo "UNKNOWN - --baseline is required" >&2
  usage >&2
  exit 3
fi

if [[ ! -r "$BASELINE" ]]; then
  echo "UNKNOWN - cannot read baseline: $BASELINE" >&2
  exit 3
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "UNKNOWN - sha256sum is not available" >&2
  exit 3
fi

if ! command -v stat >/dev/null 2>&1; then
  echo "UNKNOWN - stat is not available" >&2
  exit 3
fi

printf '# File Integrity Check\n\n'
printf 'Generated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Baseline: `%s`\n\n' "$BASELINE"
printf '| Status | Path | Details |\n'
printf '| --- | --- | --- |\n'

finding=0
checked=0

current_record() {
  local file="$1"
  local hash mode owner group size mtime

  [[ -f "$file" && -r "$file" ]] || return 1

  hash="$(sha256sum "$file" 2>/dev/null | awk '{print $1}')"
  mode="$(stat -c '%a' "$file" 2>/dev/null || true)"
  owner="$(stat -c '%U' "$file" 2>/dev/null || true)"
  group="$(stat -c '%G' "$file" 2>/dev/null || true)"
  size="$(stat -c '%s' "$file" 2>/dev/null || true)"
  mtime="$(stat -c '%Y' "$file" 2>/dev/null || true)"

  [[ -n "$hash" ]] || return 1
  printf '%s\t%s\t%s\t%s\t%s\t%s' "$hash" "$mode" "$owner" "$group" "$size" "$mtime"
}

while IFS=$'\t' read -r old_hash old_mode old_owner old_group old_size old_mtime path; do
  # Skip comments and empty lines. Baseline files intentionally start with
  # comment lines so humans can identify the file format.
  [[ -z "${old_hash:-}" ]] && continue
  [[ "$old_hash" == \#* ]] && continue

  checked=$((checked + 1))

  if [[ -z "${path:-}" ]]; then
    printf '| INVALID_BASELINE_ROW | `unknown` | row %s has no path |\n' "$checked"
    finding=1
    continue
  fi

  if [[ ! -e "$path" ]]; then
    printf '| MISSING | `%s` | file no longer exists |\n' "$path"
    finding=1
    continue
  fi

  if ! current="$(current_record "$path")"; then
    printf '| UNREADABLE | `%s` | file exists but cannot be read |\n' "$path"
    finding=1
    continue
  fi

  IFS=$'\t' read -r new_hash new_mode new_owner new_group new_size new_mtime <<<"$current"

  details=()
  if [[ "$old_hash" != "$new_hash" ]]; then
    details+=("sha256 changed")
  fi
  if [[ "$old_mode" != "$new_mode" ]]; then
    details+=("mode ${old_mode}->${new_mode}")
  fi
  if [[ "$old_owner" != "$new_owner" ]]; then
    details+=("owner ${old_owner}->${new_owner}")
  fi
  if [[ "$old_group" != "$new_group" ]]; then
    details+=("group ${old_group}->${new_group}")
  fi
  if [[ "$old_size" != "$new_size" ]]; then
    details+=("size ${old_size}->${new_size}")
  fi
  if [[ "$old_mtime" != "$new_mtime" ]]; then
    details+=("mtime ${old_mtime}->${new_mtime}")
  fi

  if [[ ${#details[@]} -gt 0 ]]; then
    printf '| CHANGED | `%s` | %s |\n' "$path" "$(IFS='; '; echo "${details[*]}")"
    finding=1
  fi
done < "$BASELINE"

if (( checked == 0 )); then
  printf '| UNKNOWN | `%s` | no baseline entries found |\n' "$BASELINE"
  exit 3
fi

if (( finding == 0 )); then
  printf '| OK | All baseline entries match | checked %s files |\n' "$checked"
fi

exit "$finding"
