#!/usr/bin/env python3
"""Verify that SMB2 loads each reconstructed overlay through its FDS loader."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path

from platform_profiles import load_profile
from validate_platform_runtime import load_forbidden_addresses, validate_fds_bios


SIGNATURE_SIZE = 16
REQUIRED_PLAN_FIELDS = (
    "mode",
    "mode_task",
    "disk_task",
    "file_list",
    "world",
    "hard_world",
    "expected_disk_task",
    "timeout_frames",
)


def overlay_plans(profile: dict[str, object]) -> list[dict[str, object]]:
    runtime = profile.get("runtime")
    if not isinstance(runtime, dict):
        raise ValueError("SMB2 profile has no runtime contract")
    plans = runtime.get("overlay_loads")
    if not isinstance(plans, list) or not plans:
        raise ValueError("SMB2 profile has no overlay load plans")
    payloads = {
        str(payload["name"]): payload
        for payload in profile.get("verified_payloads", [])
        if isinstance(payload, dict) and "name" in payload
    }
    expected_names = set(payloads) - {str(profile.get("primary_payload", ""))}
    actual_names: list[str] = []
    for plan in plans:
        if not isinstance(plan, dict) or "name" not in plan:
            raise ValueError("SMB2 overlay load plan is not an object with a name")
        name = str(plan["name"])
        if name not in payloads:
            raise ValueError(f"SMB2 overlay plan references unknown payload {name}")
        missing = [field for field in REQUIRED_PLAN_FIELDS if field not in plan]
        if missing:
            raise ValueError(f"{name} overlay plan is missing {', '.join(missing)}")
        actual_names.append(name)
    if len(actual_names) != len(set(actual_names)):
        raise ValueError("SMB2 overlay load plans contain duplicate payload names")
    if set(actual_names) != expected_names:
        raise ValueError(
            "SMB2 overlay load plans must cover exactly "
            + ", ".join(sorted(expected_names))
        )
    return plans


def checked_payload(payload_dir: Path, payload: dict[str, object]) -> tuple[int, bytes]:
    name = str(payload["name"])
    path = payload_dir / f"{name}.bin"
    if not path.is_file():
        raise ValueError(f"SMB2 payload not found: {path}")
    data = path.read_bytes()
    expected_size = int(payload["size"])
    if len(data) != expected_size:
        raise ValueError(
            f"{name} size mismatch: got {len(data)}, expected {expected_size}"
        )
    digest = hashlib.sha1(data).hexdigest()
    if digest != str(payload["sha1"]):
        raise ValueError(
            f"{name} SHA1 mismatch: got {digest}, expected {payload['sha1']}"
        )
    records = payload.get("records")
    if not isinstance(records, list) or len(records) != 1:
        raise ValueError(f"{name} requires exactly one FDS load record")
    return int(records[0]["load_address"]), data


def checked_signature(
    payload_dir: Path,
    payload: dict[str, object],
    primary_payload: dict[str, object] | None = None,
) -> tuple[int, str]:
    load_address, data = checked_payload(payload_dir, payload)
    signature_offset = 0
    if primary_payload is not None:
        primary_address, primary_data = checked_payload(
            payload_dir, primary_payload
        )
        primary_offset = load_address - primary_address
        if primary_offset < 0 or primary_offset + len(data) > len(primary_data):
            raise ValueError(
                f"{payload['name']} lies outside the primary payload address range"
            )
        baseline = primary_data[primary_offset:primary_offset + len(data)]
        difference = next(
            (index for index, value in enumerate(data) if value != baseline[index]),
            None,
        )
        if difference is None:
            raise ValueError(f"{payload['name']} is identical to the primary payload")
        signature_offset = max(0, difference - SIGNATURE_SIZE // 2)
        signature_offset = min(signature_offset, len(data) - SIGNATURE_SIZE)
    signature = data[signature_offset:signature_offset + SIGNATURE_SIZE]
    return load_address + signature_offset, signature.hex()


def relocated_payloads(
    profile: dict[str, object],
    summary_path: Path | None,
    image: Path,
) -> dict[str, dict[str, object]]:
    payloads = {
        str(payload["name"]): dict(payload)
        for payload in profile["verified_payloads"]
    }
    if summary_path is None:
        return payloads
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    expected_hashes = summary.get("candidate_payload_sha1")
    if not isinstance(expected_hashes, dict) or set(expected_hashes) != set(payloads):
        raise ValueError("relocation summary does not cover every SMB2 payload")
    expected_image_hash = str(summary.get("candidate_image_sha1", ""))
    actual_image_hash = hashlib.sha1(image.read_bytes()).hexdigest()
    if actual_image_hash != expected_image_hash:
        raise ValueError(
            "relocation image SHA1 differs from its generated summary: "
            f"got {actual_image_hash}, expected {expected_image_hash}"
        )
    for name, digest in expected_hashes.items():
        payloads[name]["sha1"] = str(digest)
    return payloads


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--fceux", required=True, type=Path)
    parser.add_argument("--fds-bios", required=True, type=Path)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--payload-dir", required=True, type=Path)
    parser.add_argument("--lua", required=True, type=Path)
    parser.add_argument("--result-dir", required=True, type=Path)
    parser.add_argument("--forbidden-manifest", type=Path)
    parser.add_argument("--relocation-summary", type=Path)
    args = parser.parse_args()
    for path in (args.fceux, args.image, args.lua):
        if not path.is_file():
            raise SystemExit(f"[ERROR] SMB2 overlay runtime input not found: {path}")
    profile = load_profile(args.manifest, args.profile)
    runtime = profile.get("runtime")
    if not isinstance(runtime, dict) or runtime.get("emulator") != "fceux":
        raise SystemExit(f"[ERROR] No FCEUX runtime contract for {args.profile}")
    try:
        validate_fds_bios(args.fceux, args.fds_bios, runtime)
        plans = overlay_plans(profile)
    except ValueError as error:
        raise SystemExit(f"[ERROR] {error}") from error
    try:
        payloads = relocated_payloads(profile, args.relocation_summary, args.image)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"[ERROR] {error}") from error
    primary_name = str(profile["primary_payload"])
    primary_payload = payloads[primary_name]
    args.result_dir.mkdir(parents=True, exist_ok=True)
    forbidden = load_forbidden_addresses(args.forbidden_manifest)
    for plan in plans:
        name = str(plan["name"])
        try:
            load_address, signature = checked_signature(
                args.payload_dir, payloads[name], primary_payload
            )
        except ValueError as error:
            raise SystemExit(f"[ERROR] {error}") from error
        result_path = args.result_dir / f"{name.lower()}.txt"
        result_path.unlink(missing_ok=True)
        environment = os.environ.copy()
        environment.update(
            SMB2_OVERLAY_NAME=name,
            SMB2_OVERLAY_BOOT_FRAME=str(int(runtime["frame"])),
            SMB2_OVERLAY_MODE=str(int(plan["mode"])),
            SMB2_OVERLAY_MODE_TASK=str(int(plan["mode_task"])),
            SMB2_OVERLAY_DISK_TASK=str(int(plan["disk_task"])),
            SMB2_OVERLAY_FILE_LIST=str(int(plan["file_list"])),
            SMB2_OVERLAY_WORLD=str(int(plan["world"])),
            SMB2_OVERLAY_HARD_WORLD=str(int(plan["hard_world"])),
            SMB2_OVERLAY_EXPECTED_DISK_TASK=str(int(plan["expected_disk_task"])),
            SMB2_OVERLAY_TIMEOUT=str(int(plan["timeout_frames"])),
            SMB2_OVERLAY_LOAD_ADDRESS=str(load_address),
            SMB2_OVERLAY_SIGNATURE=signature,
            SMB2_OVERLAY_RESULT=result_path.resolve().as_posix(),
        )
        if forbidden:
            environment["SMB_RUNTIME_FORBID_EXECUTE"] = ",".join(forbidden)
        command = [
            str(args.fceux.resolve()),
            "-lua",
            str(args.lua.resolve()),
            "-max-frames",
            str(int(runtime["frame"]) + int(plan["timeout_frames"]) + 5),
            "-turbo",
            "1",
            "-nothrottle",
            "1",
            str(args.image.resolve()),
        ]
        subprocess.run(command, check=True, env=environment, cwd=args.fceux.parent)
        result = (
            result_path.read_text(encoding="ascii").strip()
            if result_path.is_file()
            else ""
        )
        if not result.startswith(f"PASS:{name}:"):
            raise SystemExit(
                f"[ERROR] {name} FDS overlay load failed: {result or 'no result'}"
            )
        print(f"[OK] {name}: reconstructed payload loaded through the FDS engine")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
