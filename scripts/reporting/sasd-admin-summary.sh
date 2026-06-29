#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# File: scripts/reporting/sasd-admin-summary.sh
# Purpose: Create a small operational Markdown summary by running existing toolkit scripts.
#
# This script is a wrapper. It does not implement all checks itself. Instead, it
# calls selected read-only scripts from this repository when they are present.
# Missing scripts are skipped with a note. This makes the wrapper useful while the
# toolkit is still growing.
#
# Typical usage:
#   ./scripts/reporting/sasd-admin-summary.sh > admin-summary.md
#   ./scripts/reporting/sasd-admin-summary.sh --output /tmp/admin-summary.md
#

set -o nounset
set -o pipefail

VERSION="0.1.0"
OUTPUT="-"
TIMEOUT_SECONDS=30

usage() {
    cat <<USAGE
sasd-admin-summary.sh ${VERSION}

Create a Markdown operational summary by running available read-only toolkit scripts.

Usage:
  sasd-admin-summary.sh [options]

Options:
  --output PATH         Write report to PATH instead of stdout.
  --timeout SECONDS    Timeout per script. Default: 30
  --help               Show this help text.
  --version            Show version.

Exit codes:
  0  Report created.
  1  Invalid arguments or write error.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            [[ $# -ge 2 ]] || { echo "ERROR: --output requires a path" >&2; exit 1; }
            OUTPUT="$2"
            shift 2
            ;;
        --timeout)
            [[ $# -ge 2 ]] || { echo "ERROR: --timeout requires seconds" >&2; exit 1; }
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --version)
            echo "$VERSION"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

[[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || { echo "ERROR: timeout must be numeric" >&2; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
TMP_REPORT="$(mktemp)"
trap 'rm -f "$TMP_REPORT"' EXIT

have_timeout() {
    command -v timeout >/dev/null 2>&1
}

run_section() {
    local title="$1"
    local script_path="$2"
    shift 2

    {
        echo
        echo "## $title"
        echo
    } >> "$TMP_REPORT"

    if [[ ! -x "$script_path" ]]; then
        printf -- 'Script not available: `%s`\n' "$script_path" >> "$TMP_REPORT"
        return 0
    fi

    echo '```text' >> "$TMP_REPORT"
    if have_timeout; then
        timeout "$TIMEOUT_SECONDS" "$script_path" "$@" >> "$TMP_REPORT" 2>&1 || {
            rc=$?
            echo "[wrapper] command exited with status $rc" >> "$TMP_REPORT"
        }
    else
        "$script_path" "$@" >> "$TMP_REPORT" 2>&1 || {
            rc=$?
            echo "[wrapper] command exited with status $rc" >> "$TMP_REPORT"
        }
    fi
    echo '```' >> "$TMP_REPORT"
}

{
    echo "# SASD Admin Summary"
    echo
    echo "- Generated: $(date -Is 2>/dev/null || date)"
    echo "- Host: $(hostname 2>/dev/null || echo unknown)"
    printf -- '- Repository root: `%s`\n' "$REPO_ROOT"
    echo
    echo "> This report is generated from read-only toolkit scripts. Review output before sharing it publicly because hostnames, usernames, IP addresses, paths or package names may reveal environment details."
} > "$TMP_REPORT"

run_section "Host inventory" "$REPO_ROOT/scripts/host-doc/sasd-host-inventory.sh"
run_section "Service inventory" "$REPO_ROOT/scripts/host-doc/sasd-service-inventory.sh"
run_section "Package inventory" "$REPO_ROOT/scripts/host-doc/sasd-package-inventory.sh"
run_section "Disk usage" "$REPO_ROOT/scripts/filesystem/sasd-disk-usage-report.sh"
run_section "Deleted open files" "$REPO_ROOT/scripts/filesystem/sasd-deleted-open-files.sh"
run_section "Journal warnings and errors" "$REPO_ROOT/scripts/logging/sasd-journal-errors.sh"
run_section "Authentication log report" "$REPO_ROOT/scripts/logging/sasd-auth-log-report.sh"
run_section "Reboot required check" "$REPO_ROOT/scripts/monitoring/check_reboot_required.sh"

if [[ "$OUTPUT" == "-" ]]; then
    cat "$TMP_REPORT"
else
    cp "$TMP_REPORT" "$OUTPUT" || { echo "ERROR: Cannot write output: $OUTPUT" >&2; exit 1; }
fi
