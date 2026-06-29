# Account baseline and drift checks

The account baseline scripts document local users and groups in a simple TSV format.
The goal is to detect account drift over time.

## Scripts

- `scripts/accounts/sasd-account-baseline.sh`
- `scripts/accounts/sasd-account-diff.sh`

## Create a baseline

```bash
./scripts/accounts/sasd-account-baseline.sh > accounts-before.tsv
```

Running the baseline as root can include better password status information from
`/etc/shadow`, but the script never exports password hashes.

```bash
sudo ./scripts/accounts/sasd-account-baseline.sh > accounts-before-root.tsv
```

## Compare baselines

```bash
./scripts/accounts/sasd-account-baseline.sh > accounts-after.tsv
./scripts/accounts/sasd-account-diff.sh --old accounts-before.tsv --new accounts-after.tsv
```

A changed account appears as one removed row and one added row. This is simple on
purpose: the diff stays easy to review and does not hide account drift behind complex
logic.
