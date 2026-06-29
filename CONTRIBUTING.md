# Contributing

This repository is intentionally conservative. Contributions should make Linux administration easier to document, review and repeat without surprising the operator.

## Principles

- Prefer small, readable scripts over clever one-liners.
- Prefer read-only audit and documentation helpers before remediation tools.
- Do not include secrets, customer data, private IPs from real environments, tokens or private keys.
- Make potentially disruptive behavior opt-in and visible.
- Document assumptions and tested distributions.

## Script requirements

Every script should have:

- a clear purpose in the file header
- `--help` or clear usage output
- predictable output
- safe defaults
- useful exit codes
- no silent destructive behavior
- examples in documentation or under `examples/`

Shell scripts should pass:

```bash
bash -n path/to/script.sh
shellcheck path/to/script.sh
```

## Documentation requirements

Markdown should be readable in GitHub and pass the repository Markdown lint workflow. Keep examples sanitized and avoid production-specific data.

## Pull requests

A good pull request explains:

- what problem is solved
- how the change was tested
- whether the script is read-only or can change the system
- what operating systems or distributions were used for testing
