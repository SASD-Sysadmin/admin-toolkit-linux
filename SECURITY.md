# Security Policy

## Intended use

This repository contains administrative scripts and examples for Linux systems. They are intended for lab systems, small-company operations and learning.

Use them only on systems you own or are explicitly allowed to administer.

## Secrets policy

Do not commit:

- passwords
- SSH private keys
- API tokens
- customer names
- real internal IP address ranges
- production hostnames
- database credentials
- `.env` files with real values

Use sanitized examples under `examples/`.

## Script safety baseline

Scripts should be read-only by default. Scripts that modify systems must require an explicit option such as `--apply` and must document exactly what they change.

Security audit scripts must not delete files, change permissions, restart services or alter firewall rules unless that behavior is explicitly requested and documented.

## Reporting vulnerabilities

Open a private security report where possible or contact the repository owner through the published GitHub profile.
