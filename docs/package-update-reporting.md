# Package Update Reporting

`sasd-update-status-report.sh` reports update information from the package
manager's current local state. It does not refresh caches and does not install
updates.

Supported package managers:

- apt / apt-get
- dnf
- yum
- zypper
- pacman, when `checkupdates` is available

For Debian and Ubuntu systems, the script uses:

```bash
apt list --upgradable
apt-get -s upgrade
```

The output depends on the freshness of the local apt cache. Run the distribution's
normal update-cache procedure separately when you intentionally want fresh data.

`sasd-reboot-required-report.sh` checks common distro indicators such as
`/run/reboot-required` and optionally reports `needrestart` output when the tool is
installed.
