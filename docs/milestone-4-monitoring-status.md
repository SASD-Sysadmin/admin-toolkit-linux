# Milestone 4 Monitoring Status

Milestone 4 focuses on simple monitoring-plugin-style checks with predictable
output and exit codes.

## Current baseline

Implemented for the current read-only baseline:

- `scripts/monitoring/check_service_active.sh`
- `scripts/monitoring/check_reboot_required.sh`
- `scripts/monitoring/check_certificate_expiry.sh`
- `scripts/monitoring/check_disk_usage.sh`
- `scripts/monitoring/check_inodes.sh`
- `scripts/reporting/sasd-run-monitoring-review.sh`

## Design choices

- Checks use small command-line interfaces.
- Checks return monitoring-style exit codes: `0` OK, `1` WARNING, `2` CRITICAL,
  `3` UNKNOWN.
- The focused collector records exit statuses but keeps running.
- Certificate checks are optional because they contact the selected endpoint.
- Service checks are optional in the collector because service expectations
  depend on the host role.

## Still useful later

- Add role profiles for expected services per host type.
- Add optional JSON output for selected checks.
- Add a sanitized full monitoring review example from a lab VM.
- Decide whether package update checks remain operational reports or become
  monitoring plugins too.
