# File Integrity Monitoring

The FIM scripts provide a small, transparent baseline/check workflow for Linux
configuration files.

They are designed for lab systems, small servers and learning purposes. They are
not a replacement for a full enterprise FIM platform.

## Create a baseline

```bash
scripts/security/sasd-fim-baseline.sh --output baseline.tsv
```

Default monitored files include common Linux configuration files such as
`/etc/passwd`, `/etc/group`, `/etc/fstab`, `/etc/hosts`, `/etc/resolv.conf` and
`/etc/ssh/sshd_config`.

You can also specify one or more paths:

```bash
scripts/security/sasd-fim-baseline.sh --path /etc/ssh --output ssh-baseline.tsv
```

## Check a baseline

```bash
scripts/security/sasd-fim-check.sh --baseline baseline.tsv
```

Exit codes:

- `0`: baseline entries still match
- `1`: at least one file changed, disappeared or became unreadable
- `3`: invalid input or unreadable baseline

## Security note

Do not publish baselines from real customer or production systems. A baseline can
reveal file paths, owners, permissions, sizes and hashes of sensitive files.
