#!/usr/bin/env python3
"""Safely stage owner-provided REFramework JSON ZIPs in a git checkout.

The importer preserves JSON bytes, verifies SHA-256, writes a manifest,
and never commits or pushes. Requires Python 3.9+, standard library only.

Example:
  python tools/research/import_capture.py 'EQ Prove v1.1.zip' \
    --target research/dumps/items/2026-10-11/detailed-v5.2/current/v1.1/raw \
    --keep-zip
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
from zipfile import ZipFile, BadZipFile

MAX_FILE = 20_000_000
MAX_TOTAL = 150_000_000


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_name(name: str) -> str:
    # Flatten optional ZIP parent directory, but reject unsafe paths/names.
    if "\\" in name or name.startswith("/") or any(
        part in ("..", "") for part in name.split("/")
    ):
        raise ValueError(f"unsafe ZIP member: {name!r}")
    basename = Path(name).name
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*\.json", basename):
        raise ValueError(f"unsafe or non-JSON filename: {name!r}")
    return basename


def stage(archive: Path, target: Path, *, dry_run=False, keep_zip=False):
    if not archive.is_file():
        raise ValueError(f"archive not found: {archive}")
    target = target.resolve()
    archive_bytes = archive.read_bytes()
    if not archive_bytes or len(archive_bytes) > MAX_TOTAL:
        raise ValueError("ZIP empty or over size limit")
    archive_hash = sha256(archive_bytes)

    rows = []
    planned = []
    seen = set()
    total = 0
    with ZipFile(archive) as zipped:
        for info in zipped.infolist():
            if info.is_dir() or info.filename.startswith("__MACOSX/"):
                continue
            basename = safe_name(info.filename)
            if basename in seen:
                raise ValueError(f"duplicate JSON basename: {basename}")
            seen.add(basename)
            if info.file_size > MAX_FILE:
                raise ValueError(f"JSON too large: {basename}")
            total += info.file_size
            if total > MAX_TOTAL:
                raise ValueError("uncompressed data too large")
            payload = zipped.read(info)
            obj = json.loads(payload)
            if not isinstance(obj, dict):
                raise ValueError(f"expected JSON object: {basename}")
            environment = obj.get("environment")
            if not isinstance(environment, dict):
                environment = {}
            dest = target / basename
            digest = sha256(payload)
            rows.append({
                "file": basename,
                "sourceZipEntry": info.filename,
                "sha256": digest,
                "sizeBytes": len(payload),
                "kind": obj.get("kind"),
                "tdbVersion": environment.get("tdbVersion"),
            })
            planned.append((dest, payload))
    if not rows:
        raise ValueError("no JSON entries")
    manifest_data = {
        "schema": "dd2-capture-import-manifest/v1",
        "sourceArchive": archive.name,
        "sourceArchiveSha256": archive_hash,
        "sourceArchiveBytes": len(archive_bytes),
        "captureFiles": sorted(rows, key=lambda row: row["file"]),
        "note": "Original bytes preserved. Import does not validate gameplay behavior.",
    }
    manifest_path = target / f"IMPORT_{archive_hash[:12]}.json"
    planned.append((
        manifest_path,
        (json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n").encode(),
    ))
    if keep_zip:
        clean_name = re.sub(r"[^A-Za-z0-9._-]", "_", archive.name)
        planned.append((
            target / "originals" / f"{archive_hash[:12]}_{clean_name}",
            archive_bytes,
        ))

    # Precheck the whole transaction: never partially write a conflicting archive.
    for path, data in planned:
        if path.exists() and sha256(path.read_bytes()) != sha256(data):
            raise ValueError(f"existing file differs; refusing overwrite: {path}")

    if not dry_run:
        for path, data in planned:
            if not path.exists():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)

    print(f'{"DRY RUN" if dry_run else "STAGED"}: {len(rows)} JSON files')
    print(f"Source SHA-256: {archive_hash}")
    for row in sorted(rows, key=lambda item: item["file"]):
        print(f'  {row["file"]}: {row["sizeBytes"]:,} bytes, {row["kind"]}')
    print(f"Manifest: {manifest_path}")
    print("No commit or push performed. Review files before the PR.")
    return manifest_data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-zip", action="store_true")
    args = parser.parse_args()
    try:
        stage(args.archive, args.target,
              dry_run=args.dry_run, keep_zip=args.keep_zip)
    except (BadZipFile, ValueError, OSError) as exc:
        parser.exit(2, f"ERROR: {exc}\n")


if __name__ == "__main__":
    main()
