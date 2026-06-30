# SASD Backup Review Collection

- Generated: 2026-01-01T10:00:00+01:00
- Host: example-host
- Repository root: `/path/to/admin-toolkit-linux`
- Output directory: `./reports/backup-review-example`
- Backup path/reference: `/backup`
- Pattern: `*.tar.gz`
- Max age days: 7
- Min count: 1

> This collection is read-only. It does not restore, copy, delete, mount,
> rotate, compress or change backup files. It makes backup and restore
testability visible for human review.

## Command status

| Status | Script | Output |
| ---: | --- | --- |
| 0 | `scripts/backup/sasd-backup-age-check.sh` | [`01-backup-age-check.md`](01-backup-age-check.md) |
| 0 | `scripts/backup/sasd-backup-location-report.sh` | [`02-backup-location-report.md`](02-backup-location-report.md) |
| 0 | `scripts/backup/sasd-backup-manifest.sh` | [`03-backup-manifest.tsv`](03-backup-manifest.tsv) |
| 0 | `scripts/backup/sasd-restore-drill-plan.sh` | [`10-restore-drill-plan.md`](10-restore-drill-plan.md) |

## Suggested review order

1. Open `01-backup-age-check.md` to see whether recent files are visible.
2. Open `02-backup-location-report.md` to review path, mount and newest-file context.
3. Open `03-backup-manifest.tsv` if a lightweight file manifest is useful.
4. Use `10-restore-drill-plan.md` to plan a non-production restore validation.
