# Permission risk reporting

This document describes the permission-focused read-only reports.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/security/sasd-permission-risk-report.sh` | Compact report for world-writable paths, writable sensitive configuration and SUID/SGID files. |
| `scripts/security/sasd-root-owned-writable-report.sh` | Finds root-owned entries that are writable by group or everyone. |
| `scripts/reporting/sasd-findings-summary.sh` | Produces a compact triage summary from local host state. |

## Safety model

The scripts are read-only. They do not run `chmod`, `chown`, `rm`, package
commands, service restarts or database changes.

## Example commands

```bash
./scripts/security/sasd-permission-risk-report.sh
./scripts/security/sasd-permission-risk-report.sh --include-home --max-results 50
./scripts/security/sasd-root-owned-writable-report.sh --path /etc --path /opt
./scripts/reporting/sasd-findings-summary.sh
```

## Interpreting output

A permission finding means: review this path. It does not automatically mean the
system is compromised.

Important examples:

- world-writable cron files: usually high priority
- world-writable database config files: usually high priority
- root-owned group-writable files: depends on group membership and purpose
- SUID/SGID files: expected in some packages, but should be visible

## Why remediation is separate

Permission repair can break systems if applied mechanically. For example,
changing permissions under packaged application trees may affect package updates,
runtime behavior or vendor tooling. The toolkit reports; the administrator
decides.
