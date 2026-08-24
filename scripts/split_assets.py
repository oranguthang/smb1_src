#!/usr/bin/env python3
"""Validate the reference SMB1 ROM and extract ignored build assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path, PurePosixPath
from typing import Any


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_number(value: Any, field: str) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        try:
            return int(value, 0)
        except ValueError:
            pass
    fail(f"invalid integer for {field}: {value!r}")
    raise AssertionError


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def parse_ines(data: bytes) -> tuple[bytes, bytes, bytes, dict[str, Any]]:
    if len(data) < 16 or data[:4] != b"NES\x1a":
        fail("reference ROM is not a valid iNES image")
    trainer_size = 512 if data[6] & 0x04 else 0
    prg_size = data[4] * 16_384
    chr_size = data[5] * 8_192
    prg_start = 16 + trainer_size
    chr_start = prg_start + prg_size
    expected_size = chr_start + chr_size
    if len(data) != expected_size:
        fail(
            f"reference ROM size is {len(data)}, expected exactly "
            f"{expected_size}; trailing data is not accepted"
        )
    properties = {
        "trainer_size": trainer_size,
        "prg_size": prg_size,
        "chr_size": chr_size,
        "mapper": (data[6] >> 4) | (data[7] & 0xF0),
        "mirroring": "vertical" if data[6] & 0x01 else "horizontal",
    }
    return (
        data[:prg_start],
        data[prg_start:chr_start],
        data[chr_start:],
        properties,
    )


def safe_output_path(root: Path, relative: str) -> Path:
    posix = PurePosixPath(relative)
    if posix.is_absolute() or not posix.parts or ".." in posix.parts:
        fail(f"unsafe asset path in manifest: {relative!r}")
    destination = root.joinpath(*posix.parts)
    try:
        destination.resolve().relative_to(root.resolve())
    except ValueError:
        fail(f"asset path escapes output directory: {relative!r}")
    return destination


def write_if_changed(path: Path, payload: bytes) -> str:
    if path.is_file() and path.read_bytes() == payload:
        return "OK"
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(payload)
    os.replace(temporary, path)
    return "WRITE"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", required=True, help="original iNES ROM")
    parser.add_argument("--manifest", required=True, help="asset manifest")
    parser.add_argument("--output-dir", required=True, help="generated assets")
    args = parser.parse_args()

    rom_path = Path(args.rom)
    manifest_path = Path(args.manifest)
    output_dir = Path(args.output_dir)
    if not rom_path.is_file():
        fail(f"ROM not found: {rom_path}")
    if not manifest_path.is_file():
        fail(f"manifest not found: {manifest_path}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read manifest: {exc}")
    if manifest.get("schema_version") != 1:
        fail("unsupported asset manifest schema")

    reference = manifest.get("reference_rom", {})
    rom = rom_path.read_bytes()
    actual_rom_hash = sha1(rom)
    expected_rom_hash = str(reference.get("sha1", "")).lower()
    if actual_rom_hash != expected_rom_hash:
        fail(
            f"wrong reference ROM: SHA1 {actual_rom_hash}, "
            f"expected {expected_rom_hash}"
        )

    header, prg, chr_data, properties = parse_ines(rom)
    for field in ("trainer_size", "prg_size", "chr_size", "mapper"):
        expected = parse_number(reference.get(field), field)
        if properties[field] != expected:
            fail(
                f"reference {field} is {properties[field]}, expected {expected}"
            )
    expected_mirroring = str(reference.get("mirroring", ""))
    if properties["mirroring"] != expected_mirroring:
        fail(
            f"reference mirroring is {properties['mirroring']}, "
            f"expected {expected_mirroring}"
        )
    if sha1(prg) != str(reference.get("prg_sha1", "")).lower():
        fail("reference PRG checksum does not match the manifest")
    if sha1(chr_data) != str(reference.get("chr_sha1", "")).lower():
        fail("reference CHR checksum does not match the manifest")

    regions = {"header": header, "chr": chr_data}
    assets = manifest.get("assets")
    if not isinstance(assets, list) or not assets:
        fail("manifest has no assets")
    written = 0
    seen_paths: set[str] = set()
    for entry in assets:
        if not isinstance(entry, dict):
            fail("asset entries must be objects")
        relative = str(entry.get("path", ""))
        if relative in seen_paths:
            fail(f"duplicate asset path: {relative}")
        seen_paths.add(relative)
        region = str(entry.get("region", ""))
        if region not in regions:
            fail(f"unsupported extracted region for {relative}: {region!r}")
        source = regions[region]
        offset = parse_number(entry.get("offset", 0), f"{relative}.offset")
        size = parse_number(entry.get("size"), f"{relative}.size")
        if offset < 0 or size <= 0 or offset + size > len(source):
            fail(f"asset range is outside {region}: {relative}")
        payload = source[offset : offset + size]
        digest = sha1(payload)
        expected_digest = str(entry.get("sha1", "")).lower()
        if digest != expected_digest:
            fail(
                f"asset checksum mismatch for {relative}: "
                f"{digest}, expected {expected_digest}"
            )
        destination = safe_output_path(output_dir, relative)
        action = write_if_changed(destination, payload)
        written += action == "WRITE"
        print(f"[{action}] {relative} ({size} bytes, sha1={digest[:12]})")

    print(
        f"[OK] Reference ROM validated; {len(assets)} assets checked, "
        f"{written} written."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
