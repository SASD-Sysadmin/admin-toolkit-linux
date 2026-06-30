# Logging and operational review milestone

This document describes the logging-focused Roadmap Milestone 3 work.

The milestone remains read-only. The scripts inspect visible log sources and
configuration, but they do not rotate, truncate, delete, compress or modify logs.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/logging/sasd-sudo-usage-report.sh` | Summarize sudo usage from journald and auth logs. |
| `scripts/logging/sasd-kernel-warnings.sh` | Review recent kernel warnings and errors. |
| `scripts/logging/sasd-log-volume-report.sh` | Report visible log volume and largest log files. |
| `scripts/reporting/sasd-run-logging-review.sh` | Run a focused logging review collection. |

Existing related scripts:

| Script | Purpose |
| --- | --- |
| `scripts/logging/sasd-journal-errors.sh` | Review recent system journal warnings/errors. |
| `scripts/logging/sasd-auth-log-report.sh` | Summarize authentication log signals. |
| `scripts/config/sasd-journald-config-report.sh` | Review journald configuration and storage. |
| `scripts/config/sasd-logrotate-report.sh` | Review logrotate policy and drop-ins. |

## Suggested workflow

```bash
./scripts/reporting/sasd-run-logging-review.sh --output ./reports/logging-review
less ./reports/logging-review/INDEX.md
```

For a current-day review:

```bash
./scripts/reporting/sasd-run-logging-review.sh --since today --output ./reports/logging-today
```

## What to look for

- unexpected sudo usage or repeated authentication failures
- kernel warnings that repeat frequently
- oversized logs or unexpected growth below `/var/log`
- journald storage mode and persistent journal size
- logrotate configuration gaps or unexpected vendor drop-ins

## Interpretation

Log messages are signals, not verdicts. A desktop, WSL system, container host or
lab machine can produce noise that would not be acceptable on a production
server. The reports intentionally avoid automatic remediation.
