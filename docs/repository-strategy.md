# Repository strategy

`admin-toolkit-linux` is the first repository in a possible SASD `admin-toolkit-*` family.

## Why one Linux repository first?

The first goal is to create a focused, useful and maintained Linux administration toolbox. Too many empty repositories would look unfinished and would increase maintenance work. This repository should become strong before other operating-system-specific repositories are created.

## Future repository family

Possible later repositories:

- `admin-toolkit-freebsd`
- `admin-toolkit-linux`
- `admin-toolkit-macos`
- `admin-toolkit-openbsd`
- `admin-toolkit-solaris`

The naming scheme keeps related repositories close together in alphabetical lists.

## Split rule

Create a new sibling repository only when there is enough material to make it useful on its own.

A new repository should have:

- a clear README
- at least a small but useful script set
- documentation
- example output
- safety notes
- basic checks or tests

## Language policy

Scripts do not have to be written in Perl. Use the language that makes the specific task easiest to read, test and maintain.

Suggested defaults:

- Bash for small Linux-native checks
- Python for structured reports and data transformation
- Perl for classic sysadmin text parsing when it is clearly useful
- Ansible for configuration management after the read-only baseline is mature
