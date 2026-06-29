#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# File: scripts/reporting/sasd-security-summary.sh
# Purpose: Create a Markdown security summary by running existing read-only checks.
#
# This is not a vulnerability scanner and not a compliance tool. It is a small
# operational wrapper for conservative host review. It intentionally runs only
# local read-only scripts from this repository.
#
# Important implementation detail:
# Several child scripts already output Markdown, including fenced code blocks. If
# this wrapper placed that output inside another fenced block, the generated report
# would contain broken nested fences. Therefore command output is rendered as an
# indented code block. This is less fancy, but robust and easy to read on GitHub.
#
# Typical usage:
#   ./scripts/reporting/sasd-security-summary.sh > security-summary.md
#   sudo ./scripts/reporting/sasd-security-summary.sh --output /tmp/security-summary.md
#

set -o nounset
set -o pipefail

VERSION="0.1.1"
OUTPUT="-"
TIMEOUT_SECONDS=45
SENSITIVE_PATHS=("/etc" "$HOME")

usage() {
    cat <<USAGE
sasd-security-summary.sh ${VERSION}

Create a Markdown security summary by running available read-only toolkit checks.

Usage:
  sasd-security-summary.sh [options]

Options:
  --output PATH         Write report to PATH instead of stdout.
  --timeout SECONDS    Timeout per script. Default: 45
  --sensitive-path P    Path passed to sensitive-files check. Can be used multiple times.
                       Default: /etc and current user's HOME
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
        --sensitive-path)
            [[ $# -ge 2 ]] || { echo "ERROR: --sensitive-path requires a path" >&2; exit 1; }
            if [[ "${#SENSITIVE_PATHS[@]}" -eq 2 && "${SENSITIVE_PATHS[0]}" == "/etc" ]]; then
                SENSITIVE_PATHS=()
            fi
            SENSITIVE_PATHS+=("$2")
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

append_indented_output() {
    # Prefix every line with four spaces. Markdown renders this as a code block,
    # and existing backticks inside child-script output no longer break the report.
    sed 's/^/    /' >> "$TMP_REPORT"
}

run_section() {
    local title="$1"
    local script_path="$2"
    shift 2
    local rc=0
    local tmp_output

    {
        echo
        echo "## $title"
        echo
    } >> "$TMP_REPORT"

    if [[ ! -x "$script_path" ]]; then
        printf -- 'Script not available: `%s`\n' "$script_path" >> "$TMP_REPORT"
        return 0
    fi

    printf -- 'Command: `%s`\n\n' "${script_path#$REPO_ROOT/} $*" >> "$TMP_REPORT"
    tmp_output="$(mktemp)"

    if have_timeout; then
        timeout "$TIMEOUT_SECONDS" "$script_path" "$@" > "$tmp_output" 2>&1 || rc=$?
    else
        "$script_path" "$@" > "$tmp_output" 2>&1 || rc=$?
    fi

    append_indented_output < "$tmp_output"
    rm -f "$tmp_output"

    if [[ "$rc" -ne 0 ]]; then
        {
            echo
            printf -- '> Command exit status: `%s`. Some audit scripts use non-zero exit codes when findings are present; review the output above.\n' "$rc"
        } >> "$TMP_REPORT"
    fi
}

{
    echo "# SASD Security Summary"
    echo
    echo "- Generated: $(date -Is 2>/dev/null || date)"
    echo "- Host: $(hostname 2>/dev/null || echo unknown)"
    printf -- '- Repository root: `%s`\n' "$REPO_ROOT"
    echo
    echo "> This is a local, read-only review report. It is not a penetration test, not a vulnerability scan and not proof of compliance. Review sensitive output before sharing."
} > "$TMP_REPORT"

run_section "Open ports audit" "$REPO_ROOT/scripts/security/sasd-open-ports-audit.sh"
run_section "SSH baseline check" "$REPO_ROOT/scripts/security/sasd-ssh-baseline-check.sh"
run_section "SSHD configuration report" "$REPO_ROOT/scripts/config/sasd-sshd-config-report.sh"
run_section "Sudoers report" "$REPO_ROOT/scripts/config/sasd-sudoers-report.sh"
run_section "System accounts audit" "$REPO_ROOT/scripts/security/sasd-system-accounts-audit.sh"
run_section "SUID/SGID audit" "$REPO_ROOT/scripts/security/sasd-suid-sgid-audit.sh"
run_section "World-writable audit" "$REPO_ROOT/scripts/security/sasd-world-writable-audit.sh"

sensitive_script="$REPO_ROOT/scripts/security/sasd-sensitive-files-check.sh"
if [[ -x "$sensitive_script" ]]; then
    args=()
    for path in "${SENSITIVE_PATHS[@]}"; do
        [[ -e "$path" ]] && args+=("--path" "$path")
    done
    run_section "Sensitive files check" "$sensitive_script" "${args[@]}"
else
    run_section "Sensitive files check" "$sensitive_script"
fi

if [[ "$OUTPUT" == "-" ]]; then
    cat "$TMP_REPORT"
else
    cp "$TMP_REPORT" "$OUTPUT" || { echo "ERROR: Cannot write output: $OUTPUT" >&2; exit 1; }
fi
