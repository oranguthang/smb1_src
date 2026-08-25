#!/usr/bin/env python3
"""Run and validate the live FCEUX semantic-symbol smoke test."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path


REQUIRED_SYMBOLS = (
    "vec_nmi_handler",
    "sub_oper_mode_execution_tree",
    "sub_update_player_movement",
    "sub_bump_block",
    "sub_give_one_coin",
    "handler_vertical_pipe_entry",
    "handler_flagpole_slide",
    "ram_oper_mode",
)


def resolved_addresses(summary_path: Path) -> dict[str, int]:
    document = json.loads(summary_path.read_text(encoding="utf-8"))
    addresses: dict[str, int] = {}
    for section in ("breakpoint_groups", "watch_groups"):
        for entries in document[section].values():
            for entry in entries:
                addresses.setdefault(entry["symbol"], int(entry["address"]))
    missing = sorted(set(REQUIRED_SYMBOLS) - addresses.keys())
    if missing:
        raise ValueError(f"Debug summary lacks required symbols: {', '.join(missing)}")
    return {name: addresses[name] for name in REQUIRED_SYMBOLS}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fceux", required=True, type=Path)
    parser.add_argument("--rom", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--lua", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    args = parser.parse_args()

    required = (args.fceux, args.rom, args.summary, args.lua)
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise SystemExit(f"[ERROR] Missing debugger runtime input: {', '.join(missing)}")
    addresses = resolved_addresses(args.summary)
    args.result.parent.mkdir(parents=True, exist_ok=True)
    args.result.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment["SMB_DEBUG_SYMBOL_RESULT"] = str(args.result.resolve()).replace("\\", "/")
    environment["SMB_DEBUG_EXPECTED"] = ",".join(
        f"{name}={address:04X}" for name, address in addresses.items()
    )
    command = [
        str(args.fceux.resolve()),
        "-lua", str(args.lua.resolve()),
        "-max-frames", "180",
        "-turbo", "1",
        "-nothrottle", "1",
        str(args.rom.resolve()),
    ]
    subprocess.run(command, check=True, env=environment, cwd=args.rom.parent)
    if not args.result.is_file():
        raise SystemExit(f"[ERROR] Debug runtime result not found: {args.result}")
    lines = args.result.read_text(encoding="utf-8").splitlines()
    failures = [line for line in lines if line.startswith("FAIL,")]
    symbols = [line for line in lines if line.startswith("symbol,")]
    breaks = [line for line in lines if line.startswith("break,")]
    if failures:
        raise SystemExit(f"[ERROR] Runtime debugger validation failed: {failures[0]}")
    if lines[-1:] != ["OK"] or len(symbols) != len(REQUIRED_SYMBOLS) or len(breaks) != 1:
        raise SystemExit("[ERROR] Incomplete runtime debugger validation result")
    print(f"[OK] Runtime debugger validation: {len(symbols)} symbol lookups and semantic NMI break")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
