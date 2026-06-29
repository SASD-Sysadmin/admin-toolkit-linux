# Sample security report

This is sanitized example output. It demonstrates the expected style of findings.

## Open ports

```text
LISTEN 0 4096 0.0.0.0:22 0.0.0.0:* users:(("sshd",pid=1001,fd=3))
```

## SUID/SGID files

```text
/usr/bin/passwd
/usr/bin/sudo
```

## Review notes

These findings require human review. They are not automatically vulnerabilities.
