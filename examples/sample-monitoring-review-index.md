# SASD Monitoring Review Collection

- Generated: 2026-06-30T00:00:00+00:00
- Host: example-host
- Repository root: `/path/to/admin-toolkit-linux`
- Output directory: `reports/monitoring-local`
- Disk/inode path: `/`
- Disk thresholds: warning=80 critical=90
- Inode thresholds: warning=80 critical=90

> This collection is read-only. It wraps monitoring-style checks and records
> their exit status for human review. WARNING and CRITICAL results are findings,
> not collector failures.

## Command status

| Status | Script | Output |
| ---: | --- | --- |
| 0 | `scripts/monitoring/check_disk_usage.sh` | [`01-disk-usage.md`](01-disk-usage.md) |
| 0 | `scripts/monitoring/check_inodes.sh` | [`02-inode-usage.md`](02-inode-usage.md) |
| 0 | `scripts/monitoring/check_reboot_required.sh` | [`03-reboot-required.md`](03-reboot-required.md) |
| 0 | `scripts/monitoring/check_service_active.sh` | [`10-service-01.md`](10-service-01.md) |

## Suggested review order

1. Review disk and inode checks together.
2. Review reboot-required status.
3. Review optional service checks for host-role expectations.
4. Review optional certificate checks only when configured intentionally.
