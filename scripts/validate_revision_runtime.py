#!/usr/bin/env python3
"""Run the common startup gate for a supported official revision profile."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path

from revision_profiles import load_profile


def load_forbidden_addresses(path: Path | None) -> list[str]:
    if path is None:
        return []
    document = json.loads(path.read_text(encoding="utf-8"))
    return [str(address) for address in document.get("forbidden_execute_addresses", [])]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--fceux", required=True, type=Path)
    parser.add_argument("--rom", required=True, type=Path)
    parser.add_argument("--movie", required=True, type=Path)
    parser.add_argument("--lua", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--forbidden-manifest", type=Path)
    args = parser.parse_args()
    for path in (args.fceux, args.rom, args.movie, args.lua):
        if not path.is_file():
            raise SystemExit(f"[ERROR] Runtime input not found: {path}")
    load_profile(args.manifest, args.profile)
    document = json.loads(args.manifest.read_text(encoding="utf-8"))
    runtime = document["runtime"]
    args.result.parent.mkdir(parents=True, exist_ok=True)
    args.result.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment.update(
        SMB_EXPANDED_FRAME=str(runtime["frame"]),
        SMB_EXPANDED_EXPECTED=json.dumps(runtime["expected_ram"], separators=(",", ":")),
        SMB_EXPANDED_RESULT=args.result.resolve().as_posix(),
    )
    forbidden = load_forbidden_addresses(args.forbidden_manifest)
    if forbidden:
        environment["SMB_RUNTIME_FORBID_EXECUTE"] = ",".join(forbidden)
    command = [
        str(args.fceux.resolve()),
    ]
    if args.profile == "pal":
        command.extend(["-pal", "1"])
    command.extend([
        "-playmovie", str(args.movie.resolve()),
        "-lua", str(args.lua.resolve()),
        "-max-frames", str(int(runtime["frame"]) + 5),
        "-turbo", "1",
        "-nothrottle", "1",
        str(args.rom.resolve()),
    ])
    subprocess.run(command, check=True, env=environment, cwd=args.rom.parent)
    result = args.result.read_text(encoding="ascii").strip() if args.result.is_file() else ""
    if result != "PASS":
        raise SystemExit(f"[ERROR] Revision runtime validation failed: {result or 'no result'}")
    print(f"[OK] {args.profile}: common engine reached active World 1-1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
