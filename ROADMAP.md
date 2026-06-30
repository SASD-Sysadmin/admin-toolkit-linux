# Roadmap

This roadmap keeps `admin-toolkit-linux` focused. The repository grows from
small, safe, readable scripts into a practical Linux administration toolbox for
small-company operations, lab systems and portfolio use.

## Guiding rule

Audit and documentation first. Configuration-changing automation later.

Every new script should be useful on its own, easy to review, safe by default
and documented with at least one realistic example. The default behavior is
read-only unless a future script explicitly documents otherwise.

## Phase numbers versus roadmap milestones

The `Phase 1`, `Phase 2`, ... names used during development are implementation
batches from the ChatGPT-assisted build process. They are not the same thing as
roadmap milestones.

Roadmap milestones describe product maturity and topic areas. Implementation
phases describe the order in which files happened to be created.

Current direction: keep a coherent read-only toolkit before starting
configuration-changing automation or Ansible roles.

## Current release target: v0.1.x read-only toolkit

Goal: a trustworthy read-only Linux admin toolkit that a visitor can understand,
run locally and review without needing GitHub Actions or external services.

Release criteria:

- [x] Repository has README, LICENSE, SECURITY, CHANGELOG and ROADMAP.
- [x] Scripts are read-only by default.
- [x] Local checks run with `make check`.
- [x] Local smoke reports can be generated with `make smoke`.
- [x] Generated reports are ignored by Git, except `reports/.gitkeep`.
- [x] Permission reporting handles Linux symlink metadata carefully.
- [x] A findings summary exists for quick triage.
- [x] A release-readiness script exists.
- [x] Focused host inventory, logging and backup review collectors exist.
- [x] README, script index and CHANGELOG are reviewed and maintained.
- [x] Final `make check && make smoke` passes on a clean working tree.
- [x] Release readiness reports blocking failures as zero.
- [ ] Confirm whether the local `v0.1.0` tag is already on the intended commit
  and pushed to the remote.
- [ ] Final human review confirms that no real secrets or customer data exist in
  examples or generated sample reports.

## Cross-cutting follow-up: privilege awareness

Goal: make report completeness visible without forcing every script to run as
root.

Status: documented as a planned quality improvement.

Planned approach:

- [x] Document privilege expectations in `docs/privilege-expectations.md`.
- [ ] Add a common wording pattern to scripts that scan protected directories.
- [ ] Add report headers such as `Privilege: root` or `Privilege: non-root`.
- [ ] Add report completeness hints such as `complete`, `partial` or
  `best-effort` where useful.
- [ ] Keep scripts usable as normal users whenever partial output is still
  valuable.

Important rule: do not hide permission-denied signals completely. They explain
why a report may be incomplete. Prefer clear context over silent suppression.

## Milestone 0: Repository foundation

Goal: make the repository look maintained, safe and navigable.

Status: complete for the current read-only baseline.

Completed:

- [x] Add starter repository structure.
- [x] Add README, LICENSE, SECURITY and CHANGELOG.
- [x] Add ROADMAP and contribution workflow.
- [x] Add issue and pull request templates as documentation structure.
- [x] Add local shell syntax checks.
- [x] Add script safety documentation.
- [x] Normalize line endings with `.gitattributes`.
- [x] Add local smoke-test and release-readiness checks.

Still useful later:

- [ ] Decide whether to keep GitHub Actions only as examples or enable them.

Exit criteria:

- A visitor understands the purpose of the repository in less than one minute.
- It is clear that scripts are read-only unless explicitly documented otherwise.
- There is an obvious path for future work.

## Milestone 1: Host documentation baseline

Goal: document a Linux host without changing it.

Status: complete for the current read-only baseline.

Implemented:

- [x] `scripts/host-doc/sasd-host-inventory.sh`
- [x] `scripts/host-doc/sasd-service-inventory.sh`
- [x] `scripts/host-doc/sasd-package-inventory.sh`
- [x] `scripts/host-doc/sasd-network-inventory.sh`
- [x] `scripts/host-doc/sasd-storage-inventory.sh`
- [x] `scripts/reporting/sasd-run-host-inventory.sh`
- [x] `docs/host-documentation.md`
- [x] `docs/milestone-1-host-documentation-status.md`
- [x] `examples/sample-host-report.md`

Still useful later:

- [ ] Add sanitized full host inventory sample output from a lab VM.
- [ ] Add optional JSON/TSV output for selected inventory scripts.
- [ ] Add role-specific host profiles such as workstation, web server and
  database host.
- [ ] Add deeper virtualization/container and bare-metal hardware inventory.

Exit criteria:

- A Debian or Ubuntu host can be documented with readable command output.
- Sample output contains no real secrets, private IP ranges from customer systems
  or personal data.
- Scripts run without root where possible and clearly state when elevated
  privileges improve results.
- Network and storage inventory are captured without active scanning or system
  changes.

## Milestone 2: Read-only security audit baseline

Goal: make typical Linux risks visible without automatically fixing them.

Status: complete for the current baseline and already extended beyond the
original baseline.

Implemented:

- [x] `scripts/security/sasd-open-ports-audit.sh`
- [x] `scripts/security/sasd-suid-sgid-audit.sh`
- [x] `scripts/security/sasd-world-writable-audit.sh`
- [x] `scripts/security/sasd-ssh-baseline-check.sh`
- [x] `scripts/config/sasd-sudoers-report.sh`
- [x] `scripts/security/sasd-system-accounts-audit.sh`
- [x] `scripts/security/sasd-sensitive-files-check.sh`
- [x] `scripts/security/sasd-permission-risk-report.sh`
- [x] `scripts/security/sasd-root-owned-writable-report.sh`
- [x] `scripts/security/sasd-symlink-target-report.sh`
- [x] `scripts/security/sasd-firewall-status-report.sh`
- [x] `scripts/security/sasd-auditd-status-report.sh`
- [x] `scripts/reporting/sasd-findings-summary.sh`

Still useful later:

- [ ] Improve severity model with configurable host roles.
- [ ] Add optional JSON/TSV output for selected security reports.

Exit criteria:

- The scripts identify risks but do not modify the system.
- Output explains what was checked and what requires human review.
- Risky findings are worded carefully; not every finding is automatically a
  vulnerability.

## Milestone 3: Logging and operational review

Goal: provide small, useful log review helpers for daily operations.

Status: complete for the current read-only baseline.

Implemented:

- [x] `scripts/logging/sasd-journal-errors.sh`
- [x] `scripts/logging/sasd-auth-log-report.sh`
- [x] `scripts/logging/sasd-sudo-usage-report.sh`
- [x] `scripts/logging/sasd-kernel-warnings.sh`
- [x] `scripts/logging/sasd-log-volume-report.sh`
- [x] `scripts/config/sasd-journald-config-report.sh`
- [x] `scripts/config/sasd-logrotate-report.sh`
- [x] `scripts/reporting/sasd-run-logging-review.sh`
- [x] `docs/logging-milestone-3.md`
- [x] `examples/sample-logging-review-index.md`

Still useful later:

- [ ] Add privilege/completeness headers to logging reports.
- [ ] Add optional filtering for noisy known WSL or desktop kernel messages.
- [ ] Add optional TSV/JSON output for selected log summaries.
- [ ] Add sanitized sample outputs for sudo, kernel and log-volume reports.

Exit criteria:

- Scripts support systemd-journald first.
- Scripts degrade gracefully on systems without expected log files.
- Reports are useful for a daily admin review.
- Permission-denied cases are visible and explained rather than hidden.

## Milestone 4: Monitoring plugin examples

Goal: provide simple monitoring checks with predictable output and exit codes.

Status: mostly complete for the initial baseline.

Implemented:

- [x] `scripts/monitoring/check_service_active.sh`
- [x] `scripts/monitoring/check_reboot_required.sh`
- [x] `scripts/monitoring/check_certificate_expiry.sh`
- [x] `scripts/monitoring/check_disk_usage.sh`
- [x] `scripts/packages/sasd-update-status-report.sh`
- [x] `scripts/packages/sasd-reboot-required-report.sh`

Still planned:

- [ ] `scripts/monitoring/check_inodes.sh`
- [ ] Decide whether package update checks belong in `monitoring/` or remain in
  `packages/` as operational reports.

Exit criteria:

- Checks use monitoring-style exit codes where they are intended as checks.
- Each check has `--help` or clear usage output.
- Checks can be used by a human or integrated into Icinga/Nagios-compatible
  systems later.

## Milestone 5: File integrity monitoring baseline

Goal: detect important file changes with simple, understandable tooling.

Status: mostly complete for a simple baseline.

Implemented:

- [x] `scripts/security/sasd-fim-baseline.sh`
- [x] `scripts/security/sasd-fim-check.sh`
- [x] `examples/sample-fim-baseline.tsv`
- [x] `docs/file-integrity-monitoring.md`

Still planned:

- [ ] `scripts/security/sasd-fim-report.py` or
  `scripts/security/sasd-fim-report.pl`
- [ ] Sanitized `examples/sample-fim-report.md`

Exit criteria:

- A baseline can be created for selected files and directories.
- Later checks can show added, removed and changed files.
- The documentation explains limitations and why this is not a replacement for a
  full EDR/SIEM solution.

## Milestone 6: Backup and restore validation

Goal: make backup state and restore testability visible.

Status: complete for the current read-only baseline.

Implemented:

- [x] `scripts/backup/sasd-rsync-snapshot.sh`
- [x] `scripts/backup/sasd-backup-age-check.sh`
- [x] `scripts/backup/sasd-backup-location-report.sh`
- [x] `scripts/backup/sasd-backup-manifest.sh`
- [x] `scripts/backup/sasd-restore-drill-plan.sh`
- [x] `scripts/reporting/sasd-run-backup-review.sh`
- [x] `docs/backup-validation.md`
- [x] `docs/backup-age-check.md`
- [x] `docs/backup-restore-validation.md`
- [x] `docs/milestone-6-backup-restore-status.md`
- [x] `examples/sample-backup-review-index.md`

Still useful later:

- [ ] Add sanitized full backup review sample output.
- [ ] Add role-specific backup expectations for files, databases and Git repos.
- [ ] Add restore evidence template for manual restore drills.
- [ ] Add optional JSON output for selected backup reports.
- [ ] Consider `scripts/backup/sasd-git-bundle-backup.sh` as a future,
  explicitly documented backup-creation helper.

Exit criteria:

- The repository demonstrates the principle that backup without restore testing
  is incomplete.
- No script deletes backup data by default.
- Example workflows are suitable for lab and small-company use.
- Restore validation stays separated from production restore execution.

## Milestone 7: Ansible baseline preparation

Goal: add configuration management only after the read-only toolbox is useful.

Status: not started by design.

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

The `admin-toolkit-*` naming scheme is intended to keep operating-system-specific
toolkits close together in alphabetical views.

Possible later repositories:

- `admin-toolkit-freebsd`
- `admin-toolkit-linux`
- `admin-toolkit-macos`
- `admin-toolkit-openbsd`
- `admin-toolkit-solaris`

Do not create empty sibling repositories too early. A new repository should exist
only when there is enough material to make it useful on its own.

## Out of scope for now

- offensive security tooling
- unauthorised scanning
- automatic remediation as default behavior
- customer-specific scripts
- secrets, tokens, private keys or internal production data
- large configuration frameworks before the small scripts are mature
