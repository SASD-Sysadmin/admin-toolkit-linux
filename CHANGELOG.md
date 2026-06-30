# Changelog

All notable changes to this project should be documented in this file.

The project currently uses a simple, human-readable changelog because it is an
early-stage administration toolkit.

## Unreleased

### Added

- Added focused backup and restore validation review for Roadmap Milestone 6.
- Added backup location, backup manifest and restore drill planning scripts.
- Added focused logging review collection for Roadmap Milestone 3.
- Added sudo usage, kernel warning and log volume reporting scripts.
- Added release-readiness reporting for local release checks.
- Added symlink-aware permission reporting and symlink target review.
- Added PostgreSQL inventory alongside the existing MariaDB/MySQL inventory.
- Added cron and systemd timer reporting scripts.
- Added firewall and auditd status reporting scripts.
- Added conservative MariaDB/MySQL inventory script.
- Added documentation for backup/restore validation, logging review, release
  readiness, scheduling, security controls, database inventory and privilege
  expectations.
- Extended the read-only collector with additional operational and security
  reports.
- Added a detailed README script index.
- Added `docs/script-index.md` as a dedicated overview of all current scripts.
- Added `docs/testing.md` with local validation and smoke-test guidance.
- Added `.gitattributes` to keep line endings predictable across Windows, WSL
  and Linux.
- Added `reports/.gitkeep` while generated report content remains ignored.

### Changed

- Marked Roadmap Milestone 6 backup and restore validation as implemented for
  the current read-only baseline.
- Aligned `ROADMAP.md` with the current release-candidate state.
- Marked Roadmap Milestone 3 logging review as implemented for the current
  read-only baseline.
- Documented the difference between implementation phases and roadmap
  milestones.
- Documented privilege expectations for reports that are more complete when run
  as root.
- Improved backup age checks so an unconfigured backup path is informational in
  generic read-only collection runs.
- Improved permission reports so Linux symlink mode bits are not treated as
  direct high-risk permission findings.
- Extended the `Makefile` with local `help`, `list-scripts`, `file-modes`,
  `check`, `smoke` and `clean-reports` targets.
- Improved `.gitignore` handling for generated local report output.
- Improved `sasd-world-writable-audit.sh` with path, exclude, max-result and
  output-format options.

## Earlier phases

### Added

- Initial host documentation scripts.
- Initial read-only security audit scripts.
- Logging and monitoring helper scripts.
- File integrity baseline and check scripts.
- Account baseline and account diff scripts.
- Configuration audit scripts for sshd, sudoers, journald and logrotate.
- Package update and reboot-required reports.
- Read-only report collection script.
- Documentation for repository strategy, script safety, backup validation, FIM,
  account baselines and operational reporting.

### Changed

- Moved GitHub Actions workflows to documentation examples so the repository can
  be maintained locally first.
- Improved SSH configuration handling for WSL, containers and systems without
  OpenSSH server configuration.
- Improved summary Markdown generation to avoid nested code fence rendering
  problems.
