#!/usr/bin/env bash
# scripts/backup/sasd-restore-drill-plan.sh
# Purpose: Generate a read-only restore drill checklist.
# Project: admin-toolkit-linux
# License: MIT

set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SYSTEM_NAME=""
BACKUP_PATH="${SASD_BACKUP_REVIEW_PATH:-}"
RESTORE_TARGET="isolated test system"
SCOPE="configuration and data needed for the selected service"
RTO="not defined"
RPO="not defined"
OWNER="not assigned"
SERVICE="not specified"

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Options:
  --system NAME            System or host name for the drill plan.
  --service NAME           Service/application/database being tested.
  --backup-path PATH       Backup source or reference path.
  --target TEXT            Restore target description. Default: isolated test system
  --scope TEXT             Restore scope description.
  --rto TEXT               Recovery Time Objective note.
  --rpo TEXT               Recovery Point Objective note.
  --owner NAME             Responsible person/team.
  -h, --help               Show this help.

Examples:
  ./scripts/backup/sasd-restore-drill-plan.sh --system dev102 --service mariadb --backup-path /backup
  ./scripts/backup/sasd-restore-drill-plan.sh --service taskhost --target 'temporary VM'
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --system)
      [ "$#" -ge 2 ] || { echo "ERROR: --system requires a value" >&2; exit 2; }
      SYSTEM_NAME="$2"
      shift 2
      ;;
    --service)
      [ "$#" -ge 2 ] || { echo "ERROR: --service requires a value" >&2; exit 2; }
      SERVICE="$2"
      shift 2
      ;;
    --backup-path)
      [ "$#" -ge 2 ] || { echo "ERROR: --backup-path requires a value" >&2; exit 2; }
      BACKUP_PATH="$2"
      shift 2
      ;;
    --target)
      [ "$#" -ge 2 ] || { echo "ERROR: --target requires a value" >&2; exit 2; }
      RESTORE_TARGET="$2"
      shift 2
      ;;
    --scope)
      [ "$#" -ge 2 ] || { echo "ERROR: --scope requires a value" >&2; exit 2; }
      SCOPE="$2"
      shift 2
      ;;
    --rto)
      [ "$#" -ge 2 ] || { echo "ERROR: --rto requires a value" >&2; exit 2; }
      RTO="$2"
      shift 2
      ;;
    --rpo)
      [ "$#" -ge 2 ] || { echo "ERROR: --rpo requires a value" >&2; exit 2; }
      RPO="$2"
      shift 2
      ;;
    --owner)
      [ "$#" -ge 2 ] || { echo "ERROR: --owner requires a value" >&2; exit 2; }
      OWNER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

HOSTNAME_VALUE="$(hostname 2>/dev/null || printf 'unknown')"
[ -z "$SYSTEM_NAME" ] && SYSTEM_NAME="$HOSTNAME_VALUE"
GENERATED_AT="$(date -Iseconds 2>/dev/null || date)"
EUID_VALUE="$(id -u 2>/dev/null || printf 'unknown')"
USER_VALUE="$(id -un 2>/dev/null || printf 'unknown')"
[ -z "$BACKUP_PATH" ] && BACKUP_PATH="not configured"

cat <<PLAN
# SASD Restore Drill Plan

- Generated: $GENERATED_AT
- Host creating plan: $HOSTNAME_VALUE
- User: $USER_VALUE
- Effective UID: $EUID_VALUE
- System under review: $SYSTEM_NAME
- Service/application: $SERVICE
- Backup path/reference: $BACKUP_PATH
- Restore target: $RESTORE_TARGET
- Scope: $SCOPE
- RTO: $RTO
- RPO: $RPO
- Owner: $OWNER

> Read-only planning document. This script does not restore, copy, overwrite,
> delete, decrypt, mount or change anything. Use this checklist to plan and
> record a manual restore validation.

## Purpose

A backup is only credible after restore has been tested. This checklist helps
separate backup existence from restore capability.

## Preconditions

- [ ] The restore target is isolated from production.
- [ ] The restore target has enough disk space.
- [ ] Required credentials, encryption keys or key escrow procedures are known.
- [ ] The selected backup timestamp is documented.
- [ ] The expected data scope is documented.
- [ ] The person performing the drill understands what must not be overwritten.

## Backup selection

| Item | Value |
| --- | --- |
| Backup set selected | TODO |
| Backup timestamp | TODO |
| Backup source path | $BACKUP_PATH |
| Manifest file used | TODO |
| Hash/checksum available | TODO |
| Encryption/key requirement | TODO |
| Expected application version | TODO |

## Restore procedure outline

1. Prepare an isolated restore target.
2. Record package/service/database versions on the restore target.
3. Copy or attach the selected backup according to the documented process.
4. Restore into a non-production path, database, VM or container.
5. Start only the services required for validation.
6. Validate files, ownership, permissions, database schemas and application smoke tests.
7. Record differences and missing assumptions.
8. Destroy or archive the test environment according to policy.

## Validation checklist

- [ ] Restore completed without unexpected errors.
- [ ] Restored data count/size roughly matches expectation.
- [ ] File ownership and permissions are plausible.
- [ ] Service/application starts in the restore target.
- [ ] Important application functions were tested.
- [ ] Logs from the restore attempt were saved.
- [ ] RTO was measured.
- [ ] RPO was assessed.
- [ ] Gaps were written down as follow-up tasks.

## Result record

| Field | Value |
| --- | --- |
| Drill date | TODO |
| Performed by | TODO |
| Result | TODO: success / partial / failed |
| Time to restore | TODO |
| Data loss window observed | TODO |
| Main issue found | TODO |
| Follow-up ticket/link | TODO |

## Notes

- Do not treat a fresh backup file as proof of recoverability.
- Do not test restore by overwriting production.
- Do not expose generated reports publicly before reviewing paths, usernames,
  hostnames, database names and service names.
PLAN

exit 0
