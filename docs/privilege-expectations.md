# Privilege Expectations

This project prefers read-only scripts that remain useful without root access.
Some reports, however, are naturally more complete when they can inspect
protected paths such as `/var/log/private`, `/root`, `/etc/ssl/private` or
service-specific state directories.

The goal is not to force every script to run as root. The goal is to make report
completeness visible.

## Policy

Scripts should use one of these privilege expectations:

| Level | Meaning | Expected behavior |
| --- | --- | --- |
| No root needed | Normal user access is enough for the intended result. | Run normally and avoid root-only assumptions. |
| Root recommended | Normal user output is useful but incomplete. | Run best-effort, show an informational note and include scan warnings. |
| Root required | Output would be misleading or impossible without root. | Exit with a clear message and non-zero status. |

Most scripts in this repository should be either **No root needed** or
**Root recommended**.

## Why permission-denied output is not always a bug

A report such as a log-volume scan can legitimately show warnings like:

```text
find: '/var/log/private': Permission denied
find: '/var/log/gdm3': Permission denied
```

That means the script ran as a non-root user and could not inspect protected log
subtrees. The report may still be useful, but its completeness is partial.

Do not silently hide these warnings by default. They explain why a report may not
cover everything.

## Recommended wording for scripts

When a script can run without root but produces a more complete result with root,
use wording like this near the top of the report:

```text
Privilege: non-root
Completeness: best-effort; protected paths may be skipped
Hint: rerun with sudo for a more complete report
```

When running as root:

```text
Privilege: root
Completeness: full subject to filesystem availability and tool support
```

## Script categories

### Usually no root needed

- README and documentation checks
- Basic package inventory
- Basic service inventory
- Release-readiness checks
- Some monitoring-style checks

### Root recommended

- `/var/log` volume reports
- authentication and sudo log review
- world-writable scans across `/`
- root-owned writable reports
- sensitive file permission reports
- deleted-open-files reports
- backup checks on protected backup locations

### Root required only when unavoidable

Avoid root-required behavior unless a script would otherwise be misleading. Even
then, prefer a clear message over a stack trace or raw command failure.

## Implementation backlog

Planned later improvements:

- Add a small shared wording pattern to relevant scripts.
- Add `Privilege` and `Completeness` lines to reports that scan protected paths.
- Keep raw scan warnings available in the report.
- Avoid converting every permission-denied warning into a hard failure.

## Safety reminder

Running a script with `sudo` can reveal more system details in the generated
report. Review reports for usernames, hostnames, paths, IP addresses, service
names and environment-specific data before sharing them.
