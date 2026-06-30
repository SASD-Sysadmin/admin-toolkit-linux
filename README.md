# admin-toolkit-linux

Readable, conservative Linux administration scripts and documentation for
small-company operations, lab systems and portfolio use.

This repository is part of the SASD `admin-toolkit-*` repository family. It
focuses on Linux hosts first. Other Unix-like systems such as FreeBSD, macOS,
Solaris, OpenBSD or AIX should get their own repositories later when there is
enough material to make them useful and maintainable.

The repository starts as a focused sysadmin toolbox. It is intentionally small
enough to review, but useful enough to run on real lab or small-business Linux
hosts.

## Scope

Current focus:

- host documentation and inventory
- read-only security audit helpers
- Linux log and service review
- backup and restore validation review
- simple monitoring plugin examples
- account and configuration baselines
- file integrity baseline checks
- read-only report collection for repeatable local audits
- documentation patterns for repeatable administration

Later focus:

- deeper service-specific checks
- role-specific backup/restore expectations and evidence templates
- Ansible-based baseline configuration
- DNS, database and SNMP reporting helpers

## Design principles

- simple before clever
- readable before compact
- documented before magical
- read-only by default
- no secrets, no customer data, no internal IP addresses
- changes only with explicit `--apply`, where supported
- safe output formats for audits and examples
- small tools that can be reviewed before execution

## Quick start

Run a syntax check for all shell scripts:

```bash
make syntax
```

Run the local validation checks:

```bash
make check
```

Create a read-only report collection for the current host:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --output ./reports/local-test
```

Create a focused logging review:

```bash
./scripts/reporting/sasd-run-logging-review.sh --since today --output ./reports/logging-review
```

Create a focused backup and restore validation review:

```bash
./scripts/reporting/sasd-run-backup-review.sh --path /backup --pattern '*.tar.gz' --output ./reports/backup-review
```

Generated reports are intentionally written below `reports/`, which is ignored
by Git.

## Repository layout

```text
scripts/
  accounts/       Local account baselines and baseline comparisons
  backup/         Backup age, location, manifest and restore-drill helpers
  config/         Configuration reports for sshd, sudoers, journald, logrotate, cron and timers
  database/       Conservative local database inventory helpers
  filesystem/     Filesystem and open-deleted-file reports
  host-doc/       Host, service and package inventory
  logging/        Journal, sudo, kernel and log-volume review helpers
  monitoring/     Simple monitoring-plugin-style checks
  network/        DNS and listening-service reports
  packages/       Package update and reboot-required reports
  reporting/      Summary, readiness and collection scripts
  security/       Read-only security audit helpers

docs/             Documentation, runbooks and usage notes
examples/         Example outputs and sample baselines
reports/          Local generated reports, ignored by Git
```

## Script index

A detailed script index is available in [docs/script-index.md](docs/script-index.md).

| Category | Script | Purpose |
| --- | --- | --- |
| Accounts | `scripts/accounts/sasd-account-baseline.sh` | Export a local account/group baseline without password hashes. |
| Accounts | `scripts/accounts/sasd-account-diff.sh` | Compare two account baselines. |
| Backup | `scripts/backup/sasd-backup-age-check.sh` | Check whether matching backup files exist and are recent enough. |
| Backup | `scripts/backup/sasd-backup-location-report.sh` | Review backup locations, mount context and newest visible files. |
| Backup | `scripts/backup/sasd-backup-manifest.sh` | Create a lightweight metadata manifest for visible backup files. |
| Backup | `scripts/backup/sasd-restore-drill-plan.sh` | Generate a non-destructive restore drill checklist. |
| Backup | `scripts/backup/sasd-rsync-snapshot.sh` | Conservative rsync snapshot helper, dry-run by default. |
| Config | `scripts/config/sasd-browser-repo-report.sh` | Report browser/vendor package repositories and keyring hints. |
| Config | `scripts/config/sasd-cron-report.sh` | Report cron configuration and scheduled jobs. |
| Config | `scripts/config/sasd-journald-config-report.sh` | Review journald configuration and journal directory state. |
| Config | `scripts/config/sasd-logrotate-report.sh` | Review logrotate policy and drop-in configuration. |
| Config | `scripts/config/sasd-sshd-config-report.sh` | Report OpenSSH server configuration when available. |
| Config | `scripts/config/sasd-sudoers-report.sh` | Validate and review sudoers configuration. |
| Config | `scripts/config/sasd-systemd-timers-report.sh` | Report systemd timer state and timer unit files. |
| Database | `scripts/database/sasd-mariadb-inventory.sh` | Report local MariaDB/MySQL installation facts without login. |
| Database | `scripts/database/sasd-postgresql-inventory.sh` | Report local PostgreSQL installation facts without database login. |
| Filesystem | `scripts/filesystem/sasd-deleted-open-files.sh` | Find deleted files that are still held open by processes. |
| Filesystem | `scripts/filesystem/sasd-disk-usage-report.sh` | Report disk usage and largest filesystem areas. |
| Host documentation | `scripts/host-doc/sasd-host-inventory.sh` | Generate a basic host inventory report. |
| Host documentation | `scripts/host-doc/sasd-package-inventory.sh` | List installed packages. |
| Host documentation | `scripts/host-doc/sasd-service-inventory.sh` | List system services where supported. |
| Logging | `scripts/logging/sasd-auth-log-report.sh` | Summarize authentication log signals. |
| Logging | `scripts/logging/sasd-journal-errors.sh` | Review recent journal warnings/errors. |
| Logging | `scripts/logging/sasd-kernel-warnings.sh` | Review recent kernel warnings and dmesg fallback output. |
| Logging | `scripts/logging/sasd-log-volume-report.sh` | Report log directory and journald disk usage. |
| Logging | `scripts/logging/sasd-sudo-usage-report.sh` | Summarize sudo usage from journald and auth logs. |
| Monitoring | `scripts/monitoring/check_certificate_expiry.sh` | Monitoring-style certificate expiry check. |
| Monitoring | `scripts/monitoring/check_disk_usage.sh` | Monitoring-style disk usage check. |
| Monitoring | `scripts/monitoring/check_reboot_required.sh` | Monitoring-style reboot-required check. |
| Monitoring | `scripts/monitoring/check_service_active.sh` | Monitoring-style service active check. |
| Network | `scripts/network/sasd-forward-reverse-dns-check.sh` | Check forward/reverse DNS consistency for hostnames. |
| Network | `scripts/network/sasd-listening-services-report.sh` | Report listening TCP/UDP services and bind scope. |
| Packages | `scripts/packages/sasd-reboot-required-report.sh` | Report common reboot-required indicators. |
| Packages | `scripts/packages/sasd-update-status-report.sh` | Report package update status for supported package managers. |
| Reporting | `scripts/reporting/sasd-admin-summary.sh` | Generate a Markdown admin summary from selected checks. |
| Reporting | `scripts/reporting/sasd-findings-summary.sh` | Generate a compact triage findings summary. |
| Reporting | `scripts/reporting/sasd-release-readiness.sh` | Check local repository readiness before tagging. |
| Reporting | `scripts/reporting/sasd-run-logging-review.sh` | Run a focused logging review collection. |
| Reporting | `scripts/reporting/sasd-run-readonly-checks.sh` | Run a read-only check collection and create an index. |
| Reporting | `scripts/reporting/sasd-security-summary.sh` | Generate a Markdown security summary from selected checks. |
| Security | `scripts/security/sasd-auditd-status-report.sh` | Report auditd/auditctl state and audit rule visibility. |
| Security | `scripts/security/sasd-firewall-status-report.sh` | Report firewall tooling and rule summary. |
| Security | `scripts/security/sasd-fim-baseline.sh` | Create a file integrity baseline. |
| Security | `scripts/security/sasd-fim-check.sh` | Compare current files against a FIM baseline. |
| Security | `scripts/security/sasd-open-ports-audit.sh` | Report listening ports and related process data. |
| Security | `scripts/security/sasd-permission-risk-report.sh` | Report sensitive permission risks with symlink-aware handling. |
| Security | `scripts/security/sasd-root-owned-writable-report.sh` | Report root-owned files/directories with group or other write bits. |
| Security | `scripts/security/sasd-sensitive-files-check.sh` | Check permissions of sensitive system files. |
| Security | `scripts/security/sasd-ssh-baseline-check.sh` | Compare readable SSH server config with a small baseline. |
| Security | `scripts/security/sasd-suid-sgid-audit.sh` | List SUID/SGID files. |
| Security | `scripts/security/sasd-symlink-target-report.sh` | Report symlink metadata and target metadata separately. |
| Security | `scripts/security/sasd-system-accounts-audit.sh` | Identify suspicious local system account properties. |
| Security | `scripts/security/sasd-world-writable-audit.sh` | Report world-writable filesystem entries with filtering. |

## Local validation

Useful local checks:

```bash
make list-scripts
make syntax
make check
```

Optional smoke test:

```bash
make smoke
```

The smoke test writes a local report below `reports/` and does not commit
generated output.

## Safety

The scripts are designed for read-only administration and audit-style review.
They do not prove compliance, do not replace a professional security audit and
should not be run blindly on production systems without review.

Some reports are more complete when run as root because protected directories
and log files may otherwise be skipped. See
[docs/privilege-expectations.md](docs/privilege-expectations.md).

Before sharing generated reports, review them for hostnames, usernames, paths,
package names, service names, IP addresses and environment-specific details.

## Documentation

- [docs/script-index.md](docs/script-index.md)
- [docs/testing.md](docs/testing.md)
- [docs/run-readonly-checks.md](docs/run-readonly-checks.md)
- [docs/backup-restore-validation.md](docs/backup-restore-validation.md)
- [docs/milestone-6-backup-restore-status.md](docs/milestone-6-backup-restore-status.md)
- [docs/logging-milestone-3.md](docs/logging-milestone-3.md)
- [docs/milestone-3-logging-status.md](docs/milestone-3-logging-status.md)
- [docs/privilege-expectations.md](docs/privilege-expectations.md)
- [docs/world-writable-audit.md](docs/world-writable-audit.md)
- [docs/scheduling-reporting.md](docs/scheduling-reporting.md)
- [docs/security-controls-reporting.md](docs/security-controls-reporting.md)
- [docs/database-inventory.md](docs/database-inventory.md)
- [docs/release-readiness.md](docs/release-readiness.md)
- [docs/repository-strategy.md](docs/repository-strategy.md)
- [docs/script-safety.md](docs/script-safety.md)

## Status

This repository is an early but usable Linux administration toolkit. The current
focus is to keep the scripts understandable, conservative and useful for real
local review runs.
