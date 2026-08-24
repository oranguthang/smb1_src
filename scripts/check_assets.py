#!/usr/bin/env python3
"""Validate ignored local assets without modifying them."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path, PurePosixPath


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    raise SystemExit(1)


def asset_path(root: Path, relative: str) -> Path:
    posix = PurePosixPath(relative)
    if posix.is_absolute() or not posix.parts or ".." in posix.parts:
        fail(f"unsafe asset path in manifest: {relative!r}")
    destination = root.joinpath(*posix.parts)
    try:
        destination.resolve().relative_to(root.resolve())
    except ValueError:
        fail(f"asset path escapes asset directory: {relative!r}")
    return destination


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, help="asset manifest")
    parser.add_argument("--asset-dir", required=True, help="local asset root")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    asset_dir = Path(args.asset_dir)
    if not manifest_path.is_file():
        fail(f"manifest not found: {manifest_path}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read manifest: {exc}")
    if manifest.get("schema_version") != 1:
        fail("unsupported asset manifest schema")
    assets = manifest.get("assets")
    if not isinstance(assets, list) or not assets:
        fail("manifest has no assets")

    failures: list[str] = []
    for entry in assets:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            fail("asset entries must contain a string path")
        relative = entry["path"]
        path = asset_path(asset_dir, relative)
        if not path.is_file():
            failures.append(f"missing: {relative}")
            continue
        payload = path.read_bytes()
        expected_size = int(entry["size"])
        expected_hash = str(entry["sha1"]).lower()
        actual_hash = hashlib.sha1(payload).hexdigest()
        if len(payload) != expected_size:
            failures.append(
                f"wrong size: {relative} ({len(payload)}, expected {expected_size})"
            )
        elif actual_hash != expected_hash:
            failures.append(
                f"wrong SHA1: {relative} ({actual_hash}, expected {expected_hash})"
            )

    if failures:
        print("[ERROR] Local generated assets are invalid:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        print("[ERROR] Run make split to restore them.", file=sys.stderr)
        return 1
    print(f"[OK] Validated {len(assets)} local asset files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
