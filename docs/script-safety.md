# Script Safety Standard

The repository is designed for conservative administration. The first implementation phase is read-only and report-oriented.

## Rules

1. Scripts must provide `--help`.
2. Scripts must avoid destructive actions by default.
3. Scripts must write normal results to stdout and warnings/errors to stderr.
4. Scripts must not require root unless the task truly needs it.
5. Scripts must not contain secrets, customer data or internal production identifiers.
6. Scripts must make external dependencies visible.
7. Security scripts must avoid active network scanning unless clearly documented.

## Preferred behavior

- `--help` explains purpose and risk.
- `--version` prints the script version.
- Exit code `0` means successful execution.
- Exit code `1` means script or check found a warning condition.
- Exit code `2` means critical condition or invalid use, depending on script type.
- Exit code `3` means unknown state for monitoring plugins.

## Running on production systems

Before running on production systems:

1. read the script
2. run it in a lab
3. run it without root first
4. redirect output into a report file
5. never pipe output directly into another privileged command
