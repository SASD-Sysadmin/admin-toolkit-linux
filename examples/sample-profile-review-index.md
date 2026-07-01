# SASD Role Profile Review Collection

- Generated: 2026-06-30T12:00:00+02:00
- Host: lab-db01
- Repository root: `/home/admin/admin-toolkit-linux`
- Output directory: `./reports/profile-database-server`
- Profile: `database-server`
- Profile file: `/home/admin/admin-toolkit-linux/profiles/database-server.conf`
- Commands recorded: 6

> This collection is read-only. Role profiles express review expectations;
> they do not apply configuration, install packages or create backups.

## Command status

| Status | Script | Output |
| ---: | --- | --- |
| 0 | `profile-summary` | [profile-summary.md](profile-summary.md) |
| 0 | `scripts/reporting/sasd-run-host-inventory.sh` | [10-host-inventory.log](10-host-inventory.log) |
| 1 | `scripts/reporting/sasd-run-monitoring-review.sh` | [20-monitoring.log](20-monitoring.log) |
| 0 | `scripts/reporting/sasd-run-logging-review.sh` | [30-logging.log](30-logging.log) |
| 0 | `scripts/reporting/sasd-run-fim-review.sh` | [40-fim.log](40-fim.log) |
| 0 | `scripts/database/sasd-mariadb-inventory.sh` | [60-mariadb-inventory.md](60-mariadb-inventory.md) |
| 0 | `scripts/database/sasd-postgresql-inventory.sh` | [61-postgresql-inventory.md](61-postgresql-inventory.md) |

## Suggested review order

1. Open `profile-summary.md` to confirm the selected host role.
2. Review host inventory before treating findings as role-specific problems.
3. Review monitoring status for disk, inode, reboot and expected services.
4. Review logging, FIM, backup and database outputs only where enabled by the profile.
5. Treat missing expected paths/services as review items, not automatic remediation instructions.
