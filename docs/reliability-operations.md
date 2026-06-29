# Reliability and Operations Scripts

This phase adds scripts that make the toolkit easier to use during routine
operations. The focus is still conservative and read-only:

- collect reports into one output directory
- review journald and logrotate configuration
- summarize listening services
- report package update status
- report reboot-required indicators
- check backup file age

These scripts are intended for local administration, lab systems and small-company
Linux servers. They are not a compliance scanner and they do not replace a full
monitoring platform.

## Main entry point

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --output /tmp/sasd-report-dev102
```

The command creates an `INDEX.md`, a `status.tsv` and one report file per executed
script.

## Safety principles

- No package updates are installed.
- No services are restarted.
- No log files are rotated.
- No backups are created or removed.
- Non-zero child exit codes are recorded instead of stopping the collector.

Review generated reports before sharing them, because they can contain hostnames,
usernames, IP addresses, package names and local paths.
