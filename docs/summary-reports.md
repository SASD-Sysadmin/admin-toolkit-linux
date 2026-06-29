# Summary reports

Summary scripts call several read-only toolkit scripts and combine their output into
one Markdown report.

## Scripts

- `scripts/reporting/sasd-admin-summary.sh`
- `scripts/reporting/sasd-security-summary.sh`

## Admin summary

```bash
./scripts/reporting/sasd-admin-summary.sh > admin-summary.md
```

This report focuses on operational information such as host inventory, services,
packages, disk usage, deleted open files and log warnings.

## Security summary

```bash
./scripts/reporting/sasd-security-summary.sh > security-summary.md
```

This report focuses on local review checks such as open ports, SSH, sudoers,
system accounts, SUID/SGID, world-writable paths and sensitive files.

The generated reports may contain hostnames, usernames, IP addresses, paths and
package names. Review output before sharing it publicly.
