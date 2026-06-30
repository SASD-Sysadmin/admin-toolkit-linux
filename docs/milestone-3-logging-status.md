# Milestone 3 Logging Status

Roadmap Milestone 3 focuses on small, useful log review helpers for daily
operations.

## Current status

Milestone 3 is complete for the current read-only baseline.

Implemented scripts:

- `scripts/logging/sasd-journal-errors.sh`
- `scripts/logging/sasd-auth-log-report.sh`
- `scripts/logging/sasd-sudo-usage-report.sh`
- `scripts/logging/sasd-kernel-warnings.sh`
- `scripts/logging/sasd-log-volume-report.sh`
- `scripts/config/sasd-journald-config-report.sh`
- `scripts/config/sasd-logrotate-report.sh`
- `scripts/reporting/sasd-run-logging-review.sh`

Supporting files:

- `docs/logging-milestone-3.md`
- `examples/sample-logging-review-index.md`

## Review model

The focused logging review collector creates a small report set:

1. journald configuration
2. logrotate configuration
3. journal warnings/errors
4. auth log signals
5. sudo usage
6. kernel warnings
7. log volume

This supports a daily or weekly operational review without changing the host.

## Known follow-up

Some log reports are naturally more complete when run as root. This is not a
reason to make every script root-only. The project tracks this as a cross-cutting
privilege-awareness improvement in `docs/privilege-expectations.md` and
`ROADMAP.md`.

## Not part of this milestone

Milestone 3 does not implement a SIEM, log shipping, retention policy management
or automatic log cleanup. Those would be separate, later topics.
