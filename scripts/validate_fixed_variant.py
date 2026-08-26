#!/usr/bin/env python3
"""Validate a fixed-layout variant's intended RAM effect in FCEUX."""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path

from fixed_variant import load_variant, parse_number


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--variant", required=True)
    parser.add_argument("--fceux", required=True, type=Path)
    parser.add_argument("--rom", required=True, type=Path)
    parser.add_argument("--movie", required=True, type=Path)
    parser.add_argument("--lua", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    args = parser.parse_args()
    for path in (args.fceux, args.rom, args.movie, args.lua):
        if not path.is_file():
            raise SystemExit(f"[ERROR] Runtime input not found: {path}")
    variant = load_variant(args.manifest, args.variant)
    runtime = variant["runtime"]
    args.result.parent.mkdir(parents=True, exist_ok=True)
    args.result.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment.update(
        SMB_VARIANT_HOOK=f"{parse_number(runtime['hook_cpu_address']):x}",
        SMB_VARIANT_RAM=f"{parse_number(runtime['ram_address']):x}",
        SMB_VARIANT_EXPECTED=f"{parse_number(runtime['expected']):x}",
        SMB_VARIANT_RESULT=args.result.resolve().as_posix(),
    )
    command = [
        str(args.fceux.resolve()),
        "-playmovie", str(args.movie.resolve()),
        "-lua", str(args.lua.resolve()),
        "-max-frames", "220",
        "-turbo", "1",
        "-nothrottle", "1",
        str(args.rom.resolve()),
    ]
    subprocess.run(command, check=True, env=environment, cwd=args.rom.parent)
    result = args.result.read_text(encoding="ascii").strip() if args.result.is_file() else ""
    if result != "PASS":
        raise SystemExit(f"[ERROR] Variant runtime validation failed: {result or 'no result'}")
    print(f"[OK] {args.variant}: {runtime['meaning']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
