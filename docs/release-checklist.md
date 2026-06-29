# Release Checklist

This project does not need a heavy release process. A small, honest checklist is enough.

## Before creating a tag

```bash
git status
make check
make smoke
git status --ignored -s | head -80
```

Confirm:

- working tree is clean except intentional changes
- shell syntax checks pass
- file mode checks pass
- no generated report output is staged
- README script index is current
- CHANGELOG has a short entry for the current work

## Suggested first tag

```bash
git tag -a v0.1.0 -m "v0.1.0 initial Linux admin toolkit"
git push origin v0.1.0
```

## Suggested release text

```text
Initial public version with host documentation, read-only security audit helpers,
account and configuration reports, package/reboot checks, file integrity helpers,
monitoring examples and a read-only report collection workflow.
```
