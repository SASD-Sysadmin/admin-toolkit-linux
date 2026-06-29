# Database Inventory

This document covers conservative local database inventory checks.

## Script

- `scripts/database/sasd-mariadb-inventory.sh`

## Safety model

The script does not log into MariaDB or MySQL, does not use application
credentials and does not run SQL. It reports local binaries, package hints,
service state, common configuration paths, listener hints and data-directory
metadata.

Database names can reveal project or customer information. For that reason,
database-directory names are hidden by default.

## Usage

```bash
./scripts/database/sasd-mariadb-inventory.sh
```

Show readable database directory names only when appropriate:

```bash
./scripts/database/sasd-mariadb-inventory.sh --show-databases
```

## Review hints

Look for:

- installed but inactive database services
- active listeners on non-loopback interfaces
- multiple MySQL/MariaDB variants installed at the same time
- large data directories without matching backup evidence
- old project database names on development hosts
