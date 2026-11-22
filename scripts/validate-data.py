#!/usr/bin/env python3
"""Validate FReD/FLoRA static datasets and detect canonical content changes.

Usage:
  validate-data.py validate <dir> [--only explorer|flora|retraction] [--baseline <dir>]
  validate-data.py diff <baseline_dir> <candidate_dir>
"""

import argparse
import csv
import gzip
import hashlib
import io
import json
import os
import sys
from pathlib import Path

EXPLORER_FILE = "explorer-data.json"
FLORA_FILE = "flora-data.json"
RETRACTION_FILE = "retraction-watch.csv.gz"
MAX_DROP_RATIO = 0.30  # Flag implausible >30% record count drop vs baseline


def fail(msg: str) -> None:
    print(f"VALIDATION ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def load_json(path: Path) -> dict:
    if not path.is_file():
        fail(f"Missing required file: {path}")
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception as exc:
        fail(f"Invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"Expected top-level JSON object in {path}")
    return data


def validate_explorer(data_dir: Path, baseline_dir: Path | None = None) -> int:
    path = data_dir / EXPLORER_FILE
    data = load_json(path)
    studies = data.get("studies")
    if not isinstance(studies, list) or len(studies) < 100:
        fail(f"{EXPLORER_FILE}: expected nonempty studies array (>=100), got {type(studies).__name__} len={len(studies) if isinstance(studies, list) else 'n/a'}")
    sample = studies[0]
    for key in ("ref_o", "outcomes", "description"):
        if key not in sample:
            fail(f"{EXPLORER_FILE}: first study missing required key '{key}'")
    if baseline_dir and (baseline_dir / EXPLORER_FILE).is_file():
        base_n = len(load_json(baseline_dir / EXPLORER_FILE).get("studies", []))
        if base_n > 0 and len(studies) < base_n * (1 - MAX_DROP_RATIO):
            fail(f"{EXPLORER_FILE}: implausible study count drop ({len(studies)} vs baseline {base_n})")
    print(f"OK {EXPLORER_FILE}: {len(studies)} studies")
    return len(studies)


def validate_flora(data_dir: Path, baseline_dir: Path | None = None) -> int:
    path = data_dir / FLORA_FILE
    data = load_json(path)
    entries = data.get("entries")
    if not isinstance(entries, list) or len(entries) < 100:
        fail(f"{FLORA_FILE}: expected nonempty entries array (>=100), got {type(entries).__name__} len={len(entries) if isinstance(entries, list) else 'n/a'}")
    sample = entries[0]
    for key in ("doi_original", "replications"):
        if key not in sample:
            fail(f"{FLORA_FILE}: first entry missing required key '{key}'")
    if baseline_dir and (baseline_dir / FLORA_FILE).is_file():
        base_n = len(load_json(baseline_dir / FLORA_FILE).get("entries", []))
        if base_n > 0 and len(entries) < base_n * (1 - MAX_DROP_RATIO):
            fail(f"{FLORA_FILE}: implausible entry count drop ({len(entries)} vs baseline {base_n})")
    print(f"OK {FLORA_FILE}: {len(entries)} entries")
    return len(entries)


def count_retraction_dois(path: Path) -> int:
    if not path.is_file():
        fail(f"Missing required file: {path}")
    try:
        with gzip.open(path, "rt", encoding="utf-8", errors="replace", newline="") as fh:
            reader = csv.reader(fh)
            header = next(reader, None)
            if not header:
                fail(f"{RETRACTION_FILE}: empty CSV")
            lower = [h.strip().lower() for h in header]
            doi_idx = next((i for i, h in enumerate(lower) if "originalpaperdoi" in h), -1)
            if doi_idx == -1:
                fail(f"{RETRACTION_FILE}: missing OriginalPaperDOI column (found: {header[:8]})")
            for required in ("title", "retractiondate", "reason", "retractionnature"):
                if required not in lower:
                    fail(f"{RETRACTION_FILE}: missing required column '{required}'")
            doi_count = 0
            for row in reader:
                if doi_idx < len(row) and "10." in row[doi_idx]:
                    doi_count += 1
    except SystemExit:
        raise
    except Exception as exc:
        fail(f"{RETRACTION_FILE}: failed to decompress/parse gzip CSV: {exc}")
    if doi_count < 1000:
        fail(f"{RETRACTION_FILE}: expected >=1000 DOI rows, found {doi_count}")
    return doi_count


def validate_retraction(data_dir: Path, baseline_dir: Path | None = None) -> int:
    path = data_dir / RETRACTION_FILE
    doi_count = count_retraction_dois(path)
    if baseline_dir and (baseline_dir / RETRACTION_FILE).is_file():
        base_n = count_retraction_dois(baseline_dir / RETRACTION_FILE)
        if base_n > 0 and doi_count < base_n * (1 - MAX_DROP_RATIO):
            fail(f"{RETRACTION_FILE}: implausible DOI count drop ({doi_count} vs baseline {base_n})")
    print(f"OK {RETRACTION_FILE}: {doi_count} DOI records")
    return doi_count


def canonical_json_hash(path: Path) -> str:
    data = load_json(path)
    meta = data.get("metadata")
    if isinstance(meta, dict) and "generated" in meta:
        meta = dict(meta)
        meta.pop("generated", None)
        data = dict(data)
        data["metadata"] = meta
    payload = json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def decompressed_gzip_hash(path: Path) -> str:
    h = hashlib.sha256()
    with gzip.open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def cmd_validate(args: argparse.Namespace) -> None:
    data_dir = Path(args.dir)
    baseline_dir = Path(args.baseline) if args.baseline else None
    targets = [args.only] if args.only else ["explorer", "flora", "retraction"]
    for t in targets:
        if t == "explorer":
            validate_explorer(data_dir, baseline_dir)
        elif t == "flora":
            validate_flora(data_dir, baseline_dir)
        elif t == "retraction":
            validate_retraction(data_dir, baseline_dir)


def cmd_diff(args: argparse.Namespace) -> None:
    base = Path(args.baseline)
    cand = Path(args.candidate)
    changed = []

    for fname in (EXPLORER_FILE, FLORA_FILE):
        bp, cp = base / fname, cand / fname
        if not bp.is_file() or canonical_json_hash(bp) != canonical_json_hash(cp):
            changed.append(fname)

    bp, cp = base / RETRACTION_FILE, cand / RETRACTION_FILE
    if not bp.is_file() or decompressed_gzip_hash(bp) != decompressed_gzip_hash(cp):
        changed.append(RETRACTION_FILE)

    result = {"changed": bool(changed), "files": changed}
    print(json.dumps(result))


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_val = sub.add_parser("validate")
    p_val.add_argument("dir")
    p_val.add_argument("--only", choices=["explorer", "flora", "retraction"], default=None)
    p_val.add_argument("--baseline", default=None)
    p_val.set_defaults(func=cmd_validate)

    p_diff = sub.add_parser("diff")
    p_diff.add_argument("baseline")
    p_diff.add_argument("candidate")
    p_diff.set_defaults(func=cmd_diff)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
