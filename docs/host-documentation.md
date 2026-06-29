# Host Documentation

Host documentation scripts collect operational facts about a Linux system. They do not change configuration.

## Included scripts

- `scripts/host-doc/sasd-host-inventory.sh`
- `scripts/host-doc/sasd-service-inventory.sh`
- `scripts/host-doc/sasd-package-inventory.sh`

## Typical workflow

```bash
mkdir -p reports
bash scripts/host-doc/sasd-host-inventory.sh > reports/host-inventory.md
bash scripts/host-doc/sasd-service-inventory.sh > reports/service-inventory.md
bash scripts/host-doc/sasd-package-inventory.sh > reports/package-inventory.md
```

## Why this matters

A small company often lacks a current server inventory. A readable report makes operating system version, active services, packages, storage and networking visible before hardening or migration work begins.
