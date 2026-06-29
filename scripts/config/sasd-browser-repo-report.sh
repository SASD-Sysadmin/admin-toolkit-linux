#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/config/sasd-browser-repo-report.sh
# Project: admin-toolkit-linux
# Purpose: Report browser-related package repositories and installed packages.
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# Read-only. This script does not add, remove or change APT/YUM/DNF sources or
# keyrings. It only prints visible configuration and package hints.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SHOW_FILES=0
MAX_LINES=120

usage() {
  cat <<'USAGE'
Usage:
  sasd-browser-repo-report.sh [options]

Options:
  --show-files        Print matching source-list file snippets.
  --max-lines N       Limit file snippet output per source file. Default: 120.
  -h, --help          Show this help.

Examples:
  ./scripts/config/sasd-browser-repo-report.sh
  ./scripts/config/sasd-browser-repo-report.sh --show-files --max-lines 80
USAGE
}

log_error() { printf 'ERROR: %s\n' "$*" >&2; }
is_uint() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --show-files) SHOW_FILES=1; shift ;;
    --max-lines)
      [ "$#" -ge 2 ] || { log_error "--max-lines requires a value"; exit 2; }
      is_uint "$2" || { log_error "--max-lines must be numeric"; exit 2; }
      MAX_LINES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

HOSTNAME_VALUE="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
GENERATED_AT="$(date -Iseconds)"

printf 'SASD Browser Repository Report\n'
printf 'Generated: %s\n' "$GENERATED_AT"
printf 'Host:      %s\n\n' "$HOSTNAME_VALUE"

printf '== Tool detection ==\n'
for tool in apt apt-cache dpkg rpm dnf yum; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'OK:   %-10s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf 'MISS: %-10s not found\n' "$tool"
  fi
done

printf '\n== Browser-related installed package hints ==\n'
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${binary:Package}\t${Version}\n' \
    'google-chrome*' 'chrome*' 'chromium*' 'vivaldi*' 'opera*' 'brave*' 'firefox*' 'microsoft-edge*' \
    2>/dev/null | awk 'NF >= 2 {print}' | sort -u || true
elif command -v rpm >/dev/null 2>&1; then
  rpm -qa | grep -Ei 'google-chrome|chromium|vivaldi|opera|brave|firefox|microsoft-edge' | sort || true
else
  printf 'INFO: no supported package query tool found.\n'
fi

printf '\n== APT source files containing browser/vendor hints ==\n'
SOURCE_FILES=()
if [ -f /etc/apt/sources.list ]; then SOURCE_FILES+=(/etc/apt/sources.list); fi
if [ -d /etc/apt/sources.list.d ]; then
  while IFS= read -r -d '' file; do SOURCE_FILES+=("$file"); done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) -print0 2>/dev/null | sort -z)
fi

if [ "${#SOURCE_FILES[@]}" -eq 0 ]; then
  printf 'INFO: no APT source files found or APT is not used.\n'
else
  matched=0
  for file in "${SOURCE_FILES[@]}"; do
    if grep -Eiq 'google|chrome|chromium|vivaldi|opera|brave|mozilla|firefox|microsoft|edge' "$file" 2>/dev/null; then
      matched=$((matched + 1))
      stat_line="$(stat -c 'owner=%U:%G mode=%a size=%s mtime=%y' "$file" 2>/dev/null || printf 'stat unavailable')"
      printf '%s %s\n' "$file" "$stat_line"
      grep -Ein 'google|chrome|chromium|vivaldi|opera|brave|mozilla|firefox|microsoft|edge' "$file" 2>/dev/null | sed 's/^/  /' || true
    fi
  done
  if [ "$matched" -eq 0 ]; then
    printf 'INFO: no browser/vendor hints found in APT source files.\n'
  fi
fi

printf '\n== Keyring and trusted key hints ==\n'
for dir in /etc/apt/keyrings /usr/share/keyrings /etc/apt/trusted.gpg.d; do
  if [ -d "$dir" ]; then
    printf '# %s\n' "$dir"
    find "$dir" -maxdepth 1 -type f 2>/dev/null | grep -Ei 'google|chrome|chromium|vivaldi|opera|brave|mozilla|firefox|microsoft|edge' | while read -r keyfile; do
      stat -c '%n owner=%U:%G mode=%a size=%s mtime=%y' "$keyfile" 2>/dev/null || printf '%s\n' "$keyfile"
    done
  fi
done

if [ "$SHOW_FILES" -eq 1 ] && [ "${#SOURCE_FILES[@]}" -gt 0 ]; then
  printf '\n== Limited source file snippets ==\n'
  for file in "${SOURCE_FILES[@]}"; do
    if grep -Eiq 'google|chrome|chromium|vivaldi|opera|brave|mozilla|firefox|microsoft|edge' "$file" 2>/dev/null; then
      printf '\n# %s\n' "$file"
      sed -n "1,${MAX_LINES}p" "$file" 2>/dev/null || true
    fi
  done
fi

printf '\n== Review hints ==\n'
printf '%s\n' '- Browser vendor repositories are normal on desktops but should be intentional.'
printf '%s\n' '- Check whether source files and keyrings are root-owned and not world-writable.'
printf '%s\n' '- This report does not validate vendor trust or package authenticity.'

exit 0
