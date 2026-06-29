# Repository strategy

`admin-toolkit-linux` is the first repository in the planned SASD `admin-toolkit-*` family.

## Why Linux first

Linux is the strongest starting point because it matches the current practical focus: host documentation, security audits, log review, monitoring checks, backup validation and small-company operations.

## Why not one repository for every Unix system immediately

Empty repositories look unfinished. A small number of useful, documented repositories is stronger than many placeholders.

Create a sibling repository only when there is enough operating-system-specific material to justify it.

## Naming convention

Use this pattern:

```text
admin-toolkit-<platform>
```

Examples:

```text
admin-toolkit-freebsd
admin-toolkit-linux
admin-toolkit-macos
admin-toolkit-openbsd
admin-toolkit-solaris
```

Use lowercase repository names for consistency and easier command-line use.

## Split rule

A new repository should be created only when all of these are true:

- it has at least five meaningful scripts or runbooks
- it has a README that explains its independent purpose
- it has safe examples
- it has a realistic roadmap
- it is not just a renamed copy of the Linux repository

## Shared standards

All repositories in the family should follow the same principles:

- readable before compact
- documented before magical
- read-only by default
- no secrets or customer data
- explicit opt-in for changes
- small scripts with clear operational purpose
