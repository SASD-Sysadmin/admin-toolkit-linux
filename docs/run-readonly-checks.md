# Read-only Check Collection

`scripts/reporting/sasd-run-readonly-checks.sh` runs a selected set of read-only administration and audit scripts and stores the output in a report directory.

It is the easiest way to use the toolkit on a host.

## Basic usage

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --output ./reports/local-test
```

The output directory contains:

- `INDEX.md`
- `status.tsv`
- one report file per executed script

Generated report directories below `reports/` are ignored by Git.

## Default behavior

The default collection avoids summary reports to keep output size manageable and avoid duplicated content.

Summary reports can be included explicitly:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --include-summary
```

## Review before sharing

Report output can contain:

- hostnames
- usernames
- package names
- service names
- IP addresses
- local paths
- process names
- configuration details

Do not publish real reports from private systems without reviewing and redacting them.

## Exit statuses

The generated `INDEX.md` and `status.tsv` include command statuses.

General interpretation:

| Status | Meaning |
| ---: | --- |
| `0` | Command completed successfully. |
| `1` | Findings may have been detected by an audit-style script. |
| `2+` | Execution problem, invalid arguments or missing prerequisite. |

Always read the report output. The collector does not replace human review.
