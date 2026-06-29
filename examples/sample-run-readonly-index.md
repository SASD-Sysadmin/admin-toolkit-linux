# SASD Read-only Check Collection

- Generated: 2026-06-29T10:50:00+02:00
- Host: dev102
- Repository root: `/home/robin/admin-toolkit-linux`
- Output directory: `/tmp/sasd-report-dev102`

## Command status

| Status | Script | Output |
| ---: | --- | --- |
| 0 | `scripts/host-doc/sasd-host-inventory.sh` | [`01-host-inventory.md`](01-host-inventory.md) |
| 0 | `scripts/config/sasd-sshd-config-report.sh` | [`20-sshd-config.md`](20-sshd-config.md) |
| 1 | `scripts/security/sasd-system-accounts-audit.sh` | [`33-system-accounts.md`](33-system-accounts.md) |

## Notes

- Exit status 1 can mean findings were detected by an audit script.
- Review each report before sharing it outside your environment.
