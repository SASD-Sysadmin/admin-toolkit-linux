# Suggested initial GitHub issues

These issues can be created manually to make the repository look planned and maintained.

## Milestone 0: Repository foundation

1. `docs: rename README heading and explain admin-toolkit repository family`
   - Update the README heading to `admin-toolkit-linux`.
   - Add a short note about future repositories such as `admin-toolkit-freebsd`, `admin-toolkit-macos` and `admin-toolkit-solaris`.

2. `docs: add project roadmap`
   - Add `ROADMAP.md` with milestones for host documentation, security audit, logging, monitoring, FIM, backup and Ansible.

3. `repo: add issue and pull request templates`
   - Add templates for script proposals, bugs, documentation and roadmap tasks.
   - Add a PR checklist with safety and testing checks.

## Milestone 1: Host documentation baseline

4. `script: improve host inventory output format`
   - Review current host inventory output.
   - Decide whether Markdown or JSON output should be added later.

5. `docs: add sample host report`
   - Generate sanitized example output.
   - Remove private hostnames, IP addresses and personal data.

## Milestone 2: Read-only security audit baseline

6. `script: add sudoers audit helper`
   - Check `/etc/sudoers` and `/etc/sudoers.d` safely.
   - Prefer read-only validation and human-readable output.

7. `script: add system account login audit`
   - Report system accounts with interactive shells.
   - Explain false positives and review requirements.

8. `script: add sensitive files check`
   - Look for `.env`, private keys and backup-like files in selected paths.
   - Avoid scanning the whole filesystem by default.

## Milestone 3: Logging and operational review

9. `script: add auth log report`
   - Summarize failed SSH logins, successful SSH logins and sudo usage.
   - Support journald first.

10. `script: add kernel warnings report`
    - Summarize recent kernel warnings from journald.
    - Keep output suitable for daily admin review.

## Milestone 4: Monitoring checks

11. `script: add disk usage monitoring check`
    - Use exit codes 0/1/2/3.
    - Support warning and critical thresholds.

12. `script: add inode usage monitoring check`
    - Use exit codes 0/1/2/3.
    - Support warning and critical thresholds.

## Milestone 5: File integrity monitoring

13. `script: add FIM baseline creator`
    - Create checksums for selected files.
    - Store output in a simple, documented format.

14. `script: add FIM baseline checker`
    - Compare current files against a baseline.
    - Report added, removed and changed files.
