# World-writable Audit

`scripts/security/sasd-world-writable-audit.sh` reports filesystem entries that are writable by everyone.

This check is useful, but it can produce very large output on developer systems. SDKs, extracted archives, local toolchains or copied vendor trees sometimes contain many world-writable files. The script therefore supports path and exclude controls.

## Basic usage

```bash
./scripts/security/sasd-world-writable-audit.sh
```

Default behavior:

- starts at `/`
- prunes common pseudo/volatile paths such as `/proc`, `/sys`, `/dev`, `/run`, `/tmp`, `/var/tmp`, `/mnt` and `/media`
- stays on one filesystem by default
- limits output to 500 findings
- emits Markdown output

## Useful options

Search only selected paths:

```bash
./scripts/security/sasd-world-writable-audit.sh --path /etc --path /opt
```

Exclude noisy or intentionally local trees:

```bash
./scripts/security/sasd-world-writable-audit.sh --exclude /opt/nodejs
```

Limit output:

```bash
./scripts/security/sasd-world-writable-audit.sh --max-results 100
```

Show full output:

```bash
./scripts/security/sasd-world-writable-audit.sh --full
```

Use TSV for later processing:

```bash
./scripts/security/sasd-world-writable-audit.sh --format tsv > /tmp/world-writable.tsv
```

Cross filesystem boundaries:

```bash
./scripts/security/sasd-world-writable-audit.sh --cross-filesystems
```

## Interpreting findings

World-writable paths are not always equally severe.

Examples that need review:

- world-writable directories without sticky bit
- world-writable files below application, service, library or include directories
- world-writable files owned by normal users below system paths such as `/opt`
- world-writable scripts, service files, configuration files or library paths

Examples that may be expected:

- sticky temporary directories such as `/tmp`
- controlled runtime directories created by services
- lab-only SDK or toolchain trees, depending on local policy

The script does not decide whether a path is allowed. Compare findings with the host role and the local administration policy.

## Example for noisy Node.js SDK trees

If a local Node.js installation under `/opt/nodejs` creates too much noise:

```bash
./scripts/security/sasd-world-writable-audit.sh --exclude /opt/nodejs --max-results 200
```

Do not blindly exclude paths in production. First understand why the path is world-writable.
