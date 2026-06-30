# SASD File Integrity Report

- Generated: 2026-06-30T10:00:00+02:00
- Host: lab-host
- User: admin
- Effective UID: 1000
- Privilege: non-root
- Baseline: `examples/sample-fim-baseline.tsv`
- Check report: `examples/sample-fim-check.md`
- Max detail rows: 80

> Read-only summary. This report parses baseline/check output; it does not hash,
> repair, delete or modify monitored files.

## Summary

| Metric | Value |
| --- | ---: |
| Baseline entries | 3 |
| Check rows parsed | 2 |
| CHANGED rows | 1 |
| OK rows | 1 |
| Parse warnings | 0 |

Result: **FINDINGS: changed, missing, unreadable or invalid baseline entries were reported.**

## Baseline overview

| Metric | Value |
| --- | ---: |
| Files in baseline | 3 |
| Distinct owners | 1 |
| Distinct groups | 1 |
| Distinct modes | 2 |

## Check findings

| Status | Path | Details |
| --- | --- | --- |
| `CHANGED` | `/etc/ssh/sshd_config` | sha256 changed; mtime 1710000000-&gt;1710003600 |
| `OK` | `All baseline entries match` | checked 2 files |

## Review hints

- Treat a new baseline as a reference point, not proof that the current state is safe.
- Review changed, missing and unreadable entries before deciding whether a change is expected.
- Store real baselines securely; they can reveal paths, ownership, modes, sizes and hashes.
- This tool is not an EDR, SIEM or tamper-proof FIM platform.
