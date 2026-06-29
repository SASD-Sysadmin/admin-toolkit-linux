# Filesystem Audit Scripts

This directory contains read-only filesystem inspection helpers.

## sasd-disk-usage-report.sh

Creates a Markdown table with filesystem usage and warning/critical status.

Example:

```bash
scripts/filesystem/sasd-disk-usage-report.sh --warning 80 --critical 90
```

Exit codes:

- `0`: all checked filesystems are below warning threshold
- `1`: at least one filesystem reached warning threshold
- `2`: at least one filesystem reached critical threshold
- `3`: invalid input or required tool missing

## sasd-deleted-open-files.sh

Reports deleted files that are still held open by running processes. This is useful
when disk usage remains high after large files have been deleted.

Example:

```bash
scripts/filesystem/sasd-deleted-open-files.sh --limit 100
```

The script prefers `lsof +L1` and falls back to `/proc/*/fd` if `lsof` is not
installed.
