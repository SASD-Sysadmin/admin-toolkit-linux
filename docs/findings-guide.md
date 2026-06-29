# Findings guide

This guide explains how to read common findings produced by `admin-toolkit-linux`.

The toolkit is read-only by design. A finding is a review hint. It is not proof of
compromise and it is not an instruction to run a repair command blindly.

## Severity language

| Severity | Meaning |
| --- | --- |
| `HIGH` | Review soon. The finding can be dangerous on a normal server. |
| `WARN` | Review in context. It may be acceptable for the host role. |
| `INFO` | Useful context. Usually not a problem by itself. |

## World-writable cron files

World-writable files in `/etc/cron.daily`, `/etc/cron.hourly`, `/etc/cron.d` or
similar directories are serious review items. Cron jobs can run with elevated
privileges. If a cron script is writable by everyone, another local user or a
compromised low-privilege process may be able to change scheduled execution.

Review questions:

- Who owns the file?
- Which package or installer created it?
- Is the file content expected?
- Is the mode intentionally broad or accidental?

## World-writable database configuration

Files such as `/etc/mysql/my.cnf`, PostgreSQL configuration files or include
directories should normally not be writable by everyone. Database configuration
can affect authentication, bind addresses, plugin loading, logging or data paths.

Review questions:

- Is the file root-owned or owned by the database service account?
- Is group write really needed?
- Is world write accidental?
- Does the file include other configuration directories?

## Inactive firewall

An inactive local firewall is not automatically wrong. WSL instances,
containers, lab hosts and machines behind a controlled perimeter may rely on
another layer. On exposed servers, a visible and intentional firewall policy is
usually expected.

Review questions:

- Is the host reachable from other machines?
- Are services bound to `0.0.0.0`, `[::]` or non-loopback addresses?
- Is firewalling handled by cloud security groups, a hypervisor or a perimeter
  firewall?

## auditd missing

Missing `auditd` is often normal on developer machines and WSL instances. On
security-sensitive Linux servers, audit logging may be required by policy.

Review questions:

- Is this a workstation, lab host or production server?
- Is host auditing handled by another EDR/SIEM agent?
- Are privileged command execution and authentication events logged elsewhere?

## System accounts with login shells

A system account with `/bin/bash` or another interactive shell is not always a
problem. Some service accounts need it for administration or maintenance tasks.
It is still worth reviewing because unnecessary shells increase attack surface.

Review questions:

- Does the account need interactive login?
- Is SSH login possible for that account?
- Is the home directory protected?
- Is the account locked or passwordless?

## Listening services beyond loopback

Services bound to `0.0.0.0`, `[::]` or non-loopback IP addresses may be reachable
from outside the host. This is expected for web servers and many infrastructure
services, but should match the host role.

Review questions:

- Which process owns the socket?
- Is the service intentionally exposed?
- Is it protected by firewall rules?
- Does it require authentication?

## Missing sshd configuration on WSL or containers

If `/etc/ssh/sshd_config` is missing, the host may simply not run an OpenSSH
server. This is normal on many WSL and container systems.

Review questions:

- Is `openssh-server` installed?
- Is `sshd` running?
- Does the host accept SSH connections from elsewhere?

## Recommended workflow

1. Run the read-only collector.
2. Open `INDEX.md`.
3. Read `89-findings-summary.md` first.
4. Follow links to the detailed report files.
5. Validate every finding before making changes.
6. Keep remediation separate from this repository unless an explicit `--apply`
   design exists.
