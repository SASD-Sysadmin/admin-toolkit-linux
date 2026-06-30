# Backup Age Check

`scripts/backup/sasd-backup-age-check.sh` checks whether a configured backup or
snapshot directory contains recent matching files.

The script is read-only. It only reads directory metadata and file timestamps. It
does not validate that a backup can be restored. A real restore test remains a
separate operational task.

## Why the default changed

The generic read-only collector can run on many hosts where no backup directory
is known. In that situation, the backup age check now reports `INFO: no backup
path configured` and exits with status `0`.

This avoids a misleading execution failure in the collector. A missing backup
configuration is still visible in the report, but it is not treated as a script
error.

## Usage

```bash
./scripts/backup/sasd-backup-age-check.sh --path /backup --pattern '*.tar.gz' --max-age-days 2
```

Environment variables can be used for local policy defaults:

```bash
export SASD_BACKUP_CHECK_PATH=/backup
export SASD_BACKUP_CHECK_PATTERN='*.tar.gz'
export SASD_BACKUP_CHECK_MAX_AGE_DAYS=2
./scripts/backup/sasd-backup-age-check.sh
```

## Exit codes

| Code | Meaning |
| ---: | --- |
| 0 | Check completed and policy is satisfied, or no backup path is configured. |
| 1 | Check completed, but count or age policy is not satisfied. |
| 2 | Invalid arguments or configured path cannot be scanned. |

## Review notes

A fresh file does not prove that the backup is usable. A mature backup process
also needs restore tests, integrity checks, retention review and off-host/offline
coverage.
