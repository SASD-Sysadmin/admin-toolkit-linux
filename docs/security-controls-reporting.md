# Security Controls Reporting

This document covers read-only reports for common host-level security controls.

## Scripts

- `scripts/security/sasd-firewall-status-report.sh`
- `scripts/security/sasd-auditd-status-report.sh`

## Firewall report

The firewall report detects common tools such as `nft`, `iptables`, `ufw` and
`firewalld`. By default it prints tool and service state plus summary counts. It
does not dump full rulesets unless requested.

```bash
./scripts/security/sasd-firewall-status-report.sh
./scripts/security/sasd-firewall-status-report.sh --show-rules --max-lines 80
```

## Auditd report

The auditd report checks whether audit tooling is installed, whether the service
appears active and whether rules are visible through `auditctl`.

```bash
./scripts/security/sasd-auditd-status-report.sh
./scripts/security/sasd-auditd-status-report.sh --no-rules
```

## Interpretation

Missing firewall or auditd tooling is not automatically a failure. Containers,
WSL systems, appliances and small lab hosts may intentionally not run all of
these controls. The report is a starting point for review, not a compliance
verdict.
