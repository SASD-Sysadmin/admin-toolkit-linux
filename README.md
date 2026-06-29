# SASD-SysAdmin

Readable, conservative Linux administration scripts and documentation for small-company operations, lab systems and portfolio use.

This repository starts as a focused sysadmin toolbox. It is intentionally small at the beginning and grows in well-documented phases.

## Scope

Current focus:

- host documentation and inventory
- read-only security audit helpers
- Linux log and service review
- simple monitoring plugin examples
- documentation patterns for repeatable administration

Later focus:

- file integrity monitoring
- backup and restore validation
- Ansible-based baseline configuration
- DNS, database and SNMP reporting helpers

## Design principles

- simple before clever
- readable before compact
- documented before magical
- read-only by default
- no secrets, no customer data, no internal IP addresses
- changes only with explicit `--apply`, where supported
- safe output formats for audits and examples

## Repository layout

```text
scripts/
  host-doc/       Host inventory and documentation helpers
  security/       Read-only security audit scripts
  logging/        Journal and log review helpers
  monitoring/     Monitoring plugin examples

docs/             Concepts, safety notes and usage guidance
examples/         Sanitized example output
.github/          CI checks for shell scripts and Markdown
```

## Quick start

Run a host inventory:

```bash
bash scripts/host-doc/sasd-host-inventory.sh
```

Run basic security checks:

```bash
bash scripts/security/sasd-open-ports-audit.sh
bash scripts/security/sasd-suid-sgid-audit.sh /usr /bin /sbin
bash scripts/security/sasd-ssh-baseline-check.sh
```

Run monitoring checks:

```bash
bash scripts/monitoring/check_service_active.sh ssh
bash scripts/monitoring/check_reboot_required.sh
bash scripts/monitoring/check_certificate_expiry.sh example.com 443 30
```

## Safety

Most scripts are read-only and intended for documentation, review and learning. Use them only on systems you own or are explicitly allowed to administer. Review every script before running it with elevated privileges.

See [docs/script-safety.md](docs/script-safety.md).

## Status

Initial public starter version. The first goal is to build a trustworthy baseline of small, tested scripts before adding configuration-changing automation.
