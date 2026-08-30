#!/usr/bin/env python3
"""Prepare profile-correct emulator metadata without changing canonical builds."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from content_profiles import load_profiles, require_supported


def prepare_emulator_image(
    source: Path,
    output: Path,
    profile: dict[str, Any],
) -> Path:
    ppu = profile.get("ppu", {})
    ppu_id = ppu.get("nes2_vs_ppu_id")
    if ppu_id is None:
        return source
    image = bytearray(source.read_bytes())
    if len(image) < 16 or image[:4] != b"NES\x1a":
        raise ValueError("Vs. emulator image must use an iNES container")
    if not 0 <= int(ppu_id) <= 0x0F:
        raise ValueError("NES 2.0 Vs. PPU ID must fit one nibble")
    image[7] = (image[7] & 0xF0) | 0x09
    image[8] &= 0x0F
    image[13] = int(ppu_id)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(image)
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profiles", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    profile = require_supported(load_profiles(args.profiles), args.profile)
    prepared = prepare_emulator_image(args.input, args.output, profile)
    print(f"[OK] Emulator image: {prepared}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
