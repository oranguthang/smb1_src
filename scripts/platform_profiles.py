#!/usr/bin/env python3
"""Split, build, and verify official platform-profile containers."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from dataclasses import dataclass
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


@dataclass(frozen=True)
class FdsFileRecord:
    file_number: int
    file_id: int
    name: bytes
    load_address: int
    size: int
    file_type: int
    header_offset: int
    data_offset: int


def parse_fds_side(image: bytes) -> list[FdsFileRecord]:
    if len(image) < 58 or image[0] != 1:
        raise ValueError("invalid FDS disk-information block")
    position = 56
    if image[position] != 2:
        raise ValueError("invalid FDS file-count block")
    file_count = image[position + 1]
    position += 2
    records: list[FdsFileRecord] = []
    for _ in range(file_count):
        header_offset = position
        header_end = header_offset + 16
        if header_end > len(image) or image[header_offset] != 3:
            raise ValueError("invalid FDS file-header block")
        header = image[header_offset:header_end]
        size = int.from_bytes(header[13:15], "little")
        if header_end >= len(image) or image[header_end] != 4:
            raise ValueError("invalid FDS file-data block")
        data_offset = header_end + 1
        data_end = data_offset + size
        if data_end > len(image):
            raise ValueError("truncated FDS file-data block")
        records.append(
            FdsFileRecord(
                file_number=header[1],
                file_id=header[2],
                name=header[3:11],
                load_address=int.from_bytes(header[11:13], "little"),
                size=size,
                file_type=header[15],
                header_offset=header_offset,
                data_offset=data_offset,
            )
        )
        position = data_end
    if any(image[position:]):
        raise ValueError("FDS side has nonzero data after the declared files")
    return records


def validate_fds_reference(image: bytes, profile: dict[str, Any]) -> None:
    if profile.get("format") != "fds_raw_side":
        raise ValueError(f"{profile['id']} is not a raw FDS side profile")
    if len(image) != int(profile["disk_size"]) or sha1(image) != profile["disk_sha1"]:
        raise ValueError("private platform reference does not match the selected profile")
    parse_fds_side(image)


def find_fds_record(
    records: list[FdsFileRecord], descriptor: dict[str, Any]
) -> FdsFileRecord:
    matches = [
        record
        for record in records
        if record.file_id == int(descriptor["file_id"])
    ]
    if len(matches) != 1:
        raise ValueError(f"FDS file ID is not unique: {descriptor['file_id']}")
    record = matches[0]
    expected = {
        "load_address": record.load_address,
        "size": record.size,
        "file_type": record.file_type,
    }
    for field, actual in expected.items():
        if field in descriptor and int(descriptor[field]) != actual:
            raise ValueError(
                f"FDS file {descriptor['file_id']} {field} does not match the profile"
            )
    return record


def extract_fds_payloads(
    image: bytes, profile: dict[str, Any]
) -> dict[str, bytes]:
    validate_fds_reference(image, profile)
    records = parse_fds_side(image)
    payloads: dict[str, bytes] = {}
    for payload in profile["verified_payloads"]:
        parts = []
        for descriptor in payload["records"]:
            record = find_fds_record(records, descriptor)
            parts.append(image[record.data_offset : record.data_offset + record.size])
        data = b"".join(parts)
        if len(data) != int(payload["size"]) or sha1(data) != payload["sha1"]:
            raise ValueError(f"payload hash mismatch for {profile['id']}: {payload['name']}")
        payloads[payload["name"]] = data
    return payloads


def extract_source_assets(
    payloads: dict[str, bytes], profile: dict[str, Any]
) -> dict[str, bytes]:
    assets: dict[str, bytes] = {}
    for descriptor in profile.get("source_assets", []):
        name = descriptor["name"]
        payload_name = descriptor["payload"]
        if name in assets:
            raise ValueError(f"duplicate source asset name: {name}")
        if payload_name not in payloads:
            raise ValueError(f"unknown source asset payload: {payload_name}")
        offset = int(descriptor["offset"])
        size = int(descriptor["size"])
        payload = payloads[payload_name]
        if offset < 0 or size < 0 or offset + size > len(payload):
            raise ValueError(f"source asset range exceeds payload: {name}")
        data = payload[offset : offset + size]
        if sha1(data) != descriptor["sha1"]:
            raise ValueError(f"source asset hash mismatch: {name}")
        assets[name] = data
    return assets


def make_fds_template(image: bytes, profile: dict[str, Any]) -> bytes:
    extract_fds_payloads(image, profile)
    template = bytearray(image)
    records = parse_fds_side(image)
    for payload in profile["verified_payloads"]:
        for descriptor in payload["records"]:
            record = find_fds_record(records, descriptor)
            template[record.data_offset : record.data_offset + record.size] = bytes(
                record.size
            )
    result = bytes(template)
    if sha1(result) != profile["template_sha1"]:
        raise ValueError(f"FDS template hash mismatch for {profile['id']}")
    return result


def build_fds_image(
    profile: dict[str, Any],
    template: bytes,
    payloads: dict[str, bytes],
    *,
    strict: bool = True,
) -> bytes:
    if len(template) != int(profile["disk_size"]):
        raise ValueError(f"FDS template size mismatch for {profile['id']}")
    if sha1(template) != profile["template_sha1"]:
        raise ValueError(f"FDS template hash mismatch for {profile['id']}")
    records = parse_fds_side(template)
    expected_names = {payload["name"] for payload in profile["verified_payloads"]}
    if set(payloads) != expected_names:
        raise ValueError(f"payload set mismatch for {profile['id']}")
    image = bytearray(template)
    for payload in profile["verified_payloads"]:
        name = payload["name"]
        data = payloads[name]
        if len(data) != int(payload["size"]):
            raise ValueError(f"payload size mismatch for {profile['id']}: {name}")
        if strict and sha1(data) != payload["sha1"]:
            raise ValueError(f"payload hash mismatch for {profile['id']}: {name}")
        position = 0
        for descriptor in payload["records"]:
            record = find_fds_record(records, descriptor)
            existing = template[record.data_offset : record.data_offset + record.size]
            if any(existing):
                raise ValueError(f"FDS template payload is not empty: {name}")
            part = data[position : position + record.size]
            if len(part) != record.size:
                raise ValueError(f"payload record sizes do not cover {name}")
            image[record.data_offset : record.data_offset + record.size] = part
            position += record.size
        if position != len(data):
            raise ValueError(f"payload record sizes do not cover {name}")
    result = bytes(image)
    if strict and sha1(result) != profile["disk_sha1"]:
        raise ValueError(f"FDS disk hash mismatch for {profile['id']}")
    return result


def payload_paths(
    profile: dict[str, Any],
    prg: Path | None,
    arguments: list[str],
    payload_dir: Path | None = None,
) -> dict[str, Path]:
    paths: dict[str, Path] = {}
    if prg is not None:
        primary = profile.get("primary_payload")
        if not isinstance(primary, str):
            raise ValueError(f"profile does not declare a primary payload: {profile['id']}")
        paths[primary] = prg
    for argument in arguments:
        name, separator, value = argument.partition("=")
        if not separator or not name or not value:
            raise ValueError(f"invalid payload argument: {argument}")
        if name in paths:
            raise ValueError(f"duplicate payload argument: {name}")
        paths[name] = Path(value)
    if payload_dir is not None:
        for payload in profile["verified_payloads"]:
            name = payload["name"]
            if name not in paths:
                paths[name] = payload_dir / f"{name}.bin"
    return paths


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
    parser.add_argument("--payload", action="append", default=[])
    parser.add_argument("--retain-primary", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        profile = load_profile(args.manifest, args.profile)
        profile_assets = args.asset_dir / args.profile
        profile_format = profile.get("format")
        if profile_format == "ines":
            header_path = profile_assets / "header.bin"
            chr_path = profile_assets / "chr.bin"
            if args.command == "split":
                if args.reference is None:
                    raise ValueError("split requires a private platform reference")
                header, prg_data, chr_data = split_ines_reference(
                    args.reference.read_bytes(), profile
                )
                source_assets = extract_source_assets(
                    {"header": header, "prg": prg_data, "chr": chr_data},
                    profile,
                )
                atomic_write(header_path, header)
                atomic_write(chr_path, chr_data)
                for name, data in source_assets.items():
                    atomic_write(profile_assets / "source" / f"{name}.bin", data)
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
        elif profile_format == "fds_raw_side":
            template_path = profile_assets / "template.fds"
            if args.command == "split":
                if args.reference is None:
                    raise ValueError("split requires a private platform reference")
                reference = args.reference.read_bytes()
                payloads = extract_fds_payloads(reference, profile)
                source_assets = extract_source_assets(payloads, profile)
                template = make_fds_template(reference, profile)
                atomic_write(template_path, template)
                primary = profile.get("primary_payload")
                for name, data in payloads.items():
                    if name != primary or args.retain_primary:
                        atomic_write(profile_assets / "payloads" / f"{name}.bin", data)
                for name, data in source_assets.items():
                    atomic_write(profile_assets / "source" / f"{name}.bin", data)
                print(f"[OK] Extracted private platform assets: {profile_assets}")
                return 0
            if args.output is None:
                raise ValueError("build and verify require an output path")
            paths = payload_paths(
                profile, args.prg, args.payload, profile_assets / "payloads"
            )
            image = build_fds_image(
                profile,
                template_path.read_bytes(),
                {name: path.read_bytes() for name, path in paths.items()},
                strict=args.command == "verify",
            )
        else:
            raise ValueError(
                f"container build is not implemented for {profile_format}: {profile['id']}"
            )
        atomic_write(args.output, image)
        if args.command == "verify":
            if args.reference is None:
                raise ValueError("verify requires a private platform reference")
            reference = args.reference.read_bytes()
            if profile_format == "ines":
                split_ines_reference(reference, profile)
            else:
                extract_fds_payloads(reference, profile)
            if image != reference:
                raise ValueError("candidate differs from the private platform reference")
        print(f"[OK] {profile['id']}: image SHA1 {sha1(image)}")
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
