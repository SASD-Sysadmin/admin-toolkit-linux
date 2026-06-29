# Phase 2: Operational Scripts

Phase 2 adds practical, read-mostly operational scripts around filesystem audits,
authentication log review, file integrity monitoring, monitoring checks and
backup snapshot templates.

## Added script areas

```text
scripts/filesystem/
scripts/security/
scripts/logging/
scripts/monitoring/
scripts/backup/
```

## Added scripts

| Script | Purpose | Default safety model |
| --- | --- | --- |
| `scripts/filesystem/sasd-disk-usage-report.sh` | Markdown disk usage report with thresholds | read-only |
| `scripts/filesystem/sasd-deleted-open-files.sh` | Find deleted files still held open by processes | read-only |
| `scripts/security/sasd-system-accounts-audit.sh` | Find system accounts with interactive shells | read-only |
| `scripts/security/sasd-sensitive-files-check.sh` | Find likely secret filenames before publishing | read-only |
| `scripts/security/sasd-fim-baseline.sh` | Create a file integrity baseline | writes only requested baseline output |
| `scripts/security/sasd-fim-check.sh` | Compare files against a FIM baseline | read-only |
| `scripts/logging/sasd-auth-log-report.sh` | Summarize auth, SSH, sudo and su activity | read-only |
| `scripts/monitoring/check_disk_usage.sh` | Monitoring-style disk usage plugin | read-only |
| `scripts/backup/sasd-rsync-snapshot.sh` | Timestamped rsync snapshot template | dry-run by default, apply required |

## Quality expectations

All scripts should provide:

- `--help`
- `--version`
- defensive argument handling
- readable comments
- predictable exit codes
- no hard-coded customer data
- no automatic destructive repair actions
