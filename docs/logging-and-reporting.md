# Logging and Reporting

The logging scripts are read-only helpers for routine administration and incident
triage.

## sasd-auth-log-report.sh

Summarizes authentication-related activity from `journalctl` or traditional log
files such as `/var/log/auth.log` and `/var/log/secure`.

Example:

```bash
scripts/logging/sasd-auth-log-report.sh --since yesterday --limit 30
```

The report includes counts and samples for:

- failed SSH/authentication attempts
- accepted SSH logins
- sudo command entries
- su/root session entries

Running as root may provide a more complete view on systems with restricted log
access.
