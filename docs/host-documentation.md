# Host Documentation Baseline

This document explains the host documentation baseline for `admin-toolkit-linux`.
The goal is to make a Linux host understandable before deeper security,
logging, backup, monitoring or configuration work starts.

The baseline is read-only. It does not change network settings, mount points,
filesystems, services or packages.

## Why host inventory matters

A useful administration review starts with facts:

- What system is this?
- Which interfaces and routes exist?
- Which filesystems and mount points exist?
- Which services are known to the service manager?
- Which packages are installed?
- Which facts are visible as a normal user and which require elevated access?

Without this context, later findings can be misread. A listening service, a full
filesystem, a log warning or a backup gap can only be judged against the intended
host role.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/host-doc/sasd-host-inventory.sh` | Basic host, OS, kernel, CPU and memory facts. |
| `scripts/host-doc/sasd-service-inventory.sh` | Service inventory where supported. |
| `scripts/host-doc/sasd-package-inventory.sh` | Package inventory for supported package managers. |
| `scripts/host-doc/sasd-network-inventory.sh` | Interfaces, addresses, routes, resolver context and network manager hints. |
| `scripts/host-doc/sasd-storage-inventory.sh` | Mounts, filesystems, block devices, swap and storage tool hints. |
| `scripts/reporting/sasd-run-host-inventory.sh` | Focused collector for the host documentation baseline. |

## Focused collector

Run a focused host inventory into a local report directory:

```bash
./scripts/reporting/sasd-run-host-inventory.sh \
  --output ./reports/host-inventory-local
```

Limit long command sections if needed:

```bash
./scripts/reporting/sasd-run-host-inventory.sh \
  --max-lines 80 \
  --output ./reports/host-inventory-short
```

The collector writes:

| Output | Meaning |
| --- | --- |
| `INDEX.md` | Report index and suggested review order. |
| `status.tsv` | Exit status of each inventory script. |
| `01-host-inventory.md` | Basic host inventory. |
| `02-service-inventory.md` | Service inventory. |
| `03-package-inventory.md` | Package inventory. |
| `04-network-inventory.md` | Network inventory. |
| `05-storage-inventory.md` | Storage inventory. |

## Network inventory notes

The network inventory script is intentionally local-only. It does not call an
external IP service and does not perform active scanning.

It can show:

- interface names and state
- assigned addresses visible through `ip`
- IPv4 and IPv6 routes
- default routes
- neighbor table when visible
- selected resolver configuration
- network service manager state
- optional interface driver hints when `ethtool` is available

Review before sharing because addresses, DNS search domains and route details can
reveal environment structure.

## Storage inventory notes

The storage inventory script is also read-only. It does not mount, unmount,
format, repair, resize or change any filesystem.

It can show:

- mounted filesystems
- byte and inode usage
- block-device topology
- swap configuration
- sanitized `/etc/fstab` lines
- LVM hints when tools are available
- software RAID hints from `/proc/mdstat` and `mdadm`
- ZFS and Btrfs hints when tools are available
- systemd mount and automount units

The `/etc/fstab` view redacts common credential-bearing options such as
`password=`, `credentials=`, `token=` and `key=`, but generated reports still
need human review before sharing.

## Root and completeness

Most host documentation scripts should be useful as a normal user. Some details
may be incomplete without elevated privileges, depending on distribution,
security policy and filesystem permissions.

Reports should therefore be interpreted as:

- complete enough for a first review when no protected paths are involved
- partial when protected paths, hidden device metadata or restricted service data
  are not visible
- a starting point for follow-up checks, not a final compliance statement

Do not make scripts root-only unless non-root execution is genuinely misleading.
Prefer clear `Privilege` and `Completeness` notes over hard failure.

## Suggested manual review questions

After generating a host inventory, ask:

- Does the hostname match the intended environment?
- Is the OS and kernel family expected?
- Are the default routes and DNS settings expected?
- Are there unexpected network interfaces, tunnels or bridge devices?
- Are important data paths mounted where expected?
- Is byte usage and inode usage plausible?
- Are service and package counts plausible for the host role?
- Does any report contain sensitive details that should be redacted before
  sharing?

## Relationship to later milestones

Host inventory supports later roadmap work:

- Security findings need host role context.
- Logging review needs service and journald context.
- Backup validation needs storage and mount context.
- Monitoring checks need filesystem and service names.
- Future Ansible baselines need reliable facts before changing configuration.
