# Roadmap

This roadmap keeps `admin-toolkit-linux` focused. The repository should grow from small, safe, readable scripts into a practical Linux administration toolbox for small-company operations, lab systems and portfolio use.

## Guiding rule

Audit and documentation first. Configuration changes later.

Every new script should be useful on its own, easy to review, safe by default and documented with at least one realistic example.

## Milestone 0: Repository foundation

Goal: make the repository look maintained, safe and navigable.

Tasks:

- [x] Add starter repository structure
- [x] Add README, LICENSE, SECURITY and CHANGELOG
- [x] Add shell syntax checks
- [x] Add script safety documentation
- [x] Rename README heading to `admin-toolkit-linux`
- [x] Add roadmap and contribution workflow
- [x] Add issue templates for scripts, bugs and documentation
- [x] Add pull request template
- [x] Fix file modes so only executable scripts have the executable bit

Exit criteria:

- A visitor understands the purpose of the repository in less than one minute.
- It is clear that scripts are read-only unless explicitly documented otherwise.
- There is an obvious path for future work.

## Milestone 1: Host documentation baseline

Goal: document a Linux host without changing it.

Planned scripts:

- `scripts/host-doc/sasd-host-inventory.sh`
- `scripts/host-doc/sasd-service-inventory.sh`
- `scripts/host-doc/sasd-package-inventory.sh`
- `scripts/host-doc/sasd-network-inventory.sh`
- `scripts/host-doc/sasd-storage-inventory.sh`

Planned documentation:

- `docs/host-documentation.md`
- `examples/sample-host-report.md`

Exit criteria:

- A Debian or Ubuntu host can be documented with readable command output.
- Sample output contains no real secrets, private IP ranges from customer systems or personal data.
- Scripts run without root where possible and clearly state when elevated privileges improve results.

## Milestone 2: Read-only security audit baseline

Goal: make typical Linux risks visible without automatically fixing them.

Planned scripts:

- `scripts/security/sasd-open-ports-audit.sh`
- `scripts/security/sasd-suid-sgid-audit.sh`
- `scripts/security/sasd-world-writable-audit.sh`
- `scripts/security/sasd-ssh-baseline-check.sh`
- `scripts/security/sasd-sudoers-audit.sh`
- `scripts/security/sasd-system-accounts-audit.sh`
- `scripts/security/sasd-sensitive-files-check.sh`

Planned documentation:

- `docs/security-audit.md`
- `examples/sample-security-report.md`

Exit criteria:

- The scripts identify risks but do not modify the system.
- Output explains what was checked and what requires human review.
- Risky findings are worded carefully; not every finding is automatically a vulnerability.

## Milestone 3: Logging and operational review

Goal: provide small, useful log review helpers for daily operations.

Planned scripts:

- `scripts/logging/sasd-journal-errors.sh`
- `scripts/logging/sasd-auth-log-report.sh`
- `scripts/logging/sasd-sudo-usage-report.sh`
- `scripts/logging/sasd-kernel-warnings.sh`
- `scripts/logging/sasd-log-volume-report.sh`

Planned documentation:

- `docs/logging-and-reporting.md`
- `examples/sample-log-report.md`

Exit criteria:

- Scripts support systemd-journald first.
- Scripts degrade gracefully on systems without expected log files.
- Reports are useful for a daily admin review.

## Milestone 4: Monitoring plugin examples

Goal: provide simple monitoring checks with predictable output and exit codes.

Planned checks:

- `scripts/monitoring/check_service_active.sh`
- `scripts/monitoring/check_reboot_required.sh`
- `scripts/monitoring/check_certificate_expiry.sh`
- `scripts/monitoring/check_disk_usage.sh`
- `scripts/monitoring/check_inodes.sh`
- `scripts/monitoring/check_updates_available.sh`

Exit criteria:

- Checks use monitoring-style exit codes: `0 OK`, `1 WARNING`, `2 CRITICAL`, `3 UNKNOWN`.
- Each check has `--help` or clear usage output.
- Checks can be used by a human or integrated into Icinga/Nagios-compatible systems later.

## Milestone 5: File integrity monitoring baseline

Goal: detect important file changes with simple, understandable tooling.

Planned scripts:

- `scripts/security/sasd-fim-baseline.sh`
- `scripts/security/sasd-fim-check.sh`
- `scripts/security/sasd-fim-report.py` or `scripts/security/sasd-fim-report.pl`

Planned documentation:

- `docs/file-integrity-monitoring.md`
- `examples/sample-fim-report.md`

Exit criteria:

- A baseline can be created for selected files and directories.
- Later checks can show added, removed and changed files.
- The documentation explains limitations and why this is not a replacement for a full EDR/SIEM solution.

## Milestone 6: Backup and restore validation

Goal: make backup state and restore testability visible.

Planned scripts:

- `scripts/backup/sasd-rsync-snapshot.sh`
- `scripts/backup/sasd-backup-age-check.sh`
- `scripts/backup/sasd-restore-test.sh`
- `scripts/backup/sasd-git-bundle-backup.sh`

Exit criteria:

- The repository demonstrates the principle that backup without restore testing is incomplete.
- No script deletes backup data by default.
- Example workflows are suitable for lab and small-company use.

## Milestone 7: Ansible baseline preparation

Goal: add configuration management only after the read-only toolbox is useful.

Planned structure:

```text
ansible/
  inventories/
  playbooks/
  roles/
    base-packages/
    chrony/
    ssh/
    auditd/
    firewall/
```

Exit criteria:

- Ansible playbooks are clearly separated from audit scripts.
- Roles are conservative and documented.
- Potentially disruptive changes are opt-in and easy to review.

## Repository family direction

The `admin-toolkit-*` naming scheme is intended to keep operating-system-specific toolkits close together in alphabetical views.

Possible later repositories:

- `admin-toolkit-freebsd`
- `admin-toolkit-linux`
- `admin-toolkit-macos`
- `admin-toolkit-openbsd`
- `admin-toolkit-solaris`

Do not create empty sibling repositories too early. A new repository should exist only when there is enough material to make it useful on its own.

## Out of scope for now

- offensive security tooling
- unauthorised scanning
- automatic remediation as default behavior
- customer-specific scripts
- secrets, tokens, private keys or internal production data
- large configuration frameworks before the small scripts are mature
