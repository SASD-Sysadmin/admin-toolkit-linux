# Milestone 5: File Integrity Monitoring Status

Status: implemented for the current read-only baseline.

## Implemented scripts

- `scripts/security/sasd-fim-baseline.sh`
- `scripts/security/sasd-fim-check.sh`
- `scripts/security/sasd-fim-report.py`
- `scripts/reporting/sasd-run-fim-review.sh`

## Implemented documentation and examples

- `docs/file-integrity-monitoring.md`
- `docs/fim-review-reporting.md`
- `docs/milestone-5-fim-status.md`
- `examples/sample-fim-baseline.tsv`
- `examples/sample-fim-report.md`

## Current baseline capability

The current FIM workflow can:

- create a transparent TSV baseline for selected files and directories
- compare a later state against an existing baseline
- report changed, missing, unreadable and invalid baseline entries
- summarize baseline and check output in Markdown
- generate a focused FIM review collection under `reports/`

## Limitations

The current implementation is intentionally small. It does not provide:

- tamper-proof storage
- real-time monitoring
- kernel-level event collection
- central SIEM correlation
- policy enforcement
- automatic remediation

## Follow-up ideas

- Add optional JSON output for FIM summaries.
- Add a sanitized full FIM review from a lab VM.
- Add role-based baseline path presets.
- Add guidance for baseline refresh after planned maintenance.
