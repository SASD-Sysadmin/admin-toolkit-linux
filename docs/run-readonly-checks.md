# Running the Read-only Check Collection

`sasd-run-readonly-checks.sh` is the recommended operational entry point once the
individual scripts are present.

Example:

```bash
./scripts/reporting/sasd-run-readonly-checks.sh --output /tmp/sasd-report-$(hostname -s)
```

The output directory contains:

- `INDEX.md` with the status of each child script
- `status.tsv` for machine-readable status review
- individual report files

Some child scripts return exit status `1` when they detect findings. This is not
always a failure. The collector records the status and continues so the operator
gets a complete report folder.

Use `--include-slow` to include slower checks such as file integrity baselines.
