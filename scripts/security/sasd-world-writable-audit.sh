#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/security/sasd-world-writable-audit.sh
# Purpose: Find world-writable files and directories below selected paths.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# This script is read-only. It does not change permissions, remove files or
# repair findings. It only reports objects where the world-writable bit is set.
#
# Why this matters
# ----------------
# World-writable files and directories are not automatically bad. /tmp is a
# normal example, usually protected by the sticky bit. However, unexpected
# world-writable paths below application directories, home directories or service
# trees can be a serious operational and security smell.
#
# Output strategy
# ---------------
# A naive world-writable scan can produce thousands of lines on developer
# workstations, WSL environments or systems with large temporary trees. To keep
# the default output reviewable, this script limits the number of printed rows.
# Use --full for an unrestricted report or --max-results N to choose a limit.
# -----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
MAX_RESULTS=500
FULL_OUTPUT="no"
PATHS=()

show_help() {
    cat <<HELP
Usage: $SCRIPT_NAME [OPTIONS] [PATH ...]

Find world-writable files and directories below the provided paths.
Default paths: /tmp /var /home /opt

Options:
  --max-results N   Print at most N findings. Default: 500.
  --full            Print all findings without truncation.
  -h, --help        Show this help text.

Examples:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --max-results 100 /var /home
  ./$SCRIPT_NAME --full /srv/www

Exit codes:
  0  Scan completed. Findings may or may not be present.
  2  Invalid command-line arguments.
HELP
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-results)
            [[ $# -ge 2 ]] || fail "--max-results requires a numeric argument"
            [[ "$2" =~ ^[0-9]+$ ]] || fail "--max-results must be numeric"
            MAX_RESULTS="$2"
            shift 2
            ;;
        --full)
            FULL_OUTPUT="yes"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                PATHS+=("$1")
                shift
            done
            ;;
        --*)
            fail "unknown option: $1"
            ;;
        *)
            PATHS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
    PATHS=(/tmp /var /home /opt)
fi

printf '# World-writable Audit\n\n'
printf 'Generated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Paths: '
printf '`%s` ' "${PATHS[@]}"
printf '\n'

if [[ "$FULL_OUTPUT" == "yes" ]]; then
    printf 'Output limit: full\n\n'
else
    printf 'Output limit: %s finding(s)\n\n' "$MAX_RESULTS"
fi

# Store matching rows in a temporary file so we can count findings and still
# present a stable, sorted report. mktemp is used because the script may run on
# multi-user systems and predictable temporary names are unsafe.
TMP_FILE="$(mktemp)" || fail "cannot create temporary file"
trap 'rm -f "$TMP_FILE"' EXIT

# find errors are redirected to stderr by default. Here we suppress them because
# permission denied messages are expected when scanning broad system paths as a
# non-root user and would make the Markdown output noisy. The report remains an
# audit helper, not a forensic collection tool.
find "${PATHS[@]}" -xdev \( -type f -o -type d \) -perm -0002 \
    -printf '%m\t%u\t%g\t%p\n' 2>/dev/null | sort > "$TMP_FILE" || true

TOTAL_FINDINGS="$(wc -l < "$TMP_FILE" | tr -d ' ')"
printf 'Findings: %s\n\n' "$TOTAL_FINDINGS"

printf '| Mode | Owner | Group | Path |\n'
printf '| ---: | --- | --- | --- |\n'

if [[ "$FULL_OUTPUT" == "yes" ]]; then
    awk -F '\t' '{ printf "| `%s` | `%s` | `%s` | `%s` |\n", $1, $2, $3, $4 }' "$TMP_FILE"
else
    awk -F '\t' -v max="$MAX_RESULTS" 'NR <= max { printf "| `%s` | `%s` | `%s` | `%s` |\n", $1, $2, $3, $4 }' "$TMP_FILE"
fi

if [[ "$FULL_OUTPUT" != "yes" && "$TOTAL_FINDINGS" -gt "$MAX_RESULTS" ]]; then
    printf '\n> Report truncated after %s finding(s). Use `--full` or `--max-results N` for more output.\n' "$MAX_RESULTS"
fi

printf '\n## Review notes\n\n'
printf -- '- World-writable directories such as `/tmp` are expected when protected by the sticky bit.\n'
printf -- '- Unexpected world-writable paths below application, service or home directories should be reviewed.\n'
printf -- '- This script reports findings only; it does not change permissions.\n'
