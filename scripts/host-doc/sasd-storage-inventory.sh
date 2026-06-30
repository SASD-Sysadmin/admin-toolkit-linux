#!/usr/bin/env bash
# scripts/host-doc/sasd-storage-inventory.sh
# Purpose: Read-only Linux storage and filesystem inventory for host documentation.
# Date: 2026-06-30

set -u

MAX_LINES=140
SHOW_FSTAB=1
SHOW_BLKID=0

usage() {
  cat <<'USAGE'
Usage: sasd-storage-inventory.sh [options]

Create a read-only storage and filesystem inventory report for the local host.

Options:
  --max-lines N       Limit long command sections to N lines (default: 140)
  --show-blkid        Include blkid output when visible (may require root)
  --no-fstab          Do not print sanitized /etc/fstab lines
  -h, --help          Show this help

Notes:
  - This script does not mount, unmount, format, repair or change filesystems.
  - It can run as a normal user; some device details may be incomplete.
  - /etc/fstab output is sanitized for common credential options.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --max-lines)
      [ "$#" -ge 2 ] || { echo "ERROR: --max-lines requires a value" >&2; exit 2; }
      MAX_LINES="$2"
      shift 2
      ;;
    --show-blkid)
      SHOW_BLKID=1
      shift
      ;;
    --no-fstab)
      SHOW_FSTAB=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
 done

case "$MAX_LINES" in
  ''|*[!0-9]*) echo "ERROR: --max-lines must be a positive integer" >&2; exit 2 ;;
  0) echo "ERROR: --max-lines must be greater than zero" >&2; exit 2 ;;
esac

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_limited() {
  local title="$1"
  shift
  echo "### $title"
  echo
  echo '```text'
  "$@" 2>&1 | sed -n "1,${MAX_LINES}p"
  echo '```'
  echo
}

sanitize_fstab() {
  # Redact common secret-bearing mount options while preserving operational context.
  sed -E \
    -e 's/(password|passwd|pass|credentials|cred|username|user|domain)=([^,[:space:]]+)/\1=<redacted>/Ig' \
    -e 's/(secret|token|key)=([^,[:space:]]+)/\1=<redacted>/Ig' \
    /etc/fstab 2>/dev/null | sed -n "1,${MAX_LINES}p"
}

HOSTNAME_SHORT="$(hostname 2>/dev/null || printf 'unknown')"
GENERATED="$(date -Is 2>/dev/null || date)"
USER_NAME="$(id -un 2>/dev/null || printf 'unknown')"
EUID_VALUE="$(id -u 2>/dev/null || printf 'unknown')"
PRIVILEGE="non-root"
if [ "$EUID_VALUE" = "0" ]; then
  PRIVILEGE="root"
fi

cat <<EOF_HEADER
# SASD Storage Inventory

- Generated: ${GENERATED}
- Host: ${HOSTNAME_SHORT}
- User: ${USER_NAME}
- Effective UID: ${EUID_VALUE}
- Privilege: ${PRIVILEGE}
- Max lines per section: ${MAX_LINES}

> Read-only report. This script does not mount, unmount, format, repair,
> resize, wipe, encrypt, decrypt or change filesystems. Storage paths, mount
> points, volume names and fstab entries can be sensitive; review before sharing.

EOF_HEADER

cat <<'EOF_SCOPE'
## Completeness note

Normal users can usually see mounted filesystems and basic block-device topology.
Some device metadata, encrypted volume details, RAID details or protected paths
may require root or host-specific tools. Missing details are therefore not
always errors.

EOF_SCOPE

cat <<'EOF_TOOLS'
## Tool detection

| Tool | State | Path |
| --- | --- | --- |
EOF_TOOLS
for tool in findmnt lsblk df swapon blkid pvs vgs lvs mdadm zpool btrfs systemctl awk sed; do
  if has_cmd "$tool"; then
    printf '| `%s` | `OK` | `%s` |\n' "$tool" "$(command -v "$tool")"
  else
    printf '| `%s` | `MISS` | `not found` |\n' "$tool"
  fi
done

echo

echo "## Mounted filesystems"
echo
if has_cmd findmnt; then
  run_limited "findmnt overview" findmnt -R -o TARGET,SOURCE,FSTYPE,OPTIONS
else
  echo 'INFO: findmnt not found.'
  echo
fi

if has_cmd df; then
  run_limited "df -hT" df -hT
  run_limited "df -ihT" df -ihT
else
  echo 'INFO: df not found.'
  echo
fi

echo "## Block device topology"
echo
if has_cmd lsblk; then
  run_limited "lsblk filesystem view" lsblk -e 7 -o NAME,TYPE,SIZE,FSTYPE,FSVER,LABEL,UUID,FSAVAIL,FSUSE%,MOUNTPOINTS
  run_limited "lsblk hardware view" lsblk -e 7 -o NAME,TYPE,SIZE,RO,RM,ROTA,TRAN,MODEL,MOUNTPOINTS
else
  echo 'INFO: lsblk not found.'
  echo
fi

if [ "$SHOW_BLKID" -eq 1 ]; then
  echo "## blkid output"
  echo
  if has_cmd blkid; then
    run_limited "blkid" blkid
  else
    echo 'INFO: blkid not found.'
    echo
  fi
else
  cat <<'EOF_BLKID'
## blkid output

INFO: blkid output is not shown by default. Use `--show-blkid` if UUID/device
metadata is appropriate for the report audience.

EOF_BLKID
fi

echo "## Swap"
echo
if has_cmd swapon; then
  run_limited "swapon --show" swapon --show
else
  echo 'INFO: swapon not found.'
  echo
fi

if [ "$SHOW_FSTAB" -eq 1 ]; then
  echo "## /etc/fstab sanitized view"
  echo
  if [ -r /etc/fstab ]; then
    echo '```text'
    sanitize_fstab
    echo '```'
  else
    echo 'INFO: /etc/fstab is not readable.'
  fi
  echo
fi

echo "## LVM hints"
echo
if has_cmd pvs || has_cmd vgs || has_cmd lvs; then
  has_cmd pvs && run_limited "pvs" pvs --noheadings --separator ' | ' -o pv_name,vg_name,pv_size,pv_free
  has_cmd vgs && run_limited "vgs" vgs --noheadings --separator ' | ' -o vg_name,vg_size,vg_free,lv_count,pv_count
  has_cmd lvs && run_limited "lvs" lvs --noheadings --separator ' | ' -o lv_name,vg_name,lv_size,lv_attr,origin,pool_lv,data_percent,metadata_percent
else
  echo 'INFO: LVM tools not found.'
  echo
fi

echo "## Software RAID hints"
echo
if [ -r /proc/mdstat ]; then
  echo '### /proc/mdstat'
  echo
  echo '```text'
  sed -n "1,${MAX_LINES}p" /proc/mdstat
  echo '```'
  echo
else
  echo 'INFO: /proc/mdstat is not readable.'
  echo
fi
if has_cmd mdadm; then
  run_limited "mdadm --detail --scan" mdadm --detail --scan
else
  echo 'INFO: mdadm not found.'
  echo
fi

echo "## ZFS hints"
echo
if has_cmd zpool; then
  run_limited "zpool list" zpool list
  run_limited "zpool status" zpool status
else
  echo 'INFO: zpool not found.'
  echo
fi

echo "## Btrfs hints"
echo
if has_cmd btrfs; then
  run_limited "btrfs filesystem show" btrfs filesystem show
else
  echo 'INFO: btrfs command not found.'
  echo
fi

echo "## Mount units"
echo
if has_cmd systemctl; then
  run_limited "systemctl list-units --type=mount" systemctl list-units --type=mount --all --no-pager
  run_limited "systemctl list-units --type=automount" systemctl list-units --type=automount --all --no-pager
else
  echo 'INFO: systemctl not found.'
  echo
fi

cat <<'EOF_FOOTER'
## Review hints

- Compare mounted filesystems with the expected host role.
- Check whether important data paths are on the expected filesystem or mount.
- Review `df -hT` and `df -ihT` together; inode exhaustion is different from
  byte exhaustion.
- fstab entries may reveal network shares or credentials; this report redacts
  common credential options but still needs human review before sharing.
- This report is inventory, not a backup, SMART, RAID-health or filesystem-repair
  tool.
EOF_FOOTER

exit 0
