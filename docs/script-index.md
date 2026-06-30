# Script Index

This document lists the current scripts in `admin-toolkit-linux` and explains
their intended use.

The project favors small, readable scripts. Most scripts are read-only and
produce text, Markdown or TSV output that can be reviewed manually or collected
by `scripts/reporting/sasd-run-readonly-checks.sh`.

## Exit status convention

The current scripts use this general convention:

| Exit status | Meaning |
| ---: | --- |
| `0` | Command completed successfully. Output may still contain informational findings. |
| `1` | Findings were detected by an audit-style script, or a monitoring-style check is warning/critical depending on the script. |
| `2+` | Execution problem, missing prerequisite, invalid arguments or unexpected error. |

Always read the script output. An exit status alone is not a security assessment.

## Privilege expectations

Many scripts are useful as a normal user. Some reports are more complete when
run as root because protected directories or log files may otherwise be skipped.
See [docs/privilege-expectations.md](privilege-expectations.md).

## Accounts

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/accounts/sasd-account-baseline.sh` | Exports local user and group facts without password hashes. | TSV |
| `scripts/accounts/sasd-account-diff.sh` | Compares two account baselines. | Text |

Example:

```bash
./scripts/accounts/sasd-account-baseline.sh > /tmp/accounts-before.tsv
./scripts/accounts/sasd-account-diff.sh --old /tmp/accounts-before.tsv --new /tmp/accounts-before.tsv
```

## Backup

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/backup/sasd-backup-age-check.sh` | Checks whether matching backup files exist and are recent enough. | Text |
| `scripts/backup/sasd-backup-location-report.sh` | Reviews backup locations, mount context and newest visible files. | Markdown |
| `scripts/backup/sasd-backup-manifest.sh` | Creates a lightweight metadata manifest for visible backup files. | TSV/Markdown |
| `scripts/backup/sasd-restore-drill-plan.sh` | Generates a non-destructive restore drill checklist. | Markdown |
| `scripts/backup/sasd-rsync-snapshot.sh` | Conservative rsync snapshot helper, dry-run by default. | Text |

Example:

```bash
./scripts/backup/sasd-backup-age-check.sh --path /backup --pattern '*.tar.gz' --max-age-days 2
./scripts/reporting/sasd-run-backup-review.sh --path /backup --pattern '*.tar.gz' --service mariadb
```

## Configuration

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/config/sasd-browser-repo-report.sh` | Reports browser/vendor package repositories and keyring hints. | Text |
| `scripts/config/sasd-cron-report.sh` | Reports cron configuration, drop-ins and user crontab metadata. | Text |
| `scripts/config/sasd-journald-config-report.sh` | Reviews journald configuration and journal directory state. | Text |
| `scripts/config/sasd-logrotate-report.sh` | Reviews logrotate policy and drop-in files. | Text |
| `scripts/config/sasd-sshd-config-report.sh` | Reports OpenSSH server settings when readable. | Text |
| `scripts/config/sasd-sudoers-report.sh` | Validates and reviews sudoers configuration. | Text |
| `scripts/config/sasd-systemd-timers-report.sh` | Reports systemd timer state and timer unit files. | Text |

Example:

```bash
./scripts/config/sasd-sudoers-report.sh
```

## Database

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/database/sasd-mariadb-inventory.sh` | Reports local MariaDB/MySQL installation facts without login. | Text |
| `scripts/database/sasd-postgresql-inventory.sh` | Reports local PostgreSQL installation facts without database login. | Text |

Example:

```bash
./scripts/database/sasd-mariadb-inventory.sh
./scripts/database/sasd-postgresql-inventory.sh
```

## Filesystem

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/filesystem/sasd-deleted-open-files.sh` | Finds deleted files still held open by processes. | Text |
| `scripts/filesystem/sasd-disk-usage-report.sh` | Reports disk usage and large filesystem areas. | Markdown |

## Host documentation

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/host-doc/sasd-host-inventory.sh` | Creates a basic host inventory. | Markdown |
| `scripts/host-doc/sasd-network-inventory.sh` | Reports interfaces, addresses, routes, resolver context and network manager hints. | Markdown |
| `scripts/host-doc/sasd-package-inventory.sh` | Lists installed packages. | Text/Markdown |
| `scripts/host-doc/sasd-service-inventory.sh` | Lists services where supported. | Text/Markdown |
| `scripts/host-doc/sasd-storage-inventory.sh` | Reports mounts, filesystems, block devices, swap and storage tool hints. | Markdown |
| `scripts/reporting/sasd-run-host-inventory.sh` | Runs the focused host inventory collection. | Directory with reports |

Example:

```bash
./scripts/reporting/sasd-run-host-inventory.sh --output ./reports/host-inventory-local
./scripts/host-doc/sasd-network-inventory.sh --max-lines 80
./scripts/host-doc/sasd-storage-inventory.sh --show-blkid --max-lines 80
```

## Logging

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/logging/sasd-auth-log-report.sh` | Summarizes authentication log signals. | Text |
| `scripts/logging/sasd-journal-errors.sh` | Reviews recent journal warnings and errors. | Markdown/Text |
| `scripts/logging/sasd-kernel-warnings.sh` | Reviews kernel warnings from journald and dmesg fallback output. | Markdown |
| `scripts/logging/sasd-log-volume-report.sh` | Reports visible log volume and journald disk usage. | Markdown |
| `scripts/logging/sasd-sudo-usage-report.sh` | Summarizes sudo usage from journald and auth logs. | Markdown |

Example:

```bash
./scripts/logging/sasd-sudo-usage-report.sh --since today --max-lines 80
./scripts/logging/sasd-kernel-warnings.sh --since today --max-lines 80
./scripts/logging/sasd-log-volume-report.sh --max-lines 40
```

## Monitoring

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/monitoring/check_certificate_expiry.sh` | Checks certificate expiry in monitoring-plugin style. | Text |
| `scripts/monitoring/check_disk_usage.sh` | Checks disk usage thresholds. | Text |
| `scripts/monitoring/check_inodes.sh` | Checks inode usage thresholds. | Text |
| `scripts/monitoring/check_reboot_required.sh` | Checks common reboot-required indicators. | Text |
| `scripts/monitoring/check_service_active.sh` | Checks whether a service is active. | Text |
| `scripts/reporting/sasd-run-monitoring-review.sh` | Runs the focused monitoring review collection. | Directory with reports |

Example:

```bash
./scripts/monitoring/check_disk_usage.sh --path / --warning 80 --critical 90
./scripts/monitoring/check_inodes.sh --path / --warning 80 --critical 90
./scripts/reporting/sasd-run-monitoring-review.sh --path / --service cron.service --output ./reports/monitoring-local
```

## Network

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/network/sasd-forward-reverse-dns-check.sh` | Checks forward and reverse DNS consistency. | Text |
| `scripts/network/sasd-listening-services-report.sh` | Reports listening TCP/UDP sockets and bind scope. | Text |

## Packages

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/packages/sasd-reboot-required-report.sh` | Reports common reboot-required indicators. | Text |
| `scripts/packages/sasd-update-status-report.sh` | Reports package update status for supported package managers. | Text |

## Reporting

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/reporting/sasd-admin-summary.sh` | Generates a Markdown admin summary from selected checks. | Markdown |
| `scripts/reporting/sasd-findings-summary.sh` | Generates a compact triage findings summary. | Markdown |
| `scripts/reporting/sasd-release-readiness.sh` | Checks local repository readiness before tagging. | Markdown |
| `scripts/reporting/sasd-run-fim-review.sh` | Runs the focused file integrity monitoring review collection. | Directory with reports |
| `scripts/reporting/sasd-run-logging-review.sh` | Runs a focused logging review collection. | Directory with reports |
| `scripts/reporting/sasd-run-monitoring-review.sh` | Runs a focused monitoring review collection. | Directory with reports |
| `scripts/reporting/sasd-run-readonly-checks.sh` | Runs a broad read-only check collection and creates an index. | Directory with reports |
| `scripts/reporting/sasd-security-summary.sh` | Generates a Markdown security summary from selected checks. | Markdown |

Recommended usage:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --output ./reports/local-test
./scripts/reporting/sasd-run-logging-review.sh --since today --output ./reports/logging-review
./scripts/reporting/sasd-run-monitoring-review.sh --path / --output ./reports/monitoring-review
./scripts/reporting/sasd-run-fim-review.sh --path /etc/hosts --output ./reports/fim-review
```

## Security

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/security/sasd-auditd-status-report.sh` | Reports auditd/auditctl state and audit rule visibility. | Text |
| `scripts/security/sasd-firewall-status-report.sh` | Reports firewall tooling and rule summary. | Text |
| `scripts/security/sasd-fim-baseline.sh` | Creates a file integrity baseline. | TSV |
| `scripts/security/sasd-fim-check.sh` | Compares files with a FIM baseline. | Text |
| `scripts/security/sasd-open-ports-audit.sh` | Reports open/listening ports. | Markdown/Text |
| `scripts/security/sasd-permission-risk-report.sh` | Reports sensitive permission risks with symlink-aware handling. | Markdown |
| `scripts/security/sasd-root-owned-writable-report.sh` | Reports root-owned files/directories with group or other write bits. | Markdown |
| `scripts/security/sasd-sensitive-files-check.sh` | Checks sensitive system file permissions. | Text |
| `scripts/security/sasd-ssh-baseline-check.sh` | Compares SSH server config with a small baseline. | Markdown |
| `scripts/security/sasd-suid-sgid-audit.sh` | Lists SUID/SGID files. | Markdown/Text |
| `scripts/security/sasd-symlink-target-report.sh` | Reports symlink metadata and target metadata separately. | Markdown |
| `scripts/security/sasd-system-accounts-audit.sh` | Reports suspicious system-account properties. | Markdown |
| `scripts/security/sasd-world-writable-audit.sh` | Reports world-writable filesystem entries with filtering. | Markdown/Text/TSV |

Example with filtering:

```bash
./scripts/security/sasd-world-writable-audit.sh --path / --exclude /opt/nodejs --max-results 200
```
