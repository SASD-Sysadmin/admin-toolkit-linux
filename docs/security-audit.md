# Security audit

Security audit scripts in this repository are read-only by default. They make typical Linux risks visible but do not automatically fix them.

## Included scripts

- `scripts/security/sasd-open-ports-audit.sh`
- `scripts/security/sasd-suid-sgid-audit.sh`
- `scripts/security/sasd-world-writable-audit.sh`
- `scripts/security/sasd-ssh-baseline-check.sh`

## Review guidance

Not every finding is automatically a vulnerability. Findings are starting points for human review.

Examples:

- A listening service may be required.
- A SUID binary may be normal for the distribution.
- A world-writable directory may be safe when the sticky bit is set.
- SSH settings must be evaluated against operational requirements.
