#!/usr/bin/env bash
# Path: scripts/reporting/sasd-run-fim-review.sh
# Purpose: Run a focused read-only file integrity monitoring review.
# Date: 2026-06-30
# License: MIT
#
# This collector creates reports under an output directory. It does not modify
# monitored files. Creating a fresh baseline file is report output, not a change
# to the monitored paths.

set -uo pipefail

VERSION="0.1.0"
OUTPUT_DIR=""
BASELINE=""
MAX_ROWS="80"
PATHS=()

usage() {
  cat <<'USAGE'
Usage: sasd-run-fim-review.sh [OPTIONS]

Run a focused read-only FIM review collection.

Options:
  --output DIR      Directory for generated reports
  --baseline FILE   Existing baseline to check with sasd-fim-check.sh
  --path PATH       File or directory for a fresh baseline. Can be repeated.
  --max-rows N      Maximum detail rows in summary report (default: 80)
  -h, --help        Show this help text
  --version         Print version

Examples:
  scripts/reporting/sasd-run-fim-review.sh --output ./reports/fim-review
  scripts/reporting/sasd-run-fim-review.sh --path /etc --output ./reports/fim-current
  scripts/reporting/sasd-run-fim-review.sh --baseline ./reports/fim-current/01-current-baseline.tsv --output ./reports/fim-check

Notes:
  The scripts are read-only for monitored files. Generated baseline/check/report
  files are written only below the selected output directory.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --baseline)
      BASELINE="${2:-}"
      shift 2
      ;;
    --path)
      PATHS+=("${2:-}")
      shift 2
      ;;
    --max-rows)
      MAX_ROWS="${2:-}"
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

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="reports/fim-review-$(date +%Y%m%d-%H%M%S)"
fi

if ! [[ "$MAX_ROWS" =~ ^[0-9]+$ ]] || (( MAX_ROWS < 1 )); then
  echo "UNKNOWN - --max-rows must be a positive integer" >&2
  exit 3
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASELINE_SCRIPT="$REPO_ROOT/scripts/security/sasd-fim-baseline.sh"
CHECK_SCRIPT="$REPO_ROOT/scripts/security/sasd-fim-check.sh"
REPORT_SCRIPT="$REPO_ROOT/scripts/security/sasd-fim-report.py"

mkdir -p "$OUTPUT_DIR"

STATUS_FILE="$OUTPUT_DIR/status.tsv"
INDEX_FILE="$OUTPUT_DIR/INDEX.md"
CURRENT_BASELINE="$OUTPUT_DIR/01-current-baseline.tsv"
CHECK_REPORT="$OUTPUT_DIR/02-fim-check.md"
SUMMARY_REPORT="$OUTPUT_DIR/03-fim-report.md"

printf 'status\tscript\toutput\n' > "$STATUS_FILE"

run_and_record() {
  local output_file="$1"
  shift
  local status=0

  "$@" > "$OUTPUT_DIR/$output_file" 2> "$OUTPUT_DIR/$output_file.stderr" || status=$?

  if [[ -s "$OUTPUT_DIR/$output_file.stderr" ]]; then
    {
      printf '\n\n## STDERR\n\n```text\n'
      cat "$OUTPUT_DIR/$output_file.stderr"
      printf '```\n'
    } >> "$OUTPUT_DIR/$output_file"
  fi
  rm -f "$OUTPUT_DIR/$output_file.stderr"

  printf '%s\t%s\t%s\n' "$status" "$1" "$output_file" >> "$STATUS_FILE"
  return 0
}

write_info_file() {
  local output_file="$1"
  shift
  cat > "$OUTPUT_DIR/$output_file"
}

# Build a fresh baseline for the selected paths or the baseline script defaults.
baseline_args=("$BASELINE_SCRIPT" "--output" "$CURRENT_BASELINE")
if (( ${#PATHS[@]} > 0 )); then
  for item in "${PATHS[@]}"; do
    baseline_args+=("--path" "$item")
  done
fi

baseline_status=0
"${baseline_args[@]}" > "$OUTPUT_DIR/01-current-baseline.log" 2>&1 || baseline_status=$?
printf '%s\t%s\t%s\n' "$baseline_status" "scripts/security/sasd-fim-baseline.sh" "01-current-baseline.tsv" >> "$STATUS_FILE"

# Check an existing baseline if provided. Otherwise explain that the collection
# intentionally produced a current baseline only.
if [[ -n "$BASELINE" ]]; then
  check_status=0
  "$CHECK_SCRIPT" --baseline "$BASELINE" > "$CHECK_REPORT" 2> "$CHECK_REPORT.stderr" || check_status=$?
  if [[ -s "$CHECK_REPORT.stderr" ]]; then
    {
      printf '\n\n## STDERR\n\n```text\n'
      cat "$CHECK_REPORT.stderr"
      printf '```\n'
    } >> "$CHECK_REPORT"
  fi
  rm -f "$CHECK_REPORT.stderr"
  printf '%s\t%s\t%s\n' "$check_status" "scripts/security/sasd-fim-check.sh" "02-fim-check.md" >> "$STATUS_FILE"
else
  cat > "$CHECK_REPORT" <<'EOF'
# SASD FIM Check

INFO: no existing baseline was provided.

This collection created a fresh current baseline only. Store it securely and use
it as `--baseline` in a later run to detect changed, missing or unreadable files.
EOF
  printf '0\t%s\t%s\n' "scripts/security/sasd-fim-check.sh" "02-fim-check.md" >> "$STATUS_FILE"
fi

# Generate a human-friendly summary. If an existing baseline was provided, use
# that as the reference. Otherwise summarize the freshly generated baseline.
if command -v python3 >/dev/null 2>&1; then
  report_status=0
  if [[ -n "$BASELINE" ]]; then
    python3 "$REPORT_SCRIPT" --baseline "$BASELINE" --check-report "$CHECK_REPORT" --max-rows "$MAX_ROWS" > "$SUMMARY_REPORT" || report_status=$?
  else
    python3 "$REPORT_SCRIPT" --baseline "$CURRENT_BASELINE" --max-rows "$MAX_ROWS" > "$SUMMARY_REPORT" || report_status=$?
  fi
else
  report_status=3
  cat > "$SUMMARY_REPORT" <<'EOF'
# SASD File Integrity Report

UNKNOWN: python3 is not available, so the FIM summary report could not be generated.
EOF
fi
printf '%s\t%s\t%s\n' "$report_status" "scripts/security/sasd-fim-report.py" "03-fim-report.md" >> "$STATUS_FILE"

{
  printf '# SASD File Integrity Monitoring Review Collection\n\n'
  printf -- '- Generated: %s\n' "$(date -Is 2>/dev/null || date)"
  printf -- '- Host: %s\n' "$(hostname 2>/dev/null || echo unknown)"
  printf -- '- Repository root: `%s`\n' "$REPO_ROOT"
  printf -- '- Output directory: `%s`\n' "$OUTPUT_DIR"
  printf -- '- Existing baseline: `%s`\n' "${BASELINE:-not provided}"
  printf -- '- Fresh baseline: `01-current-baseline.tsv`\n'
  printf -- '- Paths selected: `%s`\n\n' "${PATHS[*]:-baseline-script defaults}"
  printf '> This collection is read-only for monitored files. Generated baseline and\n'
  printf '> report files are written only below the output directory. Baselines can reveal\n'
  printf '> sensitive path, ownership, permission, size and hash information.\n\n'
  printf '## Command status\n\n'
  printf '| Status | Script | Output |\n'
  printf '| ---: | --- | --- |\n'
} > "$INDEX_FILE"

tail -n +2 "$STATUS_FILE" | while IFS=$'\t' read -r status script output; do
  printf '| %s | `%s` | [`%s`](%s) |\n' "$status" "$script" "$output" "$output" >> "$INDEX_FILE"
done

cat >> "$INDEX_FILE" <<'EOF'

## Suggested review order

1. Open `03-fim-report.md` for the human-friendly summary.
2. Store `01-current-baseline.tsv` securely if it is intended as a future reference.
3. Open `02-fim-check.md` when an existing baseline was checked.
4. Treat changed, missing or unreadable entries as review items, not automatic proof of compromise.

## Notes

- A FIM baseline is only as trustworthy as the moment and system state in which it was created.
- Do not publish real baselines or FIM reports without reviewing paths, usernames, ownership, modes and hashes.
- This is not a replacement for an enterprise FIM, EDR or SIEM solution.
EOF

printf 'Report directory: %s\n' "$OUTPUT_DIR"
printf 'Index: %s\n' "$INDEX_FILE"
exit 0
