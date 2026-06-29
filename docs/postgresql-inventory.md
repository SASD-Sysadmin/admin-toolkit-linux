# PostgreSQL inventory

`scripts/database/sasd-postgresql-inventory.sh` collects read-only PostgreSQL
installation hints.

It reports:

- available PostgreSQL tools
- package hints
- service state
- cluster state when `pg_lsclusters` is available
- common configuration paths
- listener hints on port `5432`
- data directory metadata

Database names are hidden by default.

```bash
./scripts/database/sasd-postgresql-inventory.sh
./scripts/database/sasd-postgresql-inventory.sh --show-databases
./scripts/database/sasd-postgresql-inventory.sh --show-config --max-lines 80
```

The script does not use `sudo` and does not attempt privilege escalation. If the
current user cannot query database names, it reports that fact.
