# admin-toolkit-linux

Readable, conservative Linux administration scripts and documentation for small-company operations, lab systems and portfolio use.

This repository is part of the SASD `admin-toolkit-*` repository family. It focuses on Linux hosts first. Other Unix-like systems such as FreeBSD, macOS, Solaris, OpenBSD or AIX should get their own repositories later when there is enough material to make them useful and maintainable.

The repository starts as a focused sysadmin toolbox. It is intentionally small at the beginning and grows in well-documented phases.

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
- small tools that can be reviewed before execution

## Repository layout

```text
scripts/
  host-doc/       Host inventory and documentation helpers
  security/       Read-only security audit scripts
  logging/        Journal and log review helpers
  monitoring/     Monitoring plugin examples

docs/             Concepts, safety notes and usage guidance
examples/         Sanitized example output
.github/          CI checks, issue templates and contribution workflow
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

## Roadmap

The project roadmap is tracked in [ROADMAP.md](ROADMAP.md). The first milestone is a trustworthy Linux host documentation and read-only security audit baseline. Configuration-changing automation will only be added after the audit scripts, examples and safety documentation are solid.

## Safety

Most scripts are read-only and intended for documentation, review and learning. Use them only on systems you own or are explicitly allowed to administer. Review every script before running it with elevated privileges.

See [docs/script-safety.md](docs/script-safety.md).

## Contributing

Contributions should keep the repository conservative, readable and safe by default. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Status

Initial public starter version. The first goal is to build a trustworthy baseline of small, tested scripts before adding configuration-changing automation.
