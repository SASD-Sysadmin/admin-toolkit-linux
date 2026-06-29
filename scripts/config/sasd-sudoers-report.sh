#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# File: scripts/config/sasd-sudoers-report.sh
# Purpose: Read-only report for sudoers configuration files.
#
# This script checks:
# - whether visudo can validate the sudoers syntax,
# - ownership and permissions of /etc/sudoers and /etc/sudoers.d files,
# - visible non-comment sudo rules if the current user can read them,
# - potentially sensitive patterns such as NOPASSWD.
#
# It does not change sudo configuration and does not attempt to fix permissions.
#

set -o nounset
set -o pipefail

VERSION="0.1.0"
FORMAT="text"
SUDOERS_FILE="/etc/sudoers"
SUDOERS_DIR="/etc/sudoers.d"

usage() {
    cat <<USAGE
sasd-sudoers-report.sh ${VERSION}

Read-only sudoers configuration report.

Usage:
  sasd-sudoers-report.sh [options]

Options:
  --format FORMAT      Output format: text or markdown. Default: text
  --sudoers PATH       Main sudoers file. Default: /etc/sudoers
  --sudoers-dir PATH   sudoers.d directory. Default: /etc/sudoers.d
  --help               Show this help text.
  --version            Show version.

Exit codes:
  0  Report created.
  1  Invalid arguments.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            [[ $# -ge 2 ]] || { echo "ERROR: --format requires a value" >&2; exit 1; }
            FORMAT="$2"
            shift 2
            ;;
        --sudoers)
            [[ $# -ge 2 ]] || { echo "ERROR: --sudoers requires a path" >&2; exit 1; }
            SUDOERS_FILE="$2"
            shift 2
            ;;
        --sudoers-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --sudoers-dir requires a path" >&2; exit 1; }
            SUDOERS_DIR="$2"
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

case "$FORMAT" in
    text|markdown) ;;
    *) echo "ERROR: Unsupported format: $FORMAT" >&2; exit 1 ;;
esac

print_header() {
    if [[ "$FORMAT" == "markdown" ]]; then
        echo "# SASD Sudoers Report"
        echo
        echo "- Generated: $(date -Is 2>/dev/null || date)"
        echo "- Host: $(hostname 2>/dev/null || echo unknown)"
        echo
    else
        echo "SASD Sudoers Report"
        echo "Generated: $(date -Is 2>/dev/null || date)"
        echo "Host:      $(hostname 2>/dev/null || echo unknown)"
        echo
    fi
}

print_section() {
    local title="$1"
    if [[ "$FORMAT" == "markdown" ]]; then
        echo
        echo "## $title"
        echo
    else
        echo
        echo "== $title =="
    fi
}

file_mode_octal() {
    local path="$1"
    stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path" 2>/dev/null || echo "unknown"
}

file_owner_group() {
    local path="$1"
    stat -c '%U:%G' "$path" 2>/dev/null || stat -f '%Su:%Sg' "$path" 2>/dev/null || echo "unknown"
}

collect_files() {
    [[ -e "$SUDOERS_FILE" ]] && printf '%s\n' "$SUDOERS_FILE"
    if [[ -d "$SUDOERS_DIR" ]]; then
        find "$SUDOERS_DIR" -maxdepth 1 -type f ! -name '*~' ! -name '*.bak' | sort
    fi
}

print_header

print_section "Syntax validation"
if command -v visudo >/dev/null 2>&1; then
    if visudo -c -q >/tmp/sasd-visudo-check.$$ 2>&1; then
        [[ "$FORMAT" == "markdown" ]] && echo "- OK: visudo validation succeeded." || echo "OK: visudo validation succeeded."
    else
        [[ "$FORMAT" == "markdown" ]] && echo "- WARN: visudo validation reported issues:" || echo "WARN: visudo validation reported issues:"
        sed 's/^/  /' /tmp/sasd-visudo-check.$$
    fi
    rm -f /tmp/sasd-visudo-check.$$
else
    [[ "$FORMAT" == "markdown" ]] && echo "- INFO: visudo command not found." || echo "INFO: visudo command not found."
fi

print_section "File permissions"
if [[ "$FORMAT" == "markdown" ]]; then
    echo "| Path | Owner:Group | Mode | Note |"
    echo "|---|---:|---:|---|"
fi

while IFS= read -r path; do
    owner_group="$(file_owner_group "$path")"
    mode="$(file_mode_octal "$path")"
    note="review"

    if [[ "$owner_group" == "root:root" && ( "$mode" == "440" || "$mode" == "0440" ) ]]; then
        note="typical sudoers permissions"
    elif [[ "$owner_group" == "root:root" ]]; then
        note="owner is root, review mode"
    else
        note="review owner and permissions"
    fi

    if [[ "$FORMAT" == "markdown" ]]; then
        printf '| `%s` | `%s` | `%s` | %s |\n' "$path" "$owner_group" "$mode" "$note"
    else
        printf '%-45s owner=%-15s mode=%-5s %s\n' "$path" "$owner_group" "$mode" "$note"
    fi
done < <(collect_files)

print_section "Visible sudo rules"
if [[ "$FORMAT" == "markdown" ]]; then
    echo '```text'
fi

while IFS= read -r path; do
    if [[ -r "$path" ]]; then
        echo "# $path"
        # Print non-empty, non-comment lines. This can reveal privileged users and
        # groups, so do not paste production output into public bug reports.
        grep -Ev '^[[:space:]]*($|#)' "$path" 2>/dev/null | sed 's/[[:space:]]\+/ /g' || true
        echo
    else
        echo "# $path"
        echo "not readable by current user"
        echo
    fi
done < <(collect_files)

if [[ "$FORMAT" == "markdown" ]]; then
    echo '```'
fi

print_section "Pattern review"
patterns=("NOPASSWD" "ALL[[:space:]]*=[[:space:]]*\(ALL" "SETENV")
for pattern in "${patterns[@]}"; do
    matches=0
    while IFS= read -r path; do
        if [[ -r "$path" ]] && grep -Eiq "$pattern" "$path"; then
            matches=$((matches + 1))
        fi
    done < <(collect_files)

    if [[ "$FORMAT" == "markdown" ]]; then
        echo "- Pattern \`$pattern\`: $matches readable file(s) matched"
    else
        echo "Pattern $pattern: $matches readable file(s) matched"
    fi
done
