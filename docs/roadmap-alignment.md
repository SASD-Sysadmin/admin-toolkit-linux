# Roadmap alignment note

This note explains how the implementation history maps to `ROADMAP.md`.

## Important distinction

The development conversation used labels such as `Phase 2`, `Phase 3` and
`Phase 8`. These are implementation batches, not roadmap milestones.

Roadmap milestones describe product maturity and topic areas:

- repository foundation
- host documentation
- read-only security audit
- logging and operations
- monitoring checks
- file integrity monitoring
- backup and restore validation
- Ansible preparation

Implementation phases describe the order in which files were created and tested.
They may cross milestone boundaries.

## Current state

The project is best understood as a `v0.1.0` release candidate for a read-only
Linux administration toolkit.

The read-only baseline is intentionally stronger than the original early
roadmap. Additional reporting was added for cron, systemd timers, database
inventory, firewall state, auditd visibility, symlink-aware permission review and
release readiness.

## Recommendation

Before starting Ansible or automatic remediation, finish the first release:

1. Update `ROADMAP.md` to reflect actual progress.
2. Fix release-readiness Markdown output.
3. Review README, script index and CHANGELOG on GitHub.
4. Run `make check && make smoke` on a clean worktree.
5. Run `scripts/reporting/sasd-release-readiness.sh`.
6. Tag `v0.1.0` only after human review.
