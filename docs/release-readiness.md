# Release Readiness

This project intentionally avoids fake activity and over-engineering. A release
candidate should be tagged only when the repository is useful, understandable and
safe to run locally.

## Local readiness command

```bash
./scripts/reporting/sasd-release-readiness.sh
```

Optional smoke run:

```bash
./scripts/reporting/sasd-release-readiness.sh --run-smoke
```

The readiness script is read-only. It checks repository hygiene and local test
results. It does not create tags, commits, releases or GitHub Actions.

## Suggested v0.1.0 gate

Before tagging `v0.1.0`, check:

1. `git status` is clean.
2. `git diff --check` passes.
3. `make check` passes.
4. `make smoke` creates a report with no collector execution errors.
5. `README.md` explains the read-only safety model.
6. `docs/script-index.md` gives a useful overview.
7. `CHANGELOG.md` describes the first release honestly.
8. Generated reports are ignored except for `reports/.gitkeep`.
9. Findings are not presented as automatic proof of compromise.

## Release tag command

Only after human review:

```bash
git tag -a v0.1.0 -m "v0.1.0 initial read-only Linux admin toolkit"
git push origin v0.1.0
```
