#!/usr/bin/env python3
"""Run a focused emulator startup gate for a supported platform profile."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path

from platform_profiles import load_profile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--fceux", required=True, type=Path)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--lua", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    for path in (args.fceux, args.image, args.lua):
        if not path.is_file():
            raise SystemExit(f"[ERROR] Runtime input not found: {path}")
    profile = load_profile(args.manifest, args.profile)
    runtime = profile.get("runtime")
    if not isinstance(runtime, dict) or runtime.get("emulator") != "fceux":
        raise SystemExit(f"[ERROR] No FCEUX runtime contract for {args.profile}")
    args.result.parent.mkdir(parents=True, exist_ok=True)
    args.result.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment.update(
        SMB_PLATFORM_FRAME=str(int(runtime["frame"])),
        SMB_PLATFORM_EXPECTED=json.dumps(
            runtime["expected_ram"], separators=(",", ":")
        ),
        SMB_PLATFORM_RESULT=args.result.resolve().as_posix(),
        SMB_PLATFORM_CAPTURE="1" if args.capture else "0",
    )
    command = [
        str(args.fceux.resolve()),
        "-lua",
        str(args.lua.resolve()),
        "-max-frames",
        str(int(runtime["frame"]) + 5),
        "-turbo",
        "1",
        "-nothrottle",
        "1",
        str(args.image.resolve()),
    ]
    subprocess.run(command, check=True, env=environment, cwd=args.image.parent)
    result = args.result.read_text(encoding="ascii").strip() if args.result.is_file() else ""
    if args.capture:
        if not result.startswith("STATE:"):
            raise SystemExit(f"[ERROR] Platform runtime capture failed: {result or 'no result'}")
        print(result)
        return 0
    if result != "PASS":
        raise SystemExit(f"[ERROR] Platform runtime validation failed: {result or 'no result'}")
    print(f"[OK] {args.profile}: focused platform startup state verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
