#!/usr/bin/env python3
"""
Path: scripts/security/sasd-fim-report.py
Purpose: Summarize SASD file integrity baselines and check reports.
Date: 2026-06-30
License: MIT

This script is read-only. It parses a baseline created by
sasd-fim-baseline.sh and, optionally, a Markdown report created by
sasd-fim-check.sh. It does not hash files itself and does not modify monitored
files.
"""

from __future__ import annotations

import argparse
import collections
import datetime as _dt
import getpass
import os
import re
import socket
import sys
from pathlib import Path
from typing import Iterable, NamedTuple

VERSION = "0.1.0"


class BaselineEntry(NamedTuple):
    sha256: str
    mode: str
    owner: str
    group: str
    size: str
    mtime_epoch: str
    path: str


class CheckFinding(NamedTuple):
    status: str
    path: str
    details: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="sasd-fim-report.py",
        description="Summarize SASD FIM baselines and check reports without changing files.",
    )
    parser.add_argument("--baseline", help="Baseline TSV created by sasd-fim-baseline.sh")
    parser.add_argument("--check-report", help="Markdown report created by sasd-fim-check.sh")
    parser.add_argument("--max-rows", type=int, default=80, help="Maximum rows to show in detail tables")
    parser.add_argument("--format", choices=("markdown", "text", "tsv"), default="markdown")
    parser.add_argument("--title", default="SASD File Integrity Report")
    parser.add_argument("--version", action="version", version=VERSION)
    return parser.parse_args()


def die(message: str, code: int = 3) -> None:
    print(f"UNKNOWN - {message}", file=sys.stderr)
    raise SystemExit(code)


def read_baseline(path: str | None) -> tuple[list[BaselineEntry], list[str]]:
    if not path:
        return [], []

    baseline_path = Path(path)
    if not baseline_path.is_file():
        die(f"baseline is not a readable file: {path}")

    entries: list[BaselineEntry] = []
    warnings: list[str] = []

    with baseline_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line_number, raw_line in enumerate(handle, 1):
            line = raw_line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t", 6)
            if len(parts) != 7:
                warnings.append(f"line {line_number}: expected 7 TSV fields, got {len(parts)}")
                continue
            entries.append(BaselineEntry(*parts))

    return entries, warnings


def clean_cell(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def parse_markdown_table_row(line: str) -> list[str] | None:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return None
    cells = [clean_cell(cell) for cell in stripped.strip("|").split("|")]
    if not cells or all(not cell for cell in cells):
        return None
    if len(cells) >= 3 and cells[0].lower() in {"status", "---", ":---"}:
        return None
    if set(cells[0]) <= {"-", ":"}:
        return None
    return cells


def read_check_report(path: str | None) -> tuple[list[CheckFinding], list[str]]:
    if not path:
        return [], []

    report_path = Path(path)
    if not report_path.is_file():
        die(f"check report is not a readable file: {path}")

    findings: list[CheckFinding] = []
    warnings: list[str] = []

    with report_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line_number, line in enumerate(handle, 1):
            cells = parse_markdown_table_row(line)
            if cells is None:
                continue
            if len(cells) < 3:
                warnings.append(f"line {line_number}: skipped short Markdown table row")
                continue
            status = cells[0].upper().replace(" ", "_")
            path_cell = cells[1]
            details = cells[2]
            if status in {"OK", "CHANGED", "MISSING", "UNREADABLE", "INVALID_BASELINE_ROW", "UNKNOWN"}:
                findings.append(CheckFinding(status, path_cell, details))

    return findings, warnings


def escape_md(value: object) -> str:
    text = str(value)
    text = text.replace("\\", "\\\\")
    text = text.replace("|", "\\|")
    text = text.replace("`", "\\`")
    return text


def short_path(path: str, max_len: int = 140) -> str:
    if len(path) <= max_len:
        return path
    return "..." + path[-(max_len - 3):]


def count_top(values: Iterable[str], limit: int = 10) -> list[tuple[str, int]]:
    return collections.Counter(values).most_common(limit)


def mtime_to_iso(epoch: str) -> str:
    if not epoch or not re.fullmatch(r"\d+", epoch):
        return ""
    try:
        return _dt.datetime.fromtimestamp(int(epoch), tz=_dt.timezone.utc).isoformat()
    except (ValueError, OSError, OverflowError):
        return ""


def status_counts(findings: list[CheckFinding]) -> collections.Counter[str]:
    return collections.Counter(finding.status for finding in findings)


def finding_severity(status: str) -> int:
    order = {
        "CHANGED": 10,
        "MISSING": 10,
        "UNREADABLE": 9,
        "INVALID_BASELINE_ROW": 8,
        "UNKNOWN": 7,
        "OK": 0,
    }
    return order.get(status, 5)


def render_markdown(args: argparse.Namespace, entries: list[BaselineEntry], baseline_warnings: list[str], findings: list[CheckFinding], check_warnings: list[str]) -> int:
    now = _dt.datetime.now().astimezone().isoformat(timespec="seconds")
    host = socket.gethostname()
    user = getpass.getuser()
    euid = os.geteuid() if hasattr(os, "geteuid") else "unknown"
    privilege = "root" if euid == 0 else "non-root"

    counts = status_counts(findings)
    changed_like = sum(counts.get(status, 0) for status in ("CHANGED", "MISSING", "UNREADABLE", "INVALID_BASELINE_ROW"))
    has_unknown = counts.get("UNKNOWN", 0) > 0 or bool(baseline_warnings or check_warnings)

    print(f"# {args.title}")
    print()
    print(f"- Generated: {now}")
    print(f"- Host: {host}")
    print(f"- User: {user}")
    print(f"- Effective UID: {euid}")
    print(f"- Privilege: {privilege}")
    print(f"- Baseline: `{args.baseline or 'not provided'}`")
    print(f"- Check report: `{args.check_report or 'not provided'}`")
    print(f"- Max detail rows: {args.max_rows}")
    print()
    print("> Read-only summary. This report parses baseline/check output; it does not hash, repair, delete or modify monitored files.")
    print()

    print("## Summary")
    print()
    print("| Metric | Value |")
    print("| --- | ---: |")
    print(f"| Baseline entries | {len(entries)} |")
    if findings:
        print(f"| Check rows parsed | {len(findings)} |")
        for status in sorted(counts):
            print(f"| {escape_md(status)} rows | {counts[status]} |")
    else:
        print("| Check rows parsed | 0 |")
    print(f"| Parse warnings | {len(baseline_warnings) + len(check_warnings)} |")
    print()

    if findings:
        if changed_like:
            result = "FINDINGS: changed, missing, unreadable or invalid baseline entries were reported."
        elif has_unknown:
            result = "UNKNOWN: check output contained unknown rows or parse warnings."
        else:
            result = "OK: parsed check output does not show changed baseline entries."
    elif entries:
        result = "INFO: baseline summary only; no check report was provided."
    else:
        result = "UNKNOWN: no baseline entries and no check findings were parsed."
    print(f"Result: **{escape_md(result)}**")
    print()

    if entries:
        print("## Baseline overview")
        print()
        print("| Metric | Value |")
        print("| --- | ---: |")
        print(f"| Files in baseline | {len(entries)} |")
        print(f"| Distinct owners | {len(set(entry.owner for entry in entries))} |")
        print(f"| Distinct groups | {len(set(entry.group for entry in entries))} |")
        print(f"| Distinct modes | {len(set(entry.mode for entry in entries))} |")
        print()

        print("### Top owners")
        print()
        print("| Owner | Count |")
        print("| --- | ---: |")
        for owner, count in count_top(entry.owner for entry in entries):
            print(f"| `{escape_md(owner)}` | {count} |")
        print()

        print("### Baseline sample")
        print()
        print("| Mode | Owner | Group | Size bytes | Modified UTC | Path |")
        print("| ---: | --- | --- | ---: | --- | --- |")
        for entry in entries[: args.max_rows]:
            print(
                f"| `{escape_md(entry.mode)}` | `{escape_md(entry.owner)}` | `{escape_md(entry.group)}` | "
                f"{escape_md(entry.size)} | `{escape_md(mtime_to_iso(entry.mtime_epoch))}` | `{escape_md(short_path(entry.path))}` |"
            )
        if len(entries) > args.max_rows:
            print(f"\nINFO: baseline sample limited to {args.max_rows} of {len(entries)} entries.")
        print()

    if findings:
        print("## Check findings")
        print()
        print("| Status | Path | Details |")
        print("| --- | --- | --- |")
        ordered = sorted(findings, key=lambda f: (-finding_severity(f.status), f.path))
        for finding in ordered[: args.max_rows]:
            print(f"| `{escape_md(finding.status)}` | `{escape_md(short_path(finding.path))}` | {escape_md(finding.details)} |")
        if len(findings) > args.max_rows:
            print(f"\nINFO: check findings limited to {args.max_rows} of {len(findings)} rows.")
        print()

    all_warnings = baseline_warnings + check_warnings
    if all_warnings:
        print("## Parse warnings")
        print()
        print("```text")
        for warning in all_warnings[: args.max_rows]:
            print(warning)
        print("```")
        print()

    print("## Review hints")
    print()
    print("- Treat a new baseline as a reference point, not proof that the current state is safe.")
    print("- Review changed, missing and unreadable entries before deciding whether a change is expected.")
    print("- Store real baselines securely; they can reveal paths, ownership, modes, sizes and hashes.")
    print("- This tool is not an EDR, SIEM or tamper-proof FIM platform.")

    if changed_like:
        return 1
    if has_unknown or not entries and not findings:
        return 3
    return 0


def render_text(args: argparse.Namespace, entries: list[BaselineEntry], baseline_warnings: list[str], findings: list[CheckFinding], check_warnings: list[str]) -> int:
    counts = status_counts(findings)
    print(args.title)
    print(f"Baseline entries: {len(entries)}")
    print(f"Check rows parsed: {len(findings)}")
    for status in sorted(counts):
        print(f"{status}: {counts[status]}")
    warnings = len(baseline_warnings) + len(check_warnings)
    print(f"Parse warnings: {warnings}")
    changed_like = sum(counts.get(status, 0) for status in ("CHANGED", "MISSING", "UNREADABLE", "INVALID_BASELINE_ROW"))
    if changed_like:
        return 1
    if warnings or counts.get("UNKNOWN", 0) or not entries and not findings:
        return 3
    return 0


def render_tsv(entries: list[BaselineEntry], findings: list[CheckFinding]) -> int:
    print("type\tstatus\tpath\tdetails")
    for finding in findings:
        print(f"check\t{finding.status}\t{finding.path}\t{finding.details}")
    if not findings:
        for entry in entries:
            print(f"baseline\tENTRY\t{entry.path}\tmode={entry.mode};owner={entry.owner};group={entry.group};size={entry.size}")
    counts = status_counts(findings)
    if sum(counts.get(status, 0) for status in ("CHANGED", "MISSING", "UNREADABLE", "INVALID_BASELINE_ROW")):
        return 1
    return 0


def main() -> int:
    args = parse_args()
    if args.max_rows < 1:
        die("--max-rows must be greater than zero")
    if not args.baseline and not args.check_report:
        die("provide --baseline and/or --check-report")

    entries, baseline_warnings = read_baseline(args.baseline)
    findings, check_warnings = read_check_report(args.check_report)

    if args.format == "markdown":
        return render_markdown(args, entries, baseline_warnings, findings, check_warnings)
    if args.format == "text":
        return render_text(args, entries, baseline_warnings, findings, check_warnings)
    return render_tsv(entries, findings)


if __name__ == "__main__":
    raise SystemExit(main())
