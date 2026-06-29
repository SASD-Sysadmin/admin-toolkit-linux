# Network and DNS checks

The network scripts are defensive documentation helpers. They should only query
hosts or networks you own or are explicitly allowed to review.

## Forward/reverse DNS check

Script:

- `scripts/network/sasd-forward-reverse-dns-check.sh`

Example:

```bash
./scripts/network/sasd-forward-reverse-dns-check.sh example.org www.example.org
```

Or from a file:

```bash
./scripts/network/sasd-forward-reverse-dns-check.sh --file hosts.txt --format markdown
```

The script does not scan networks. It only resolves hostnames that are explicitly
provided.
