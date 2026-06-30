# Milestone 1 Host Documentation Status

Roadmap Milestone 1 focuses on documenting a Linux host without changing it.

## Current baseline

Implemented for the current read-only baseline:

- basic host inventory
- service inventory
- package inventory
- network inventory
- storage inventory
- focused host inventory collector
- host documentation runbook
- sanitized sample host report index

## Scope

The milestone is intentionally about inventory, not remediation.

The scripts should answer:

- What host is this?
- Which operating system and kernel are visible?
- Which packages and services are known?
- Which network interfaces, addresses, routes and resolver settings exist?
- Which filesystems, block devices, mount points and swap areas exist?
- Which parts of the inventory are visible without root?

## Remaining future enhancements

Useful later additions could include:

- optional JSON/TSV output for selected inventory scripts
- role-specific host profiles, such as workstation, web server or database host
- sanitized full example reports generated from a lab VM
- deeper virtualization/container detection
- optional hardware inventory for bare-metal systems

## Review policy

Generated host inventory reports can contain sensitive operational details.
Before publishing or attaching reports to issues, review:

- hostnames
- usernames
- paths
- package names
- service names
- IP addresses
- DNS search domains
- mount points
- filesystem labels or UUIDs
