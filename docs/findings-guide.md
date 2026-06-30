# Findings guide

This guide explains common findings produced by the read-only scripts. It is not
a remediation plan. Validate every finding before changing a system.

## Severity model

- `HIGH`: review soon; the finding can create a meaningful integrity or security risk.
- `WARN`: review in context; it may be acceptable depending on the host role.
- `INFO`: informational; often normal on desktops, WSL, containers or lab hosts.

## Symlink mode 777

On Linux, symlinks often appear as mode `777`. This is usually not the effective
permission of the target file. The toolkit therefore does not treat symlink mode
`777` alone as a direct `HIGH` finding.

Use this command to inspect link targets:

```bash
./scripts/security/sasd-symlink-target-report.sh --path /etc/mysql --path /etc/cron.daily
```

## World-writable cron targets

Cron entries should not be writable by everyone. If the finding is a symlink, the
target permissions are more important than the symlink mode.

Review:

- file content
- package ownership
- target path
- effective owner/group/mode

## World-writable database configuration targets

Database configuration files should not be writable by everyone. If a database
configuration path is a symlink, inspect the resolved target.

Review:

- whether the symlink target is expected
- whether target permissions are too broad
- whether the file belongs to a package or was manually changed

## System account with interactive shell

Some service accounts legitimately have shells. Others should not. The toolkit
reports this as a review item, not as automatic proof of misconfiguration.

## No visible firewall ruleset

A missing local firewall can be acceptable on WSL, containers, tightly controlled
lab systems or hosts protected by upstream firewalls. On servers, it should be an
intentional decision.

## auditd missing

The Linux audit subsystem is often not installed on developer machines. For
servers, audit requirements depend on operational, compliance and incident
response needs.
