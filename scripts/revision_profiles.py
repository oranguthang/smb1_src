#!/usr/bin/env python3
"""Split private profile assets and build or verify official ROM profiles."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from pathlib import Path
from typing import Any


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def load_profile(path: Path, profile_id: str) -> dict[str, Any]:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1:
        raise ValueError("unsupported revision profile schema")
    matches = [item for item in document["supported"] if item["id"] == profile_id]
    if len(matches) != 1:
        raise ValueError(f"supported revision profile not found: {profile_id}")
    return matches[0]


def split_rom(rom: bytes, profile: dict[str, Any]) -> tuple[bytes, bytes, bytes, bytes]:
    if len(rom) != int(profile["rom_size"]) or sha1(rom) != profile["rom_sha1"]:
        raise ValueError("private reference ROM does not match the selected profile")
    header_end = int(profile["header_size"])
    prg_end = header_end + int(profile["prg_size"])
    chr_end = prg_end + int(profile["chr_size"])
    regions = rom[:header_end], rom[header_end:prg_end], rom[prg_end:chr_end], rom[chr_end:]
    for name, region in zip(("header", "prg", "chr", "extra"), regions):
        expected_size = int(profile[f"{name}_size"])
        expected_hash = profile[f"{name}_sha1"]
        if len(region) != expected_size:
            raise ValueError(f"{name} size mismatch")
        if expected_hash is not None and sha1(region) != expected_hash:
            raise ValueError(f"{name} hash mismatch")
    return regions


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def build_image(
    profile: dict[str, Any],
    header: bytes,
    prg: bytes,
    chr_data: bytes,
    extra: bytes,
) -> bytes:
    regions = {"header": header, "prg": prg, "chr": chr_data, "extra": extra}
    for name, region in regions.items():
        if len(region) != int(profile[f"{name}_size"]):
            raise ValueError(f"{name} size mismatch for {profile['id']}")
        expected_hash = profile[f"{name}_sha1"]
        if expected_hash is not None and sha1(region) != expected_hash:
            raise ValueError(f"{name} hash mismatch for {profile['id']}")
    return header + prg + chr_data + extra


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("split", "build", "verify"))
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--reference-rom", type=Path)
    parser.add_argument("--asset-dir", required=True, type=Path)
    parser.add_argument("--header", type=Path)
    parser.add_argument("--prg", type=Path)
    parser.add_argument("--chr", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        profile = load_profile(args.manifest, args.profile)
        extra_path = args.asset_dir / args.profile / "platform.extra"
        if args.command == "split":
            if args.reference_rom is None:
                raise ValueError("split requires a private reference ROM")
            _, _, _, extra = split_rom(args.reference_rom.read_bytes(), profile)
            if extra:
                atomic_write(extra_path, extra)
                print(f"[OK] Extracted private platform payload: {extra_path}")
            else:
                print(f"[OK] {args.profile} has no extra private platform payload")
            return 0
        if not all((args.header, args.prg, args.chr, args.output)):
            raise ValueError("build and verify require header, PRG, CHR, and output")
        extra = extra_path.read_bytes() if int(profile["extra_size"]) else b""
        image = build_image(
            profile,
            args.header.read_bytes(),
            args.prg.read_bytes(),
            args.chr.read_bytes(),
            extra,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(image)
        if args.command == "verify":
            if args.reference_rom is None:
                raise ValueError("verify requires a private reference ROM")
            reference = args.reference_rom.read_bytes()
            split_rom(reference, profile)
            if image != reference:
                raise ValueError("candidate differs from the private profile reference")
        print(f"[OK] {profile['id']}: ROM SHA1 {sha1(image)}")
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
