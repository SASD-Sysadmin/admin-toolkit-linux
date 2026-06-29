# Script safety

The repository is conservative by design. Scripts should be readable, reviewable and safe by default.

## Default behavior

Scripts should not modify the system unless this is explicitly documented and protected by an option such as `--apply`.

Preferred default behavior:

- collect facts
- print reports
- show warnings
- return useful exit codes
- avoid automatic repair

## Elevated privileges

Some checks produce better results when run as root. A script should still degrade gracefully when possible.

Before running a script with elevated privileges:

1. Read the script.
2. Run it with `--help`.
3. Test it in a lab system.
4. Redirect output to a report file if you need evidence.

## Data hygiene

Do not commit:

- secrets
- tokens
- private keys
- customer names
- internal production IP addresses
- personal data
- raw incident data

Use sanitized examples under `examples/`.
