#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# File: scripts/accounts/sasd-account-baseline.sh
# Purpose: Create a read-only local account baseline from passwd/group/shadow.
#
# The output is a TSV file designed for later comparison with
# sasd-account-diff.sh. It intentionally does not export password hashes.
# Only password status is recorded:
# - unreadable: current user cannot read shadow information
# - empty: password field is empty, review immediately
# - locked: common locked account markers such as ! or *
# - set: a password hash or other non-empty credential marker exists
#
# Typical usage:
#   ./scripts/accounts/sasd-account-baseline.sh > accounts.tsv
#   sudo ./scripts/accounts/sasd-account-baseline.sh > accounts-root.tsv
#

set -o nounset
set -o pipefail

VERSION="0.1.0"
OUTPUT="-"
INCLUDE_HEADER="yes"

usage() {
    cat <<USAGE
sasd-account-baseline.sh ${VERSION}

Create a read-only TSV baseline of local users and groups.

Usage:
  sasd-account-baseline.sh [options]

Options:
  --output PATH         Write output to PATH instead of stdout.
  --no-header          Do not print the TSV header line.
  --help               Show this help text.
  --version            Show version.

Exit codes:
  0  Baseline created.
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
        --no-header)
            INCLUDE_HEADER="no"
            shift
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

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

password_status_for_user() {
    local user="$1"
    local shadow_line shadow_field

    if [[ ! -r /etc/shadow ]]; then
        echo "unreadable"
        return 0
    fi

    shadow_line="$(grep -E "^${user}:" /etc/shadow 2>/dev/null | head -n 1 || true)"
    if [[ -z "$shadow_line" ]]; then
        echo "missing"
        return 0
    fi

    shadow_field="$(printf '%s\n' "$shadow_line" | cut -d: -f2)"
    case "$shadow_field" in
        "") echo "empty" ;;
        '!'*|'*'*) echo "locked" ;;
        *) echo "set" ;;
    esac
}

emit_header() {
    printf 'record_type\tname\tid\tprimary_or_members\thome\tshell\tpassword_status\n'
}

emit_users() {
    # Use getent when available so NSS-provided local-compatible entries can be seen.
    # For a strict /etc/passwd-only baseline, replace getent with cat /etc/passwd.
    local passwd_source
    if command -v getent >/dev/null 2>&1; then
        passwd_source="getent passwd"
    else
        passwd_source="cat /etc/passwd"
    fi

    eval "$passwd_source" | while IFS=: read -r name _ uid gid gecos home shell; do
        # The GECOS field is not included because it often contains personal data.
        # This baseline is for operational drift checks, not HR documentation.
        status="$(password_status_for_user "$name")"
        printf 'user\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$uid" "$gid" "$home" "$shell" "$status"
    done
}

emit_groups() {
    local group_source
    if command -v getent >/dev/null 2>&1; then
        group_source="getent group"
    else
        group_source="cat /etc/group"
    fi

    eval "$group_source" | while IFS=: read -r name _ gid members; do
        printf 'group\t%s\t%s\t%s\t-\t-\t-\n' "$name" "$gid" "${members:-}"
    done
}

{
    if [[ "$INCLUDE_HEADER" == "yes" ]]; then
        emit_header
    fi
    {
        emit_users
        emit_groups
    } | sort
} > "$TMP_OUT"

if [[ "$OUTPUT" == "-" ]]; then
    cat "$TMP_OUT"
else
    cp "$TMP_OUT" "$OUTPUT" || { echo "ERROR: Cannot write output: $OUTPUT" >&2; exit 1; }
fi
