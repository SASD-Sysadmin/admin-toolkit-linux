# Privilege and completeness contract

This document defines the wording we should use consistently when scripts are
more or less complete depending on privileges, readable paths or host tooling.

The goal is not to force every script to run as root. The goal is to make the
level of confidence visible.

## Privilege field

Scripts and collectors should prefer this vocabulary:

| Value | Meaning |
| --- | --- |
| `root` | Effective UID is 0. Protected paths are more likely to be visible. |
| `non-root` | Effective UID is not 0. Some paths/logs may be incomplete. |
| `unknown` | Privilege state could not be determined. |

Recommended report line:

```text
- Privilege: non-root
```

## Completeness field

Where useful, scripts should also state completeness:

| Value | Meaning |
| --- | --- |
| `complete` | The script believes the selected scope was fully visible. |
| `partial` | Some expected sources were unavailable or unreadable. |
| `best-effort` | The script is useful but cannot reliably know what is missing. |
| `unknown` | Completeness cannot be evaluated. |

Recommended report line:

```text
- Completeness: partial
```

## Non-root behavior

Scripts should avoid wasting time on scans that are likely to fail late. A good
pattern is:

1. Detect privilege early.
2. Detect obviously unreadable configured paths early.
3. Report skipped or unreadable paths explicitly.
4. Continue with readable paths where useful.
5. Return a meaningful status only when the command itself failed.

## Permission denied handling

Do not hide permission-denied signals completely. Prefer a small, bounded
summary:

```text
Permission-denied entries observed: 12
Completeness: partial
```

Large raw permission-denied output should be capped or written to a separate
section so reports stay readable.

## Long-running scans

For long-running scans, scripts should prefer:

- default result limits
- explicit `--full` or `--max-results` flags
- preflight notes for non-root users
- path-scoped operation where possible

The existing world-writable and permission-risk reports already follow this
style partly. The quality pass should gradually apply the same pattern to other
scripts that scan protected directories or large filesystem trees.

## Role profile interaction

Role profiles should not make scripts magically privileged. Instead, profile
reports should make context visible:

```text
Profile: database-server
Privilege: non-root
Completeness: partial
Reason: database logs or protected config paths may be incomplete as non-root.
```

This keeps review honest and avoids false confidence.
