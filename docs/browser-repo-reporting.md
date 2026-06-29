# Browser repository reporting

`scripts/config/sasd-browser-repo-report.sh` reports browser-related package
repositories and package hints.

It is useful on workstations and mixed developer machines where browsers may
bring additional vendor repositories, keyrings and scheduled jobs.

The script reports:

- browser-related installed package hints
- APT source files mentioning common browser vendors
- keyring files with browser/vendor naming hints
- optional source snippets with `--show-files`

Example:

```bash
./scripts/config/sasd-browser-repo-report.sh
./scripts/config/sasd-browser-repo-report.sh --show-files --max-lines 80
```

The script does not judge whether a vendor repository is good or bad. It makes
it visible so an administrator can decide whether it is still needed.
