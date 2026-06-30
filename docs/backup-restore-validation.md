# Backup and Restore Validation

This document describes the `admin-toolkit-linux` approach to backup and restore
validation.

The key rule is simple:

> A backup that has not been restored is only a backup candidate.

The scripts in this area are read-only. They do not copy, delete, rotate,
compress, mount, decrypt, repair or restore data. They help an administrator see
whether backup files are visible and whether a restore drill is planned well
enough to execute manually in a safe environment.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/backup/sasd-backup-age-check.sh` | Checks whether matching backup files exist and are recent enough. |
| `scripts/backup/sasd-backup-location-report.sh` | Reviews configured backup locations, mount context and newest visible files. |
| `scripts/backup/sasd-backup-manifest.sh` | Creates a lightweight metadata manifest for visible backup files. |
| `scripts/backup/sasd-restore-drill-plan.sh` | Generates a non-destructive restore drill checklist. |
| `scripts/reporting/sasd-run-backup-review.sh` | Runs a focused backup/restore review collection. |

## Typical workflow

```bash
./scripts/reporting/sasd-run-backup-review.sh \
  --path /backup \
  --pattern '*.tar.gz' \
  --max-age-days 2 \
  --service mariadb \
  --target 'temporary VM'
```

Then review:

1. `01-backup-age-check.md`
2. `02-backup-location-report.md`
3. `03-backup-manifest.tsv`
4. `10-restore-drill-plan.md`

## Why restore validation matters

Backup existence answers only one question: "Is something there?"

Restore validation answers more important questions:

- Is the selected backup readable?
- Is the expected data inside?
- Are ownership and permissions plausible after restore?
- Are credentials or encryption keys available?
- Can the application start after restore?
- How long does restore take?
- How much data loss would be expected?

## Read-only boundaries

The scripts deliberately do not perform the restore. Restore tests can be risky
because they may overwrite production data, expose secrets or trigger services in
an unsafe environment.

The expected pattern is:

1. Use the scripts to document backup state.
2. Generate a restore drill plan.
3. Perform the restore manually in an isolated test target.
4. Record the result and follow-up tasks.

## Privilege expectations

Non-root execution is useful for a quick review, but some backup locations may be
hidden or partially readable. This is not automatically a script failure.

Run as root only when needed for completeness and only after reviewing the
script. The scripts are still intended to be read-only when run as root.
