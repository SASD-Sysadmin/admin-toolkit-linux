# Security Audit Helpers

These scripts are read-only helpers. They are not a replacement for a full professional security audit, but they provide a useful starting point for Linux host review.

## Included scripts

- `scripts/security/sasd-open-ports-audit.sh`
- `scripts/security/sasd-suid-sgid-audit.sh`
- `scripts/security/sasd-world-writable-audit.sh`
- `scripts/security/sasd-ssh-baseline-check.sh`

## Suggested first run

```bash
mkdir -p reports
bash scripts/security/sasd-open-ports-audit.sh > reports/open-ports.md
bash scripts/security/sasd-suid-sgid-audit.sh /usr /bin /sbin > reports/suid-sgid.md
bash scripts/security/sasd-world-writable-audit.sh /tmp /var/tmp /usr /opt > reports/world-writable.md
bash scripts/security/sasd-ssh-baseline-check.sh > reports/ssh-baseline.md
```

## Interpretation

Findings are indicators. They need human review. For example, SUID files are not automatically bad, but unexpected SUID files are worth investigating.
