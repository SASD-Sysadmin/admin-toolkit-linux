# Monitoring Checks

This document describes the read-only monitoring-style checks in
`admin-toolkit-linux`.

The scripts are intentionally small. They are useful for manual checks, lab
systems and later integration into monitoring systems such as Icinga or Nagios.
They do not change system configuration.

## Exit status convention

The monitoring checks use the common plugin convention:

| Exit status | Meaning |
| ---: | --- |
| `0` | OK |
| `1` | WARNING |
| `2` | CRITICAL |
| `3` | UNKNOWN |

A non-zero monitoring exit status is not necessarily a script failure. It can be
the intended result of a check that found a warning or critical condition.

## Current checks

| Script | Purpose |
| --- | --- |
| `scripts/monitoring/check_disk_usage.sh` | Checks byte usage for one path or mount point. |
| `scripts/monitoring/check_inodes.sh` | Checks inode usage for one path or mount point. |
| `scripts/monitoring/check_reboot_required.sh` | Checks common reboot-required marker files. |
| `scripts/monitoring/check_service_active.sh` | Checks whether one systemd service is active. |
| `scripts/monitoring/check_certificate_expiry.sh` | Checks remote TLS certificate expiry. |
| `scripts/reporting/sasd-run-monitoring-review.sh` | Runs a focused monitoring review collection. |

## Examples

```bash
scripts/monitoring/check_disk_usage.sh --path / --warning 80 --critical 90
scripts/monitoring/check_inodes.sh --path / --warning 70 --critical 85
scripts/monitoring/check_reboot_required.sh
scripts/monitoring/check_service_active.sh cron.service
```

Focused local review:

```bash
scripts/reporting/sasd-run-monitoring-review.sh \
  --path / \
  --service cron.service \
  --output reports/monitoring-local
```

Optional certificate check:

```bash
scripts/reporting/sasd-run-monitoring-review.sh \
  --cert-host example.org \
  --cert-port 443 \
  --cert-warning-days 30
```

## Notes

- Disk usage and inode usage must both be reviewed. A filesystem can have free
  bytes but no remaining inodes.
- Service checks require a concrete expected service name. The generic collector
  does not assume a server role.
- Certificate checks contact the configured endpoint and are therefore optional.
- The scripts report state; they do not restart services, clean filesystems,
  rotate logs or install certificates.
