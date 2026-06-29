# Script Index

This document lists the current scripts in `admin-toolkit-linux` and explains their intended use.

The project favors small, readable scripts. Most scripts are read-only and produce text, Markdown or TSV output that can be reviewed manually or collected by `scripts/reporting/sasd-run-readonly-checks.sh`.

## Exit status convention

The current scripts use this general convention:

| Exit status | Meaning |
| ---: | --- |
| `0` | Command completed successfully. Output may still contain informational findings. |
| `1` | Findings were detected by an audit-style script, or a monitoring-style check is warning/critical depending on the script. |
| `2+` | Execution problem, missing prerequisite, invalid arguments or unexpected error. |

Always read the script output. An exit status alone is not a security assessment.

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
| `scripts/backup/sasd-rsync-snapshot.sh` | Conservative rsync snapshot helper, dry-run by default. | Text |

Example:

```bash
./scripts/backup/sasd-backup-age-check.sh --path /backup --pattern '*.tar.gz' --max-age-days 2
```

## Configuration

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/config/sasd-journald-config-report.sh` | Reviews journald configuration and journal directory state. | Text |
| `scripts/config/sasd-logrotate-report.sh` | Reviews logrotate policy and drop-in files. | Text |
| `scripts/config/sasd-cron-report.sh` | Reports cron configuration, drop-ins and user crontab metadata. | Text |
| `scripts/config/sasd-systemd-timers-report.sh` | Reports systemd timer state and timer unit files. | Text |
| `scripts/config/sasd-sshd-config-report.sh` | Reports OpenSSH server settings when readable. | Text |
| `scripts/config/sasd-sudoers-report.sh` | Validates and reviews sudoers configuration. | Text |

Example:

```bash
./scripts/config/sasd-sudoers-report.sh
```

## Database

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/database/sasd-mariadb-inventory.sh` | Reports local MariaDB/MySQL installation facts without login. | Text |

Example:

```bash
./scripts/database/sasd-mariadb-inventory.sh
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
| `scripts/host-doc/sasd-package-inventory.sh` | Lists installed packages. | Text/Markdown |
| `scripts/host-doc/sasd-service-inventory.sh` | Lists services where supported. | Text/Markdown |

## Logging

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/logging/sasd-auth-log-report.sh` | Summarizes authentication log signals. | Text |
| `scripts/logging/sasd-journal-errors.sh` | Reviews recent journal warnings and errors. | Markdown/Text |

## Monitoring

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/monitoring/check_certificate_expiry.sh` | Checks certificate expiry in monitoring-plugin style. | Text |
| `scripts/monitoring/check_disk_usage.sh` | Checks disk usage thresholds. | Text |
| `scripts/monitoring/check_reboot_required.sh` | Checks common reboot-required indicators. | Text |
| `scripts/monitoring/check_service_active.sh` | Checks whether a service is active. | Text |

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
| `scripts/reporting/sasd-run-readonly-checks.sh` | Runs a read-only check collection and creates an index. | Directory with reports |
| `scripts/reporting/sasd-security-summary.sh` | Generates a Markdown security summary from selected checks. | Markdown |

Recommended usage:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --output ./reports/local-test
```

## Security

| Script | Purpose | Typical output |
| --- | --- | --- |
| `scripts/security/sasd-auditd-status-report.sh` | Reports auditd/auditctl state and audit rule visibility. | Text |
| `scripts/security/sasd-firewall-status-report.sh` | Reports firewall tooling and rule summary. | Text |
| `scripts/security/sasd-fim-baseline.sh` | Creates a file integrity baseline. | TSV |
| `scripts/security/sasd-fim-check.sh` | Compares files with a FIM baseline. | Text |
| `scripts/security/sasd-open-ports-audit.sh` | Reports open/listening ports. | Markdown/Text |
| `scripts/security/sasd-sensitive-files-check.sh` | Checks sensitive system file permissions. | Text |
| `scripts/security/sasd-ssh-baseline-check.sh` | Compares SSH server config with a small baseline. | Markdown |
| `scripts/security/sasd-suid-sgid-audit.sh` | Lists SUID/SGID files. | Markdown/Text |
| `scripts/security/sasd-system-accounts-audit.sh` | Reports suspicious system-account properties. | Markdown |
| `scripts/security/sasd-world-writable-audit.sh` | Reports world-writable filesystem entries with filtering. | Markdown/Text/TSV |

Example with filtering:

```bash
./scripts/security/sasd-world-writable-audit.sh --path / --exclude /opt/nodejs --max-results 200
```
