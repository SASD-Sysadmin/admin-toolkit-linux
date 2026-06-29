#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# File: scripts/network/sasd-forward-reverse-dns-check.sh
# Purpose: Compare forward and reverse DNS for a list of hostnames.
#
# This is a defensive documentation and operations helper. It does not scan a
# network. It only checks names that you explicitly provide.
#
# Typical usage:
#   ./scripts/network/sasd-forward-reverse-dns-check.sh example.org www.example.org
#   ./scripts/network/sasd-forward-reverse-dns-check.sh --file hosts.txt --format markdown
#

set -o nounset
set -o pipefail

VERSION="0.1.0"
FORMAT="text"
HOST_FILE=""
HOSTS=()

usage() {
    cat <<USAGE
sasd-forward-reverse-dns-check.sh ${VERSION}

Compare forward and reverse DNS for explicit hostnames.

Usage:
  sasd-forward-reverse-dns-check.sh [options] HOST [HOST...]

Options:
  --file PATH          Read hostnames from PATH, one per line.
  --format FORMAT      Output format: text or markdown. Default: text
  --help               Show this help text.
  --version            Show version.

Exit codes:
  0  All checked hostnames have matching reverse DNS or no hard mismatch.
  1  Invalid arguments or no hosts provided.
  2  One or more mismatches or lookup failures were found.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            [[ $# -ge 2 ]] || { echo "ERROR: --file requires a path" >&2; exit 1; }
            HOST_FILE="$2"
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
        --)
            shift
            while [[ $# -gt 0 ]]; do HOSTS+=("$1"); shift; done
            ;;
        -*)
            echo "ERROR: Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            HOSTS+=("$1")
            shift
            ;;
    esac
done

case "$FORMAT" in
    text|markdown) ;;
    *) echo "ERROR: Unsupported format: $FORMAT" >&2; exit 1 ;;
esac

if [[ -n "$HOST_FILE" ]]; then
    [[ -r "$HOST_FILE" ]] || { echo "ERROR: Cannot read host file: $HOST_FILE" >&2; exit 1; }
    while IFS= read -r line; do
        # Trim comments and whitespace.
        line="${line%%#*}"
        line="$(printf '%s' "$line" | xargs 2>/dev/null || true)"
        [[ -n "$line" ]] && HOSTS+=("$line")
    done < "$HOST_FILE"
fi

[[ "${#HOSTS[@]}" -gt 0 ]] || { echo "ERROR: No hostnames provided" >&2; usage >&2; exit 1; }

lookup_ips() {
    local host="$1"
    if command -v getent >/dev/null 2>&1; then
        getent ahosts "$host" | awk '{print $1}' | grep -E '^[0-9a-fA-F:.]+$' | sort -u
    elif command -v host >/dev/null 2>&1; then
        host "$host" 2>/dev/null | awk '/has address|has IPv6 address/ {print $NF}' | sort -u
    else
        echo "ERROR: need getent or host command" >&2
        return 1
    fi
}

reverse_name() {
    local ip="$1"
    if command -v getent >/dev/null 2>&1; then
        getent hosts "$ip" | awk '{print $2}' | head -n 1
    elif command -v host >/dev/null 2>&1; then
        host "$ip" 2>/dev/null | awk '/domain name pointer/ {print $NF}' | sed 's/\.$//' | head -n 1
    fi
}

normalize_name() {
    printf '%s' "$1" | sed 's/\.$//' | tr '[:upper:]' '[:lower:]'
}

if [[ "$FORMAT" == "markdown" ]]; then
    echo "# SASD Forward/Reverse DNS Check"
    echo
    echo "- Generated: $(date -Is 2>/dev/null || date)"
    echo
    echo "| Status | Host | IP | Reverse name |"
    echo "|---|---|---|---|"
else
    echo "SASD Forward/Reverse DNS Check"
    echo "Generated: $(date -Is 2>/dev/null || date)"
    echo
fi

failures=0
for host in "${HOSTS[@]}"; do
    normalized_host="$(normalize_name "$host")"
    mapfile -t ips < <(lookup_ips "$host" || true)

    if [[ "${#ips[@]}" -eq 0 ]]; then
        failures=$((failures + 1))
        if [[ "$FORMAT" == "markdown" ]]; then
            printf '| WARN | `%s` | `-` | no forward lookup result |\n' "$host"
        else
            printf 'WARN host=%s ip=- reverse="no forward lookup result"\n' "$host"
        fi
        continue
    fi

    for ip in "${ips[@]}"; do
        rev="$(reverse_name "$ip" || true)"
        normalized_rev="$(normalize_name "$rev")"
        status="OK"
        [[ -n "$normalized_rev" ]] || status="WARN"

        # Exact reverse match is ideal. Aliases are common, so a mismatch is WARN,
        # not CRITICAL. This script documents drift; it does not enforce policy.
        if [[ -n "$normalized_rev" && "$normalized_rev" != "$normalized_host" ]]; then
            status="INFO"
        fi

        [[ "$status" == "WARN" ]] && failures=$((failures + 1))

        if [[ "$FORMAT" == "markdown" ]]; then
            printf '| %s | `%s` | `%s` | `%s` |\n' "$status" "$host" "$ip" "${rev:-none}"
        else
            printf '%-4s host=%s ip=%s reverse=%s\n' "$status" "$host" "$ip" "${rev:-none}"
        fi
    done
done

[[ "$failures" -eq 0 ]] || exit 2
exit 0
