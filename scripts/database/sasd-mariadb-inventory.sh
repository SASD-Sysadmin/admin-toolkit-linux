#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/database/sasd-mariadb-inventory.sh
# Purpose: Report local MariaDB/MySQL installation facts without logging in.
# Project: admin-toolkit-linux
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# This script is read-only. It does not connect with application credentials,
# run SQL, change services or inspect table data. It reports local binaries,
# packages, service state, common configuration paths and socket/listener hints.
#
# Privacy note
# ------------
# Database names and paths can reveal project/customer information. Therefore,
# database-directory names are hidden by default and only shown with
# --show-databases.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SHOW_DATABASES="no"
MAX_DATABASES="80"

show_help() {
    cat <<HELP
Usage: $SCRIPT_NAME [OPTIONS]

Report local MariaDB/MySQL installation facts without connecting to databases.

Options:
  --show-databases   Show readable database directory names below data dirs.
  --max-databases N  Maximum database names to show. Default: 80.
  -h, --help         Show this help text.

Examples:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --show-databases

Exit codes:
  0  Report completed.
  2  Invalid arguments.
HELP
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --show-databases)
            SHOW_DATABASES="yes"
            shift
            ;;
        --max-databases)
            [[ $# -ge 2 ]] || fail "--max-databases requires a number"
            [[ "$2" =~ ^[0-9]+$ ]] || fail "--max-databases must be numeric"
            MAX_DATABASES="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
done

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

file_meta() {
    local path="$1"
    if [[ -e "$path" ]]; then
        stat -c '%n owner=%U:%G mode=%a size=%s bytes mtime=%y' "$path" 2>/dev/null || ls -ld "$path" 2>/dev/null || true
    else
        printf 'MISSING: %s\n' "$path"
    fi
}

printf 'SASD MariaDB/MySQL Inventory\n'
printf 'Generated: %s\n' "$(date -Is)"
printf 'Host:      %s\n' "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
printf '\n'

printf '== Tool detection ==\n'
for tool in mariadb mysql mariadbd mysqld mysqladmin mariadb-admin systemctl ss dpkg rpm; do
    if command_exists "$tool"; then
        printf 'OK:   %-14s %s\n' "$tool" "$(command -v "$tool")"
    else
        printf 'MISS: %-14s not found\n' "$tool"
    fi
done
printf '\n'

printf '== Version hints ==\n'
for tool in mariadb mysql mariadbd mysqld; do
    if command_exists "$tool"; then
        printf '# %s --version\n' "$tool"
        "$tool" --version 2>&1 || true
    fi
done
printf '\n'

printf '== Package hints ==\n'
if command_exists dpkg; then
    dpkg-query -W -f='${binary:Package}\t${Version}\n' 'mariadb*' 'mysql*' 2>/dev/null | sort || true
elif command_exists rpm; then
    rpm -qa '*mariadb*' '*mysql*' 2>/dev/null | sort || true
else
    printf 'INFO: no supported package query tool found.\n'
fi
printf '\n'

printf '== Service state ==\n'
if command_exists systemctl; then
    for unit in mariadb.service mysql.service mysqld.service; do
        printf '%s enabled=%s active=%s\n' \
            "$unit" \
            "$(systemctl is-enabled "$unit" 2>/dev/null || echo unknown)" \
            "$(systemctl is-active "$unit" 2>/dev/null || echo unknown)"
    done
else
    printf 'INFO: systemctl not available.\n'
fi
printf '\n'

printf '== Common configuration paths ==\n'
for path in /etc/mysql /etc/mysql/my.cnf /etc/mysql/mariadb.conf.d /etc/my.cnf /etc/my.cnf.d; do
    file_meta "$path"
done
printf '\n'

printf '== Listener hints ==\n'
if command_exists ss; then
    ss -H -ltnp 2>/dev/null | awk '$4 ~ /:3306$/ || $4 ~ /:33060$/ { print }' || true
else
    printf 'INFO: ss not available.\n'
fi
printf '\n'

printf '== Data directory hints ==\n'
for dir in /var/lib/mysql /var/lib/mariadb; do
    if [[ -d "$dir" ]]; then
        file_meta "$dir"
        du -sh "$dir" 2>/dev/null || printf 'INFO: cannot calculate size for %s\n' "$dir"
        if [[ "$SHOW_DATABASES" == "yes" ]]; then
            printf '# database-like directories below %s\n' "$dir"
            find "$dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | head -n "$MAX_DATABASES"
        else
            count="$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | awk '{ print $1 }')"
            printf 'Readable database-like directory count: %s\n' "$count"
            printf 'INFO: names hidden by default. Use --show-databases if appropriate.\n'
        fi
    else
        printf 'MISSING: %s\n' "$dir"
    fi
    printf '\n'
done

exit 0
