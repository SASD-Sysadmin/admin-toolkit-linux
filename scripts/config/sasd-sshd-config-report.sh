#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# File: scripts/config/sasd-sshd-config-report.sh
# Purpose: Read-only SSH daemon configuration report for Linux hosts.
#
# This script is intentionally conservative:
# - It does not change sshd_config.
# - It does not restart or reload sshd.
# - It tries to use `sshd -T` for the effective configuration when available.
# - It falls back to parsing a config file when `sshd -T` is not available.
# - If OpenSSH server configuration is not present, it reports that fact instead
#   of aborting. This is important on WSL, containers and minimal lab systems.
#
# Why `sshd -T` matters:
# OpenSSH supports Include directives and distribution-specific defaults. Reading
# only /etc/ssh/sshd_config can miss settings from included files or built-in
# defaults. `sshd -T` prints the effective configuration as OpenSSH understands it.
#
# Typical usage:
#   ./scripts/config/sasd-sshd-config-report.sh
#   ./scripts/config/sasd-sshd-config-report.sh --format markdown
#   ./scripts/config/sasd-sshd-config-report.sh --config ./fixtures/sshd_config
#

set -o nounset
set -o pipefail

VERSION="0.1.1"
CONFIG_FILE="/etc/ssh/sshd_config"
FORMAT="text"
USE_EFFECTIVE="auto"

usage() {
    cat <<USAGE
sasd-sshd-config-report.sh ${VERSION}

Read-only SSH daemon configuration report.

Usage:
  sasd-sshd-config-report.sh [options]

Options:
  --config PATH        Parse this sshd_config file when not using sshd -T.
                       Default: /etc/ssh/sshd_config
  --effective          Force use of 'sshd -T'.
  --no-effective       Do not use 'sshd -T'; parse the config file only.
  --format FORMAT      Output format: text or markdown. Default: text
  --help               Show this help text.
  --version            Show version.

Exit codes:
  0  Report created. Findings are expressed in the report body.
  1  Invalid arguments or unsupported format.
  2  Requested effective mode failed.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            [[ $# -ge 2 ]] || { echo "ERROR: --config requires a path" >&2; exit 1; }
            CONFIG_FILE="$2"
            shift 2
            ;;
        --effective)
            USE_EFFECTIVE="yes"
            shift
            ;;
        --no-effective)
            USE_EFFECTIVE="no"
            shift
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

# Store configuration as lower-case key=value lines in a temporary file.
# We avoid bash associative arrays to keep the script easy to read and review.
TMP_CONFIG="$(mktemp)"
trap 'rm -f "$TMP_CONFIG"' EXIT

can_use_effective() {
    command -v sshd >/dev/null 2>&1 || return 1

    # Some systems require additional runtime paths or host keys before sshd -T
    # succeeds. We only use it when it works cleanly. Otherwise we fall back to
    # file parsing or a "not present" report.
    "$(command -v sshd)" -T >/dev/null 2>&1
}

load_effective_config() {
    "$(command -v sshd)" -T 2>/dev/null |
        awk '{print tolower($1) "=" substr($0, index($0,$2))}' > "$TMP_CONFIG"
}

load_file_config() {
    local file="$1"
    [[ -r "$file" ]] || return 1

    # This parser is deliberately simple. It reads explicit key/value pairs from
    # one file and ignores comments. It does not expand Include directives. That
    # is why `sshd -T` is preferred when available.
    awk '
        /^[[:space:]]*($|#)/ { next }
        {
            key=tolower($1)
            $1=""
            sub(/^[[:space:]]+/, "", $0)
            print key "=" $0
        }
    ' "$file" > "$TMP_CONFIG"
}

SOURCE=""
NO_CONFIG="false"

if [[ "$USE_EFFECTIVE" == "yes" ]]; then
    if can_use_effective; then
        load_effective_config
        SOURCE="effective configuration from sshd -T"
    else
        echo "ERROR: sshd -T is not available or failed" >&2
        exit 2
    fi
elif [[ "$USE_EFFECTIVE" == "auto" ]] && can_use_effective; then
    load_effective_config
    SOURCE="effective configuration from sshd -T"
else
    if load_file_config "$CONFIG_FILE"; then
        SOURCE="parsed file: $CONFIG_FILE"
    else
        SOURCE="OpenSSH server configuration not readable or not present: $CONFIG_FILE"
        NO_CONFIG="true"
        : > "$TMP_CONFIG"
    fi
fi

get_value() {
    local key="$1"
    # Keep the last occurrence. In sshd_config, later values can override earlier
    # values in some contexts; with sshd -T there should normally be one value.
    grep -E "^${key}=" "$TMP_CONFIG" | tail -n 1 | cut -d= -f2-
}

status_for_setting() {
    local key="$1"
    local value="$2"

    if [[ "$NO_CONFIG" == "true" ]]; then
        echo "INFO"
        return 0
    fi

    case "$key" in
        permitrootlogin)
            case "$value" in
                no) echo "OK" ;;
                prohibit-password|without-password) echo "WARN" ;;
                yes) echo "WARN" ;;
                not\ set) echo "INFO" ;;
                *) echo "INFO" ;;
            esac
            ;;
        passwordauthentication|kbdinteractiveauthentication|challengeresponseauthentication)
            [[ "$value" == "no" ]] && echo "OK" || echo "WARN"
            ;;
        pubkeyauthentication)
            [[ "$value" == "yes" ]] && echo "OK" || echo "WARN"
            ;;
        x11forwarding|allowtcpforwarding)
            [[ "$value" == "no" ]] && echo "OK" || echo "INFO"
            ;;
        maxauthtries)
            if [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -le 4 ]]; then echo "OK"; else echo "INFO"; fi
            ;;
        *)
            echo "INFO"
            ;;
    esac
}

print_text_header() {
    echo "SASD SSHD Configuration Report"
    echo "Generated: $(date -Is 2>/dev/null || date)"
    echo "Host:      $(hostname 2>/dev/null || echo unknown)"
    echo "Source:    $SOURCE"
    echo
}

print_markdown_header() {
    echo "# SASD SSHD Configuration Report"
    echo
    echo "- Generated: $(date -Is 2>/dev/null || date)"
    echo "- Host: $(hostname 2>/dev/null || echo unknown)"
    echo "- Source: $SOURCE"
    echo
    echo "| Status | Setting | Value | Note |"
    echo "|---|---|---|---|"
}

note_for_setting() {
    local key="$1"

    if [[ "$NO_CONFIG" == "true" ]]; then
        echo "No sshd configuration was readable. OpenSSH server may be absent, disabled, containerized or not installed."
        return 0
    fi

    case "$key" in
        permitrootlogin) echo "Root login should normally be disabled or limited." ;;
        passwordauthentication) echo "Password login increases brute-force exposure on internet-facing hosts." ;;
        pubkeyauthentication) echo "Public-key authentication should normally be enabled." ;;
        kbdinteractiveauthentication|challengeresponseauthentication) echo "Interactive password mechanisms are often disabled on hardened hosts." ;;
        x11forwarding) echo "Usually unnecessary on servers." ;;
        allowtcpforwarding) echo "May be needed for jump hosts; otherwise review." ;;
        maxauthtries) echo "Lower values reduce brute-force attempts per connection." ;;
        loglevel) echo "VERBOSE can help with key fingerprint logging; INFO is common default." ;;
        allowusers|allowgroups) echo "Allow-lists can reduce SSH exposure when maintained carefully." ;;
        *) echo "Review according to local policy." ;;
    esac
}

SETTINGS=(
    permitrootlogin
    passwordauthentication
    pubkeyauthentication
    kbdinteractiveauthentication
    challengeresponseauthentication
    x11forwarding
    allowtcpforwarding
    maxauthtries
    loglevel
    allowusers
    allowgroups
)

if [[ "$FORMAT" == "markdown" ]]; then
    print_markdown_header
else
    print_text_header
fi

for key in "${SETTINGS[@]}"; do
    value="$(get_value "$key")"
    [[ -n "$value" ]] || value="not set"
    status="$(status_for_setting "$key" "$value")"
    note="$(note_for_setting "$key")"

    if [[ "$FORMAT" == "markdown" ]]; then
        printf '| %s | `%s` | `%s` | %s |\n' "$status" "$key" "$value" "$note"
    else
        printf '%-5s %-34s %s\n' "$status" "$key" "$value"
        printf '      %s\n' "$note"
    fi
done

if [[ "$NO_CONFIG" == "true" ]]; then
    echo
    if [[ "$FORMAT" == "markdown" ]]; then
        echo "> Note: No readable OpenSSH server configuration was found. This can be normal on WSL, containers or systems without openssh-server."
    else
        echo "NOTE: No readable OpenSSH server configuration was found. This can be normal on WSL, containers or systems without openssh-server."
    fi
elif [[ "$SOURCE" == parsed* ]]; then
    echo
    if [[ "$FORMAT" == "markdown" ]]; then
        echo "> Note: This report parsed one config file. Use '--effective' on hosts where sshd -T is available to include OpenSSH defaults and Include directives."
    else
        echo "NOTE: This report parsed one config file. Use --effective on hosts where sshd -T is available."
    fi
fi
