# Backup Validation

`admin-toolkit-linux` starts with conservative backup helpers. The goal is not to
replace a professional backup product, but to document repeatable and reviewable
backup patterns.

## sasd-rsync-snapshot.sh

Creates timestamped rsync snapshots. The default mode is dry-run.

Dry-run:

```bash
scripts/backup/sasd-rsync-snapshot.sh --source /etc --destination /backup/etc
```

Apply after reviewing the dry-run:

```bash
scripts/backup/sasd-rsync-snapshot.sh --source /etc --destination /backup/etc --apply
```

The script writes a new `.partial` snapshot first and renames it after successful
completion. The `latest` symlink is only updated after a successful applied run.

Production use requires review, restore testing, storage monitoring and retention
planning.
