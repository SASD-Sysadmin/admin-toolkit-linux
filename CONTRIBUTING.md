# Contributing

Thank you for improving `admin-toolkit-linux`.

This repository is intentionally conservative. It is meant to contain readable Linux administration scripts and runbooks that are useful for host documentation, security auditing, log review, monitoring checks, backup validation and small-company operations.

## General rules

- Keep scripts readable before clever.
- Prefer small focused tools over large all-in-one scripts.
- Default to read-only behavior.
- Do not include secrets, customer data, private hostnames or internal IP addresses.
- Do not add destructive actions without an explicit opt-in such as `--apply`.
- Explain limitations and assumptions in documentation.
- Prefer boring, dependable tools that are available on common Linux systems.

## Script expectations

Every script should aim to provide:

- clear purpose in the file header
- usage output or `--help`
- predictable exit codes
- stdout for normal result output
- stderr for warnings and errors
- no hidden network activity
- no automatic system modifications by default
- comments where the operational intent is not obvious

## Security-sensitive changes

Security-related scripts should report findings carefully. A finding can be suspicious, risky or worth reviewing without being a confirmed compromise.

Do not open public issues for real vulnerabilities affecting private systems. Follow `SECURITY.md` for sensitive reports.

## Testing

For shell scripts, run at least:

```bash
make syntax
```

If ShellCheck is available, also run:

```bash
shellcheck scripts/**/*.sh
```

## Pull request checklist

Before opening a pull request, check:

- [ ] The script or document has a clear purpose.
- [ ] The change is safe by default.
- [ ] No secrets, customer data or internal addresses are included.
- [ ] Example output is sanitized.
- [ ] Documentation or README references are updated if needed.
- [ ] Shell syntax checks pass for changed shell scripts.
