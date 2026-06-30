# Symlink-aware permission reporting

Linux systems often show symbolic links as `lrwxrwxrwx` or mode `777`.
This is usually not the permission that controls access to the target file.
The kernel follows the symlink and applies the permissions of the target object.

For that reason, the toolkit should not treat symlink mode `777` as a direct
`HIGH` finding. It should either ignore symlink mode bits by default or resolve
the target and report the effective target metadata.

## Why this matters

A naive world-writable scan can produce thousands of misleading entries under
locations such as:

- `/etc/rc*.d`
- `/etc/systemd/system`
- `/etc/ssl/certs`
- `/opt/nodejs`
- browser application directories
- package-managed compatibility links

Many of those entries are symlinks. The link itself may appear as `777`, while
the target file is not writable by everyone.

## Toolkit behavior

The following scripts are now symlink-aware:

- `scripts/security/sasd-world-writable-audit.sh`
- `scripts/security/sasd-permission-risk-report.sh`
- `scripts/security/sasd-root-owned-writable-report.sh`
- `scripts/reporting/sasd-findings-summary.sh`

A new inspection helper is also available:

- `scripts/security/sasd-symlink-target-report.sh`

## Recommended review workflow

Run the broad read-only collector first:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --output ./reports/host-review
```

Then inspect the compact finding summary:

```bash
less ./reports/host-review/89-findings-summary.md
```

If a path is a symlink, inspect target metadata:

```bash
./scripts/security/sasd-symlink-target-report.sh --path /etc/mysql --path /etc/cron.daily
```

## Important limitation

This still does not decide whether a finding is exploitable. It only improves
signal quality by separating symlink metadata from effective target metadata.
