# Scheduling Reporting

This document covers scripts that make scheduled local work visible.

## Scripts

- `scripts/config/sasd-cron-report.sh`
- `scripts/config/sasd-systemd-timers-report.sh`

## Why this matters

Linux hosts often run operational work outside interactive sessions. Backups,
cleanup jobs, package refresh tasks, certificate renewal, application jobs and
legacy maintenance commands may be scheduled through cron or systemd timers.

A host review should show these schedules clearly before anyone changes them.
Both scripts are read-only and are intended for documentation and review.

## Recommended usage

```bash
./scripts/config/sasd-cron-report.sh
./scripts/config/sasd-systemd-timers-report.sh
```

For user crontab content, use the option explicitly because commands may reveal
private paths or application details:

```bash
./scripts/config/sasd-cron-report.sh --user-crontabs content
```

## Review hints

Look for:

- old backup jobs that still run
- scripts under deleted or migrated application paths
- duplicate cron and systemd timer jobs
- jobs running as root without clear documentation
- jobs that call network tools, database dumps or cleanup commands
- disabled or failed timers
