# Monitoring checks

Monitoring scripts follow a simple plugin style. They print one summary line and return predictable exit codes.

## Exit codes

- `0`: OK
- `1`: WARNING
- `2`: CRITICAL
- `3`: UNKNOWN

## Included scripts

- `scripts/monitoring/check_service_active.sh`
- `scripts/monitoring/check_reboot_required.sh`
- `scripts/monitoring/check_certificate_expiry.sh`

## Example

```bash
bash scripts/monitoring/check_service_active.sh ssh
```

The checks can be run by humans or integrated into Icinga/Nagios-compatible monitoring later.
