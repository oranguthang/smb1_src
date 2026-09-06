#!/usr/bin/env python3
"""Validate the expanded-ROM profile through focused FCEUX playback."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--fceux", required=True, type=Path)
    parser.add_argument("--rom", required=True, type=Path)
    parser.add_argument("--movie", required=True, type=Path)
    parser.add_argument("--lua", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    args = parser.parse_args()
    for path in (args.fceux, args.rom, args.movie, args.lua):
        if not path.is_file():
            raise SystemExit(f"[ERROR] Runtime input not found: {path}")
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    runtime = manifest["runtime"]
    args.result.parent.mkdir(parents=True, exist_ok=True)
    args.result.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment.update(
        SMB_EXPANDED_FRAME=str(runtime["frame"]),
        SMB_EXPANDED_EXPECTED=json.dumps(runtime["expected_ram"], separators=(",", ":")),
        SMB_EXPANDED_RESULT=args.result.resolve().as_posix(),
    )
    command = [
        str(args.fceux.resolve()),
        "-playmovie", str(args.movie.resolve()),
        "-lua", str(args.lua.resolve()),
        "-max-frames", str(int(runtime["frame"]) + 5),
        "-turbo", "1",
        "-nothrottle", "1",
        str(args.rom.resolve()),
    ]
    subprocess.run(command, check=True, env=environment, cwd=args.rom.parent)
    result = args.result.read_text(encoding="ascii").strip() if args.result.is_file() else ""
    if result != "PASS":
        raise SystemExit(f"[ERROR] Expanded runtime validation failed: {result or 'no result'}")
    print(f"[OK] {manifest['id']}: {runtime['meaning']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
