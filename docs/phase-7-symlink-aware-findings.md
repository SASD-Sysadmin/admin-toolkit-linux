# Phase 7: Symlink-aware findings

Phase 7 improves the quality of permission findings without changing the
read-only safety model.

## Goals

- avoid false positives caused by Linux symlink mode bits
- evaluate target permissions for sensitive symlink paths where possible
- keep broad reports reviewable
- keep summary output useful for triage
- continue to avoid automatic remediation

## Changed scripts

- `scripts/security/sasd-world-writable-audit.sh`
- `scripts/security/sasd-permission-risk-report.sh`
- `scripts/security/sasd-root-owned-writable-report.sh`
- `scripts/reporting/sasd-findings-summary.sh`
- `scripts/reporting/sasd-run-readonly-checks.sh`

## New script

- `scripts/security/sasd-symlink-target-report.sh`

## Expected result

Before this phase, many symlinks could appear as `777` and inflate HIGH/WARN
counts. After this phase, direct permission findings focus on regular files and
directories. Symlinks are documented separately and target permissions are used
when evaluating sensitive paths.

## Testing

```bash
make check
./scripts/security/sasd-world-writable-audit.sh --max-results 50
./scripts/security/sasd-symlink-target-report.sh --max-results 50
./scripts/security/sasd-permission-risk-report.sh --max-results 50
./scripts/reporting/sasd-findings-summary.sh
./scripts/reporting/sasd-run-readonly-checks.sh --output ./reports/phase7-test
```
