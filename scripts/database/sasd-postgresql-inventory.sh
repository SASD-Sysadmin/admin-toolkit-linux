#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: scripts/database/sasd-postgresql-inventory.sh
# Project: admin-toolkit-linux
# Purpose: Read-only inventory for PostgreSQL installations.
# License: MIT
# -----------------------------------------------------------------------------
# Safety model
# ------------
# Read-only. This script does not connect with write statements, does not change
# roles, does not dump data and does not edit configuration. Optional database
# names are hidden by default.
# -----------------------------------------------------------------------------

set -u
set -o pipefail

SHOW_DATABASES=0
SHOW_CONFIG_SNIPPETS=0
MAX_LINES=120

usage() {
  cat <<'USAGE'
Usage:
  sasd-postgresql-inventory.sh [options]

Options:
  --show-databases       Try to print database names if local access permits it.
  --show-config          Print limited PostgreSQL config snippets.
  --max-lines N          Limit config snippet lines. Default: 120.
  -h, --help             Show this help.

Examples:
  ./scripts/database/sasd-postgresql-inventory.sh
  ./scripts/database/sasd-postgresql-inventory.sh --show-databases
USAGE
}

log_error() { printf 'ERROR: %s\n' "$*" >&2; }
is_uint() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --show-databases) SHOW_DATABASES=1; shift ;;
    --show-config) SHOW_CONFIG_SNIPPETS=1; shift ;;
    --max-lines)
      [ "$#" -ge 2 ] || { log_error "--max-lines requires a value"; exit 2; }
      is_uint "$2" || { log_error "--max-lines must be numeric"; exit 2; }
      MAX_LINES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

HOSTNAME_VALUE="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
GENERATED_AT="$(date -Iseconds)"

printf 'SASD PostgreSQL Inventory\n'
printf 'Generated: %s\n' "$GENERATED_AT"
printf 'Host:      %s\n\n' "$HOSTNAME_VALUE"

printf '== Tool detection ==\n'
for tool in psql postgres pg_ctlcluster pg_lsclusters systemctl ss dpkg-query rpm; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'OK:   %-14s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf 'MISS: %-14s not found\n' "$tool"
  fi
done

printf '\n== Version hints ==\n'
if command -v psql >/dev/null 2>&1; then
  printf '# psql --version\n'
  psql --version 2>/dev/null || true
fi
if command -v postgres >/dev/null 2>&1; then
  printf '# postgres --version\n'
  postgres --version 2>/dev/null || true
fi

printf '\n== Package hints ==\n'
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 'postgresql*' 'libpq*' 2>/dev/null | awk 'NF >= 2 {print}' | sort -u || true
elif command -v rpm >/dev/null 2>&1; then
  rpm -qa | grep -Ei '^postgresql|libpq' | sort || true
else
  printf 'INFO: no supported package query tool found.\n'
fi

printf '\n== Service state ==\n'
if command -v systemctl >/dev/null 2>&1; then
  for svc in postgresql.service postgresql@.service; do
    enabled="$(systemctl is-enabled "$svc" 2>/dev/null || printf 'unknown')"
    active="$(systemctl is-active "$svc" 2>/dev/null || printf 'inactive')"
    printf '%-24s enabled=%s active=%s\n' "$svc" "$enabled" "$active"
  done
else
  printf 'INFO: systemctl not available.\n'
fi

printf '\n== Cluster hints ==\n'
if command -v pg_lsclusters >/dev/null 2>&1; then
  pg_lsclusters 2>/dev/null || true
else
  printf 'INFO: pg_lsclusters not available.\n'
fi

printf '\n== Common configuration paths ==\n'
for path in /etc/postgresql /etc/postgresql-common /etc/postgresql/*/*/postgresql.conf /etc/postgresql/*/*/pg_hba.conf /etc/postgresql/*/*/pg_ident.conf; do
  for item in $path; do
    if [ -e "$item" ] || [ -L "$item" ]; then
      stat -c '%n owner=%U:%G mode=%a size=%s mtime=%y' "$item" 2>/dev/null || printf '%s\n' "$item"
    fi
  done
done

printf '\n== Listener hints ==\n'
if command -v ss >/dev/null 2>&1; then
  ss -H -tulpen 2>/dev/null | awk '$0 ~ /:5432[[:space:]]/ || $0 ~ /postgres/ {print}' || true
else
  printf 'INFO: ss not available.\n'
fi

printf '\n== Data directory hints ==\n'
for dir in /var/lib/postgresql /var/lib/pgsql; do
  if [ -d "$dir" ]; then
    stat -c '%n owner=%U:%G mode=%a size=%s mtime=%y' "$dir" 2>/dev/null || printf '%s\n' "$dir"
    du -sh "$dir" 2>/dev/null || printf 'INFO: cannot calculate size for %s\n' "$dir"
  else
    printf 'MISSING: %s\n' "$dir"
  fi
done

if [ "$SHOW_DATABASES" -eq 1 ]; then
  printf '\n== Database names, if local access permits ==\n'
  if command -v psql >/dev/null 2>&1; then
    # Try unprivileged local access first. Do not use sudo here; the script stays
    # explicit and non-escalating.
    psql -Atqc "select datname from pg_database where datistemplate = false order by datname;" 2>/dev/null || \
      printf 'INFO: could not query database names with current user.\n'
  else
    printf 'INFO: psql not available.\n'
  fi
else
  printf '\nINFO: database names hidden by default. Use --show-databases if appropriate.\n'
fi

if [ "$SHOW_CONFIG_SNIPPETS" -eq 1 ]; then
  printf '\n== Limited configuration snippets ==\n'
  for cfg in /etc/postgresql/*/*/postgresql.conf /etc/postgresql/*/*/pg_hba.conf; do
    [ -f "$cfg" ] || continue
    printf '\n# %s\n' "$cfg"
    sed -n "1,${MAX_LINES}p" "$cfg" 2>/dev/null || true
  done
fi

exit 0
