#!/usr/bin/env python3
"""Run deterministic FM2/Lua runtime scenarios through FCEUX."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path


def sha1(path: Path) -> str:
    digest = hashlib.sha1()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fceux", required=True, type=Path)
    parser.add_argument("--rom", required=True, type=Path)
    parser.add_argument("--movie", required=True, type=Path)
    parser.add_argument("--lua", required=True, type=Path)
    parser.add_argument("--scenarios", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--scenario", action="append", dest="selected")
    args = parser.parse_args()

    required = (args.fceux, args.rom, args.movie, args.lua, args.scenarios)
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"[ERROR] Missing runtime input: {', '.join(missing)}")
    document = json.loads(args.scenarios.read_text(encoding="utf-8"))
    for path, expected in ((args.rom, document["rom_sha1"]), (args.movie, document["movie_sha1"])):
        actual = sha1(path)
        if actual != expected:
            raise SystemExit(f"[ERROR] SHA-1 mismatch for {path}: expected={expected}, actual={actual}")

    configured = {scenario["id"] for scenario in document["scenarios"]}
    selected = set(args.selected or configured)
    unknown = selected - configured
    if unknown:
        raise SystemExit(f"[ERROR] Unknown runtime scenario: {', '.join(sorted(unknown))}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for scenario in document["scenarios"]:
        if scenario["id"] not in selected:
            continue
        output = args.output_dir / f"{scenario['id']}.csv"
        output.unlink(missing_ok=True)
        environment = os.environ.copy()
        environment.update(
            SMB_RUNTIME_TRACE=str(output.resolve()).replace("\\", "/"),
            SMB_RUNTIME_SCENARIO=scenario["id"],
            SMB_RUNTIME_MAX_FRAMES=str(scenario["max_frames"]),
        )
        forbidden = document.get("forbidden_execute_addresses", [])
        if forbidden:
            environment["SMB_RUNTIME_FORBID_EXECUTE"] = ",".join(
                str(address) for address in forbidden
            )
        command = [
            str(args.fceux.resolve()),
            "-playmovie", str(args.movie.resolve()),
            "-lua", str(args.lua.resolve()),
            "-max-frames", str(scenario["max_frames"] + 2),
            "-turbo", "1",
            "-nothrottle", "1",
            str(args.rom.resolve()),
        ]
        print(f"[RUN] {scenario['id']}: {scenario['method']}", flush=True)
        subprocess.run(command, check=True, env=environment, cwd=args.rom.parent)
        if not output.is_file() or output.stat().st_size == 0:
            raise SystemExit(f"[ERROR] Runtime trace was not created: {output}")
        print(f"[OK] Runtime trace: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
