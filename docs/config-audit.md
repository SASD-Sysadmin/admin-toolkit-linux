# Configuration audit scripts

This directory contains read-only configuration review helpers.

## Scripts

- `scripts/config/sasd-sshd-config-report.sh`
- `scripts/config/sasd-sudoers-report.sh`

The scripts are intentionally conservative. They inspect configuration and report
findings, but they do not modify files, restart services or reload daemons.

## SSHD configuration report

The SSHD report prefers `sshd -T` because this prints the effective OpenSSH
configuration after defaults and include files are applied. If `sshd -T` is not
available, the script falls back to parsing `/etc/ssh/sshd_config`.

Example:

```bash
./scripts/config/sasd-sshd-config-report.sh --format markdown
```

## Sudoers report

The sudoers report uses `visudo -c` when available and documents file ownership,
permissions and visible sudo rules.

Example:

```bash
./scripts/config/sasd-sudoers-report.sh --format markdown
```

The output can contain usernames, groups and privileged command rules. Do not paste
production output into public tickets or examples without review.
