#!/usr/bin/env python3
"""Run deterministic SMB2 gameplay and compare a relocation candidate."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path

from platform_profiles import load_profile
from validate_platform_runtime import load_forbidden_addresses, validate_fds_bios


def gameplay_environment(
    runtime: dict[str, object],
    result: Path,
    forbidden: list[str],
) -> dict[str, str]:
    gameplay = runtime.get("gameplay")
    if not isinstance(gameplay, dict):
        raise ValueError("SMB2 profile has no gameplay contract")
    required = (
        "boot_task",
        "ready_mode",
        "ready_task",
        "ready_engine",
        "ready_timeout_frames",
        "run_frames",
        "minimum_active_frames",
        "minimum_progress_pixels",
    )
    missing = [field for field in required if field not in gameplay]
    if missing:
        raise ValueError(f"SMB2 gameplay contract lacks {', '.join(missing)}")
    environment = {
        "SMB2_GAMEPLAY_BOOT_FRAME": str(int(runtime["frame"])),
        "SMB2_GAMEPLAY_BOOT_TASK": str(int(gameplay["boot_task"])),
        "SMB2_GAMEPLAY_READY_MODE": str(int(gameplay["ready_mode"])),
        "SMB2_GAMEPLAY_READY_TASK": str(int(gameplay["ready_task"])),
        "SMB2_GAMEPLAY_READY_ENGINE": str(int(gameplay["ready_engine"])),
        "SMB2_GAMEPLAY_READY_TIMEOUT": str(int(gameplay["ready_timeout_frames"])),
        "SMB2_GAMEPLAY_RUN_FRAMES": str(int(gameplay["run_frames"])),
        "SMB2_GAMEPLAY_MINIMUM_ACTIVE": str(int(gameplay["minimum_active_frames"])),
        "SMB2_GAMEPLAY_MINIMUM_PROGRESS": str(int(gameplay["minimum_progress_pixels"])),
        "SMB2_GAMEPLAY_RESULT": result.resolve().as_posix(),
    }
    if forbidden:
        environment["SMB_RUNTIME_FORBID_EXECUTE"] = ",".join(forbidden)
    return environment


def run_gameplay(
    fceux: Path,
    image: Path,
    lua: Path,
    runtime: dict[str, object],
    result: Path,
    forbidden: list[str],
) -> str:
    result.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment.update(gameplay_environment(runtime, result, forbidden))
    gameplay = runtime["gameplay"]
    maximum_frames = (
        int(runtime["frame"])
        + int(gameplay["ready_timeout_frames"])
        + int(gameplay["run_frames"])
        + 10
    )
    command = [
        str(fceux.resolve()),
        "-lua",
        str(lua.resolve()),
        "-max-frames",
        str(maximum_frames),
        "-turbo",
        "1",
        "-nothrottle",
        "1",
        str(image.resolve()),
    ]
    subprocess.run(command, check=True, env=environment, cwd=fceux.parent)
    return result.read_text(encoding="ascii").strip() if result.is_file() else ""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--fceux", required=True, type=Path)
    parser.add_argument("--fds-bios", required=True, type=Path)
    parser.add_argument("--baseline-image", required=True, type=Path)
    parser.add_argument("--candidate-image", type=Path)
    parser.add_argument("--lua", required=True, type=Path)
    parser.add_argument("--result-dir", required=True, type=Path)
    parser.add_argument("--forbidden-manifest", type=Path)
    args = parser.parse_args()
    for path in (args.fceux, args.baseline_image, args.lua):
        if not path.is_file():
            raise SystemExit(f"[ERROR] SMB2 gameplay input not found: {path}")
    if args.candidate_image is not None and not args.candidate_image.is_file():
        raise SystemExit(f"[ERROR] SMB2 gameplay candidate not found: {args.candidate_image}")
    profile = load_profile(args.manifest, args.profile)
    runtime = profile.get("runtime")
    if not isinstance(runtime, dict) or runtime.get("emulator") != "fceux":
        raise SystemExit(f"[ERROR] No FCEUX runtime contract for {args.profile}")
    try:
        validate_fds_bios(args.fceux, args.fds_bios, runtime)
        gameplay_environment(runtime, args.result_dir / "probe.txt", [])
    except ValueError as error:
        raise SystemExit(f"[ERROR] {error}") from error
    args.result_dir.mkdir(parents=True, exist_ok=True)
    baseline = run_gameplay(
        args.fceux,
        args.baseline_image,
        args.lua,
        runtime,
        args.result_dir / "baseline.txt",
        [],
    )
    if not baseline.startswith("PASS:"):
        raise SystemExit(f"[ERROR] SMB2 baseline gameplay failed: {baseline or 'no result'}")
    print("[OK] SMB2 baseline: deterministic World 1-1 gameplay reached")
    if args.candidate_image is None:
        return 0
    forbidden = load_forbidden_addresses(args.forbidden_manifest)
    candidate = run_gameplay(
        args.fceux,
        args.candidate_image,
        args.lua,
        runtime,
        args.result_dir / "candidate.txt",
        forbidden,
    )
    if candidate != baseline:
        raise SystemExit(
            "[ERROR] SMB2 relocated gameplay differs from baseline: "
            f"baseline={baseline or 'no result'} candidate={candidate or 'no result'}"
        )
    print("[OK] SMB2 relocation: deterministic gameplay state matches baseline")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
