# Monitoring Checks

Scripts in `scripts/monitoring/` follow a simple Nagios/Icinga-compatible style:

- `0` = OK
- `1` = WARNING
- `2` = CRITICAL
- `3` = UNKNOWN

## Included checks

- `check_service_active.sh`
- `check_reboot_required.sh`
- `check_certificate_expiry.sh`

## Examples

```bash
bash scripts/monitoring/check_service_active.sh ssh
bash scripts/monitoring/check_reboot_required.sh
bash scripts/monitoring/check_certificate_expiry.sh example.com 443 30
```
