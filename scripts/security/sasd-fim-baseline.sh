#!/usr/bin/env bash
# Path: scripts/security/sasd-fim-baseline.sh
# Purpose: Create a simple SHA-256 file integrity baseline for selected files.
# Date: 2026-06-29
# License: MIT
#
# Why this matters:
#   File Integrity Monitoring (FIM) detects unexpected changes in important
#   configuration files. This script creates a small, transparent baseline that
#   can later be checked with sasd-fim-check.sh.
#
# Security note:
#   A baseline can reveal which files exist and can contain hashes of sensitive
#   configuration files. Store it with appropriate permissions and do not publish
#   baselines from real customer systems.
#
# Exit codes:
#   0 = baseline created successfully
#   3 = unknown / invalid arguments / required command missing

set -uo pipefail

VERSION="0.2.0"
OUTPUT=""
PATHS=()

usage() {
  cat <<'USAGE'
Usage: sasd-fim-baseline.sh [OPTIONS]

Create a tab-separated SHA-256 file integrity baseline.

Options:
      --path PATH      File or directory to include. Can be used multiple times.
      --output FILE    Write baseline to FILE instead of stdout.
  -h, --help           Show this help text
      --version        Print version

Default paths:
  /etc/passwd /etc/group /etc/sudoers /etc/fstab /etc/hosts /etc/resolv.conf
  /etc/ssh/sshd_config

Examples:
  scripts/security/sasd-fim-baseline.sh > baseline.tsv
  scripts/security/sasd-fim-baseline.sh --path /etc/ssh --output ssh-baseline.tsv

Notes:
  The script does not change monitored files. It only reads metadata and hashes.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      PATHS+=("${2:-}")
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
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

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "UNKNOWN - sha256sum is not available" >&2
  exit 3
fi

if ! command -v stat >/dev/null 2>&1; then
  echo "UNKNOWN - stat is not available" >&2
  exit 3
fi

if [[ ${#PATHS[@]} -eq 0 ]]; then
  PATHS=(
    /etc/passwd
    /etc/group
    /etc/sudoers
    /etc/fstab
    /etc/hosts
    /etc/resolv.conf
    /etc/ssh/sshd_config
  )
fi

collect_file() {
  local file="$1"
  local hash mode owner group size mtime

  [[ -f "$file" && -r "$file" ]] || return 0

  # sha256sum prints "HASH  FILE". We only need the first field.
  hash="$(sha256sum "$file" 2>/dev/null | awk '{print $1}')"
  mode="$(stat -c '%a' "$file" 2>/dev/null || true)"
  owner="$(stat -c '%U' "$file" 2>/dev/null || true)"
  group="$(stat -c '%G' "$file" 2>/dev/null || true)"
  size="$(stat -c '%s' "$file" 2>/dev/null || true)"
  mtime="$(stat -c '%Y' "$file" 2>/dev/null || true)"

  [[ -n "$hash" ]] || return 0
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$hash" "$mode" "$owner" "$group" "$size" "$mtime" "$file"
}

create_baseline() {
  printf '# sasd-fim-baseline version=%s generated=%s\n' "$VERSION" "$(date -Is 2>/dev/null || date)"
  printf '# fields: sha256 mode owner group size mtime_epoch path\n'

  for item in "${PATHS[@]}"; do
    if [[ -f "$item" ]]; then
      collect_file "$item"
    elif [[ -d "$item" ]]; then
      # Directories are traversed on the same filesystem. This avoids accidentally
      # walking mounted network filesystems when /etc or /opt contains mounts.
      while IFS= read -r -d '' file; do
        collect_file "$file"
      done < <(find "$item" -xdev -type f -print0 2>/dev/null)
    else
      echo "WARN - path does not exist or is not readable: $item" >&2
    fi
  done | sort -k7,7
}

if [[ -n "$OUTPUT" ]]; then
  # Write with a restrictive umask because baselines may contain sensitive host
  # information. The caller can relax permissions afterwards if appropriate.
  old_umask="$(umask)"
  umask 077
  create_baseline > "$OUTPUT"
  umask "$old_umask"
  echo "Baseline written to $OUTPUT" >&2
else
  create_baseline
fi

exit 0
