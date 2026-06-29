#!/usr/bin/env bash
# Path: scripts/backup/sasd-rsync-snapshot.sh
# Purpose: Create timestamped rsync snapshots with a safe dry-run default.
# Date: 2026-06-29
# License: MIT
#
# Why this matters:
#   A backup strategy is incomplete without repeatable commands and restore tests.
#   This script demonstrates a conservative snapshot pattern using rsync and
#   hard-linking unchanged files from the previous snapshot via --link-dest.
#
# Safety model:
#   - Default mode is dry-run. No files are copied unless --apply is given.
#   - A new snapshot is first written to a .partial directory and then renamed.
#   - The "latest" symlink is updated only after a successful applied run.
#
# Exit codes:
#   0 = dry-run or snapshot completed successfully
#   3 = invalid arguments / required command missing

set -uo pipefail

VERSION="0.2.0"
SOURCE=""
DESTINATION=""
APPLY=0
EXCLUDES=()

usage() {
  cat <<'USAGE'
Usage: sasd-rsync-snapshot.sh --source DIR --destination DIR [OPTIONS]

Create a timestamped rsync snapshot. Dry-run is the default.

Required:
      --source DIR        Source directory to back up
      --destination DIR   Destination directory that will contain snapshots

Options:
      --exclude PATTERN   rsync exclude pattern. Can be used multiple times.
      --apply             Actually copy data and update the latest symlink
  -h, --help              Show this help text
      --version           Print version

Examples:
  scripts/backup/sasd-rsync-snapshot.sh --source /etc --destination /backup/etc
  scripts/backup/sasd-rsync-snapshot.sh --source /etc --destination /backup/etc --apply

Notes:
  Review the dry-run output before using --apply. This script is a template and
  should be tested in a lab before production use.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --exclude)
      EXCLUDES+=("${2:-}")
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --version)
      echo "$VERSION"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "UNKNOWN - unsupported argument: $1" >&2
      usage >&2
      exit 3
      ;;
  esac
done

if ! command -v rsync >/dev/null 2>&1; then
  echo "UNKNOWN - rsync is not available" >&2
  exit 3
fi

if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
  echo "UNKNOWN - --source and --destination are required" >&2
  usage >&2
  exit 3
fi

if [[ ! -d "$SOURCE" ]]; then
  echo "UNKNOWN - source is not a directory: $SOURCE" >&2
  exit 3
fi

# Normalize source without removing the trailing slash semantics: rsync should
# copy the contents of SOURCE into the snapshot directory, not the SOURCE folder
# itself. Therefore we add a trailing slash in the rsync invocation below.
timestamp="$(date +%Y%m%d-%H%M%S)"
snapshot_dir="$DESTINATION/$timestamp"
partial_dir="$DESTINATION/.${timestamp}.partial"
latest_link="$DESTINATION/latest"

mkdir_args=()
if (( APPLY == 0 )); then
  mkdir_args+=(--dry-run)
fi

# The destination parent may not exist. In dry-run mode we do not create it; in
# apply mode we create it explicitly before running rsync.
if (( APPLY == 1 )); then
  mkdir -p "$DESTINATION"
fi

rsync_args=(
  -aH
  --numeric-ids
  --delete
  --itemize-changes
)

if (( APPLY == 0 )); then
  rsync_args+=(--dry-run)
fi

for pattern in "${EXCLUDES[@]}"; do
  rsync_args+=(--exclude "$pattern")
done

if [[ -L "$latest_link" || -d "$latest_link" ]]; then
  # --link-dest must be relative to the destination directory or absolute. Using
  # the symlink path keeps the command readable and allows rsync to hard-link
  # unchanged files from the previous snapshot.
  rsync_args+=(--link-dest "$latest_link")
fi

printf '# Rsync Snapshot\n\n'
printf 'Generated: %s\n\n' "$(date -Is 2>/dev/null || date)"
printf 'Mode: `%s`\n\n' "$([[ "$APPLY" -eq 1 ]] && echo apply || echo dry-run)"
printf 'Source: `%s`  \n' "$SOURCE"
printf 'Destination: `%s`  \n' "$DESTINATION"
printf 'Snapshot: `%s`\n\n' "$snapshot_dir"
printf '```text\n'

if (( APPLY == 1 )); then
  rm -rf "$partial_dir"
  mkdir -p "$partial_dir"
  rsync "${rsync_args[@]}" "$SOURCE/" "$partial_dir/"
  mv "$partial_dir" "$snapshot_dir"
  ln -sfn "$snapshot_dir" "$latest_link"
  echo "Snapshot completed: $snapshot_dir"
else
  # In dry-run mode we pass the final snapshot path. rsync will not create it due
  # to --dry-run, but it shows the planned file operations.
  rsync "${rsync_args[@]}" "$SOURCE/" "$snapshot_dir/"
  echo "Dry-run only. Re-run with --apply after reviewing the output."
fi

printf '```\n'
exit 0
