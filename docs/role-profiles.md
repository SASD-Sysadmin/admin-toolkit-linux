# Role profiles

Role profiles are a light-weight overlay for the existing read-only toolkit.
They define what should be reviewed for a host role without changing the host.

The first profiles are intentionally simple:

- `generic`
- `workstation`
- `web-server`
- `database-server`
- `backup-host`

Profiles are not compliance policies. They are review expectations. For example,
selecting the `web-server` profile means that web-related services and paths are
expected and should be checked; it does not mean the collector will install or
configure a web server.

## Why profiles exist

The same finding can mean different things on different hosts:

- `postgresql.service` inactive can be normal on a workstation.
- `postgresql.service` inactive can be important on a database server.
- `/backup` missing can be normal on a generic host.
- `/backup` missing can be important on a backup host.

Profiles help keep this context visible without hard-coding one universal
interpretation into every script.

## Usage

List profiles:

```bash
./scripts/reporting/sasd-run-profile-review.sh --list-profiles
```

Run the generic profile:

```bash
./scripts/reporting/sasd-run-profile-review.sh \
  --profile generic \
  --output ./reports/profile-generic
```

Run a database-server review:

```bash
./scripts/reporting/sasd-run-profile-review.sh \
  --profile database-server \
  --output ./reports/profile-database-server
```

## Profile file format

Profiles are simple `KEY=value` files below `profiles/`.

Pipe-separated values are used for lists:

```text
DISK_PATHS=/|/var|/var/log
EXPECTED_SERVICES=mariadb.service|postgresql.service
FIM_PATHS=/etc/hosts|/etc/resolv.conf|/etc/fstab|/etc/mysql|/etc/postgresql
```

The current keys are:

| Key | Purpose |
| --- | --- |
| `PROFILE_ID` | Stable profile identifier. |
| `PROFILE_NAME` | Human-readable profile name. |
| `PROFILE_DESCRIPTION` | Short description of the role. |
| `RUN_HOST_INVENTORY` | Run focused host inventory collector. |
| `RUN_MONITORING` | Run focused monitoring collector. |
| `RUN_LOGGING` | Run focused logging collector. |
| `RUN_FIM` | Run focused FIM review for existing configured paths. |
| `RUN_BACKUP_REVIEW` | Run focused backup review for the first existing backup path. |
| `RUN_DATABASE_INVENTORY` | Run local database inventory scripts. |
| `DISK_PATHS` | Role-relevant filesystem paths. |
| `EXPECTED_SERVICES` | Services that are expected for the role. |
| `FIM_PATHS` | Files/directories suitable for a focused FIM baseline. |
| `BACKUP_PATHS` | Backup paths expected for the role. |
| `NOTES` | Free-text profile note. |

## Safety

The profile collector does not:

- install packages
- enable services
- create users
- create backups
- edit configuration files
- mount filesystems
- repair findings

It only runs existing read-only collectors and writes reports below the selected
output directory.

## Current limitations

- Profiles are intentionally conservative and may need local adjustment.
- Missing services or paths are findings for review, not automatic errors.
- FIM runs only for configured paths that currently exist.
- Backup review runs only when the profile enables it and at least one configured
  backup path exists.
- Profiles are not yet used by Ansible or write-capable backup helpers.
