#!/usr/bin/env python3
"""Split, build, and verify official platform-profile containers."""

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
        raise ValueError("unsupported platform profile schema")
    matches = [item for item in document["profiles"] if item["id"] == profile_id]
    if len(matches) != 1:
        raise ValueError(f"platform profile not found: {profile_id}")
    return matches[0]


def validate_region(profile: dict[str, Any], name: str, data: bytes) -> None:
    if len(data) != int(profile[f"{name}_size"]):
        raise ValueError(f"{name} size mismatch for {profile['id']}")
    if sha1(data) != profile[f"{name}_sha1"]:
        raise ValueError(f"{name} hash mismatch for {profile['id']}")


def split_ines_reference(
    image: bytes,
    profile: dict[str, Any],
) -> tuple[bytes, bytes, bytes]:
    if profile.get("format") != "ines":
        raise ValueError(f"{profile['id']} is not an iNES platform profile")
    if len(image) != int(profile["rom_size"]) or sha1(image) != profile["rom_sha1"]:
        raise ValueError("private platform reference does not match the selected profile")
    header_end = int(profile["header_size"])
    prg_end = header_end + int(profile["prg_size"])
    chr_end = prg_end + int(profile["chr_size"])
    if chr_end != len(image):
        raise ValueError("iNES platform regions do not cover the complete reference")
    regions = image[:header_end], image[header_end:prg_end], image[prg_end:chr_end]
    for name, region in zip(("header", "prg", "chr"), regions):
        validate_region(profile, name, region)
    return regions


def build_ines_image(
    profile: dict[str, Any],
    header: bytes,
    prg: bytes,
    chr_data: bytes,
) -> bytes:
    for name, region in (("header", header), ("prg", prg), ("chr", chr_data)):
        validate_region(profile, name, region)
    image = header + prg + chr_data
    if len(image) != int(profile["rom_size"]):
        raise ValueError(f"ROM size mismatch for {profile['id']}")
    if sha1(image) != profile["rom_sha1"]:
        raise ValueError(f"ROM hash mismatch for {profile['id']}")
    return image


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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("split", "build", "verify"))
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--asset-dir", required=True, type=Path)
    parser.add_argument("--prg", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        profile = load_profile(args.manifest, args.profile)
        if profile.get("format") != "ines":
            raise ValueError(
                f"container build is not implemented for {profile['format']}: {profile['id']}"
            )
        profile_assets = args.asset_dir / args.profile
        header_path = profile_assets / "header.bin"
        chr_path = profile_assets / "chr.bin"
        if args.command == "split":
            if args.reference is None:
                raise ValueError("split requires a private platform reference")
            header, _, chr_data = split_ines_reference(
                args.reference.read_bytes(), profile
            )
            atomic_write(header_path, header)
            atomic_write(chr_path, chr_data)
            print(f"[OK] Extracted private platform assets: {profile_assets}")
            return 0
        if args.prg is None or args.output is None:
            raise ValueError("build and verify require PRG and output paths")
        image = build_ines_image(
            profile,
            header_path.read_bytes(),
            args.prg.read_bytes(),
            chr_path.read_bytes(),
        )
        atomic_write(args.output, image)
        if args.command == "verify":
            if args.reference is None:
                raise ValueError("verify requires a private platform reference")
            reference = args.reference.read_bytes()
            split_ines_reference(reference, profile)
            if image != reference:
                raise ValueError("candidate differs from the private platform reference")
        print(f"[OK] {profile['id']}: ROM SHA1 {sha1(image)}")
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
