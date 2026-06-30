# Sample Host Inventory Report Index

This is a sanitized example of the focused host inventory collector output. It is
not generated from a real customer system.

```text
Report directory: ./reports/host-inventory-example
Index: ./reports/host-inventory-example/INDEX.md
```

## Expected files

| File | Purpose |
| --- | --- |
| `INDEX.md` | Entry point for the host inventory collection. |
| `status.tsv` | Exit status table for each inventory script. |
| `01-host-inventory.md` | OS, kernel, CPU, memory and runtime facts. |
| `02-service-inventory.md` | Service manager facts and service list. |
| `03-package-inventory.md` | Package manager and installed package facts. |
| `04-network-inventory.md` | Interfaces, addresses, routes and resolver context. |
| `05-storage-inventory.md` | Filesystems, mounts, block devices and swap context. |

## Example review order

1. Review `01-host-inventory.md` to understand the platform.
2. Review `04-network-inventory.md` to understand connectivity and naming.
3. Review `05-storage-inventory.md` to understand filesystems and capacity.
4. Review `02-service-inventory.md` and `03-package-inventory.md` to understand
   installed software and runtime services.

## Sanitization reminder

Before sharing real host inventory output, remove or review:

- hostnames
- usernames
- local paths
- IP addresses and DNS domains
- package and service names that reveal internal technology choices
- mount labels, UUIDs and network share paths
