# Phase 6: Read-only findings and interpretation

Phase 6 adds compact triage reporting without introducing remediation.

## New scripts

| Script | Purpose |
| --- | --- |
| `scripts/security/sasd-permission-risk-report.sh` | Permission risk report for sensitive paths. |
| `scripts/security/sasd-root-owned-writable-report.sh` | Root-owned entries writable by group or everyone. |
| `scripts/config/sasd-browser-repo-report.sh` | Browser/vendor repository and keyring hints. |
| `scripts/database/sasd-postgresql-inventory.sh` | PostgreSQL inventory. |
| `scripts/reporting/sasd-findings-summary.sh` | Compact findings summary. |

## Collector update

`scripts/reporting/sasd-run-readonly-checks.sh` now includes the compact findings
summary by default as `89-findings-summary.md`.

Verbose admin/security summaries remain opt-in with:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --include-summary
```

## Design decision

This phase intentionally does not include repair scripts. Repair logic belongs in
separate, explicit tools with a stronger safety contract, confirmation workflow
and rollback plan.
