# Read-only Check Collection

`scripts/reporting/sasd-run-readonly-checks.sh` runs a curated set of safe,
read-only checks and stores their output in a report directory.

The collector is intended for first-look host documentation and operational
review. It does not change configuration, install packages, stop/start services
or repair findings.

## Basic usage

```bash
./scripts/reporting/sasd-run-readonly-checks.sh
```

The default output path is:

```text
reports/<host>-<timestamp>/
```

Use a fixed output directory when you are testing:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --output ./reports/dev102-test
```

## Summary reports

Summary reports are excluded by default because they call many child checks again
and can duplicate output. Include them explicitly when you want a human-readable
top-level report:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --include-summary --output ./reports/full-review
```

## Large findings

The world-writable audit is limited by default when called from the collector.
Change the limit with:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --world-writable-max 1000
```

Run the individual script with `--full` when an unrestricted report is required.

## Review notes

Generated reports can contain hostnames, usernames, IP addresses, package names,
service names and local paths. Review the output before sharing it publicly.
