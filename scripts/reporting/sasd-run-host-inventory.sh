#!/usr/bin/env bash
# scripts/reporting/sasd-run-host-inventory.sh
# Purpose: Run a focused read-only host inventory collection.
# Date: 2026-06-30

set -u

OUTPUT_DIR=""
MAX_LINES=140

usage() {
  cat <<'USAGE'
Usage: sasd-run-host-inventory.sh [options]

Run a focused read-only host inventory collection.

Options:
  --output DIR       Output directory (default: reports/host-inventory-YYYYmmdd-HHMMSS)
  --max-lines N      Limit long sections in network/storage inventory (default: 140)
  -h, --help         Show this help

Notes:
  - This collector is read-only.
  - Generated reports can contain hostnames, usernames, paths, IP addresses,
    package names and service names. Review before sharing.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || { echo "ERROR: --output requires a directory" >&2; exit 2; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --max-lines)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-lines requires a value" >&2; exit 2; }
      MAX_LINES="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
 done

case "$MAX_LINES" in
  ''|*[!0-9]*) echo "ERROR: --max-lines must be a positive integer" >&2; exit 2 ;;
  0) echo "ERROR: --max-lines must be greater than zero" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)"
HOSTNAME_SHORT="$(hostname 2>/dev/null || printf 'unknown')"
GENERATED="$(date -Is 2>/dev/null || date)"

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="reports/host-inventory-$(date +%Y%m%d-%H%M%S 2>/dev/null || date +%s)"
fi

mkdir -p "$OUTPUT_DIR" || { echo "ERROR: cannot create output directory: $OUTPUT_DIR" >&2; exit 2; }
STATUS_FILE="${OUTPUT_DIR}/status.tsv"
INDEX_FILE="${OUTPUT_DIR}/INDEX.md"
: > "$STATUS_FILE"
printf 'status\tscript\toutput\n' > "$STATUS_FILE"

run_report() {
  local script="$1"
  local output="$2"
  shift 2
  local status=0

  if [ ! -x "${REPO_ROOT}/${script}" ]; then
    {
      echo "# Missing script"
      echo
      printf 'Script `%s` is not executable or does not exist.\n' "$script"
    } > "${OUTPUT_DIR}/${output}"
    status=2
  else
    "${REPO_ROOT}/${script}" "$@" > "${OUTPUT_DIR}/${output}" 2>&1 || status=$?
  fi

  printf '%s\t%s\t%s\n' "$status" "$script" "$output" >> "$STATUS_FILE"
}

run_report "scripts/host-doc/sasd-host-inventory.sh" "01-host-inventory.md"
run_report "scripts/host-doc/sasd-service-inventory.sh" "02-service-inventory.md"
run_report "scripts/host-doc/sasd-package-inventory.sh" "03-package-inventory.md"
run_report "scripts/host-doc/sasd-network-inventory.sh" "04-network-inventory.md" --max-lines "$MAX_LINES"
run_report "scripts/host-doc/sasd-storage-inventory.sh" "05-storage-inventory.md" --max-lines "$MAX_LINES"

{
  echo "# SASD Host Inventory Collection"
  echo
  printf -- '- Generated: %s\n' "$GENERATED"
  printf -- '- Host: %s\n' "$HOSTNAME_SHORT"
  printf -- '- Repository root: `%s`\n' "$REPO_ROOT"
  printf -- '- Output directory: `%s`\n' "$OUTPUT_DIR"
  printf -- '- Max lines for long network/storage sections: %s\n' "$MAX_LINES"
  echo
  cat <<'EOF_INTRO'
> This collection is read-only. It documents local host facts for review and
> follow-up work. Reports can contain hostnames, usernames, paths, IP addresses,
> package names and service names; review before sharing.

## Command status

| Status | Script | Output |
| ---: | --- | --- |
EOF_INTRO
  tail -n +2 "$STATUS_FILE" | while IFS=$'\t' read -r status script output; do
    [ -n "$script" ] || continue
    printf '| %s | `%s` | [`%s`](%s) |\n' "$status" "$script" "$output" "$output"
  done
  echo
  cat <<'EOF_ORDER'
## Suggested review order

1. Open `01-host-inventory.md` for OS, kernel, CPU and memory context.
2. Open `04-network-inventory.md` for interfaces, routes and resolver context.
3. Open `05-storage-inventory.md` for filesystems, mounts, swap and block devices.
4. Open `02-service-inventory.md` and `03-package-inventory.md` for service and package context.

## Notes

- Inventory is a starting point, not a security assessment by itself.
- Compare network and storage facts with the intended host role.
- Run with elevated privileges only when needed for completeness; scripts remain read-only.
EOF_ORDER
} > "$INDEX_FILE"

echo "Report directory: $OUTPUT_DIR"
echo "Index: $INDEX_FILE"

exit 0
