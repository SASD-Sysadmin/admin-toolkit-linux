#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# File: scripts/accounts/sasd-account-diff.sh
# Purpose: Compare two account baseline TSV files.
#
# The script compares complete baseline rows. A changed user therefore appears as
# one removed row and one added row. This simple approach is intentional: it keeps
# the tool easy to audit and avoids hiding important drift behind complicated logic.
#
# Typical usage:
#   ./scripts/accounts/sasd-account-baseline.sh > before.tsv
#   # make a change in a lab environment
#   ./scripts/accounts/sasd-account-baseline.sh > after.tsv
#   ./scripts/accounts/sasd-account-diff.sh --old before.tsv --new after.tsv
#

set -o nounset
set -o pipefail

VERSION="0.1.0"
OLD_FILE=""
NEW_FILE=""
FORMAT="text"

usage() {
    cat <<USAGE
sasd-account-diff.sh ${VERSION}

Compare two account baseline TSV files.

Usage:
  sasd-account-diff.sh --old OLD.tsv --new NEW.tsv [options]

Options:
  --old PATH           Previous baseline TSV file.
  --new PATH           Current baseline TSV file.
  --format FORMAT      Output format: text or markdown. Default: text
  --help               Show this help text.
  --version            Show version.

Exit codes:
  0  No differences found.
  1  Invalid arguments or read error.
  2  Differences found.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --old)
            [[ $# -ge 2 ]] || { echo "ERROR: --old requires a path" >&2; exit 1; }
            OLD_FILE="$2"
            shift 2
            ;;
        --new)
            [[ $# -ge 2 ]] || { echo "ERROR: --new requires a path" >&2; exit 1; }
            NEW_FILE="$2"
            shift 2
            ;;
        --format)
            [[ $# -ge 2 ]] || { echo "ERROR: --format requires a value" >&2; exit 1; }
            FORMAT="$2"
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

[[ -n "$OLD_FILE" && -n "$NEW_FILE" ]] || { usage >&2; exit 1; }
[[ -r "$OLD_FILE" ]] || { echo "ERROR: Cannot read old baseline: $OLD_FILE" >&2; exit 1; }
[[ -r "$NEW_FILE" ]] || { echo "ERROR: Cannot read new baseline: $NEW_FILE" >&2; exit 1; }

TMP_OLD="$(mktemp)"
TMP_NEW="$(mktemp)"
TMP_ADDED="$(mktemp)"
TMP_REMOVED="$(mktemp)"
trap 'rm -f "$TMP_OLD" "$TMP_NEW" "$TMP_ADDED" "$TMP_REMOVED"' EXIT

# Remove optional header lines and sort for stable comparison.
grep -Ev '^record_type[[:space:]]' "$OLD_FILE" | sort > "$TMP_OLD"
grep -Ev '^record_type[[:space:]]' "$NEW_FILE" | sort > "$TMP_NEW"

comm -13 "$TMP_OLD" "$TMP_NEW" > "$TMP_ADDED"
comm -23 "$TMP_OLD" "$TMP_NEW" > "$TMP_REMOVED"

added_count="$(wc -l < "$TMP_ADDED" | tr -d ' ')"
removed_count="$(wc -l < "$TMP_REMOVED" | tr -d ' ')"

if [[ "$FORMAT" == "markdown" ]]; then
    echo "# SASD Account Baseline Diff"
    echo
    echo "- Generated: $(date -Is 2>/dev/null || date)"
    printf -- '- Old baseline: `%s`\n' "$OLD_FILE"
    printf -- '- New baseline: `%s`\n' "$NEW_FILE"
    echo "- Added rows: $added_count"
    echo "- Removed rows: $removed_count"
    echo
    echo "## Added rows"
    echo
    echo '```text'
    cat "$TMP_ADDED"
    echo '```'
    echo
    echo "## Removed rows"
    echo
    echo '```text'
    cat "$TMP_REMOVED"
    echo '```'
else
    echo "SASD Account Baseline Diff"
    echo "Generated: $(date -Is 2>/dev/null || date)"
    echo "Old:       $OLD_FILE"
    echo "New:       $NEW_FILE"
    echo "Added:     $added_count"
    echo "Removed:   $removed_count"
    echo
    echo "== Added rows =="
    cat "$TMP_ADDED"
    echo
    echo "== Removed rows =="
    cat "$TMP_REMOVED"
fi

if [[ "$added_count" -eq 0 && "$removed_count" -eq 0 ]]; then
    exit 0
fi

exit 2
