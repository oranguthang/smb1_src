#!/usr/bin/env python3
"""Build and verify the isolated CNROM expanded-ROM profile."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def load_manifest(path: Path) -> dict[str, object]:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1:
        raise ValueError("unsupported expanded-ROM manifest schema")
    if document.get("mapper") != 3:
        raise ValueError("this builder supports the reviewed Mapper 3 architecture")
    return document


def ines_header(manifest: dict[str, object]) -> bytes:
    prg_banks = int(manifest["prg_banks_16k"])
    chr_banks = int(manifest["chr_banks_8k"])
    mapper = int(manifest["mapper"])
    mirroring = 1 if manifest["mirroring"] == "vertical" else 0
    return bytes(
        [
            0x4E, 0x45, 0x53, 0x1A,
            prg_banks,
            chr_banks,
            ((mapper & 0x0F) << 4) | mirroring,
            mapper & 0xF0,
            0, 0, 0, 0, 0, 0, 0, 0,
        ]
    )


def build_image(
    manifest: dict[str, object],
    prg: bytes,
    canonical_chr: bytes,
) -> bytes:
    expected_prg_size = int(manifest["prg_banks_16k"]) * 16_384
    if len(prg) != expected_prg_size:
        raise ValueError(f"PRG size is {len(prg)}, expected {expected_prg_size}")
    if len(canonical_chr) != 8_192:
        raise ValueError(f"canonical CHR size is {len(canonical_chr)}, expected 8192")
    chr_banks = [canonical_chr for _ in manifest["chr_bank_sha1"]]
    if len(chr_banks) != int(manifest["chr_banks_8k"]):
        raise ValueError("CHR bank count does not match the manifest")
    return ines_header(manifest) + prg + b"".join(chr_banks)


def verify_image(
    manifest: dict[str, object],
    image: bytes,
    canonical_prg: bytes,
) -> None:
    header = ines_header(manifest)
    if not image.startswith(header):
        raise ValueError("generated iNES header does not match the reviewed mapper layout")
    prg_start = len(header)
    prg_end = prg_start + int(manifest["prg_banks_16k"]) * 16_384
    prg = image[prg_start:prg_end]
    if prg != canonical_prg:
        differences = [
            offset
            for offset, (original, candidate) in enumerate(zip(canonical_prg, prg))
            if original != candidate
        ]
        raise ValueError(
            f"fixed CPU range differs at {len(differences)} byte(s); "
            f"first={differences[0] if differences else 'size'}"
        )
    if sha1(prg) != manifest["prg_sha1"]:
        raise ValueError("fixed PRG hash does not match the architecture manifest")
    chr_data = image[prg_end:]
    expected_size = int(manifest["chr_banks_8k"]) * 8_192
    if len(chr_data) != expected_size:
        raise ValueError(f"expanded CHR size is {len(chr_data)}, expected {expected_size}")
    for index, expected_hash in enumerate(manifest["chr_bank_sha1"]):
        bank = chr_data[index * 8_192:(index + 1) * 8_192]
        if sha1(bank) != expected_hash:
            raise ValueError(f"CHR bank {index} does not match its declared hash")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--prg", required=True, type=Path)
    parser.add_argument("--chr", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    try:
        manifest = load_manifest(args.manifest)
        prg = args.prg.read_bytes()
        image = build_image(manifest, prg, args.chr.read_bytes())
        if args.verify:
            verify_image(manifest, image, prg)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(image)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    print(
        f"[OK] {manifest['id']}: mapper {manifest['mapper']}, "
        f"{len(image)} bytes, SHA1 {sha1(image)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
