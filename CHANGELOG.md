# Changelog

All notable changes to this project should be documented in this file.

The project currently uses a simple, human-readable changelog because it is an early-stage administration toolkit.

## Unreleased

### Added

- Added cron and systemd timer reporting scripts.
- Added firewall and auditd status reporting scripts.
- Added conservative MariaDB/MySQL inventory script.
- Added documentation for scheduling, security controls and database inventory.
- Extended the read-only collector with the new reports.
- Added a detailed README script index.
- Added `docs/script-index.md` as a dedicated overview of all current scripts.
- Added `docs/testing.md` with local validation and smoke-test guidance.
- Added `.gitattributes` to keep line endings predictable across Windows, WSL and Linux.
- Added `reports/.gitkeep` while generated report content remains ignored.

### Changed

- Extended the `Makefile` with local `help`, `list-scripts`, `file-modes`, `check`, `smoke` and `clean-reports` targets.
- Improved `.gitignore` handling for generated local report output.
- Improved `sasd-world-writable-audit.sh` with path, exclude, max-result and output-format options.

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
- Documentation for repository strategy, script safety, backup validation, FIM, account baselines and operational reporting.

### Changed

- Moved GitHub Actions workflows to documentation examples so the repository can be maintained locally first.
- Improved SSH configuration handling for WSL, containers and systems without OpenSSH server configuration.
- Improved summary Markdown generation to avoid nested code fence rendering problems.
