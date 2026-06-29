# World-writable Audit

`scripts/security/sasd-world-writable-audit.sh` finds world-writable files and
directories below selected paths.

World-writable paths are not always wrong. Directories such as `/tmp` are normal
when protected by the sticky bit. Unexpected world-writable paths below
application directories, service trees or user home directories should be
reviewed.

## Usage

```bash
./scripts/security/sasd-world-writable-audit.sh
./scripts/security/sasd-world-writable-audit.sh /var /home
./scripts/security/sasd-world-writable-audit.sh --max-results 100 /srv
./scripts/security/sasd-world-writable-audit.sh --full /srv/www
```

The default scan paths are:

```text
/tmp /var /home /opt
```

The default output is limited to keep reports readable. Use `--full` only when a
large report is acceptable.
