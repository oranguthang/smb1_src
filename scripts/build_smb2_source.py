#!/usr/bin/env python3
"""Build and verify the four SMB2 FDS program payloads from project source."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

from build_native import resolve_tool, rooted, run_tool


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    raise SystemExit(1)


def number(value: Any, field: str) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        try:
            return int(value, 0)
        except ValueError:
            pass
    fail(f"invalid integer for {field}: {value!r}")
    raise AssertionError


def sha1(payload: bytes) -> str:
    return hashlib.sha1(payload).hexdigest()


def load_payload_contract(path: Path) -> list[dict[str, Any]]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read reconstruction manifest {path}: {exc}")
    if document.get("schema_version") != 1 or document.get("id") != "smb2_jp_fds":
        fail("unsupported SMB2 reconstruction manifest")
    payloads = document.get("payloads")
    if not isinstance(payloads, list) or not payloads:
        fail("SMB2 reconstruction manifest has no payload contract")
    for payload in payloads:
        if not isinstance(payload, dict):
            fail("invalid SMB2 payload contract")
        for field in ("name", "size", "sha1", "load_address", "source"):
            if field not in payload:
                fail(f"SMB2 payload contract lacks {field}")
    return payloads


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="src/revisions/smb2/build.asm")
    parser.add_argument("--config", default="config/linker/smb2_payloads.cfg")
    parser.add_argument("--manifest", default="config/smb2_reconstruction.json")
    parser.add_argument("--output-dir", default="build/smb2/source")
    parser.add_argument(
        "--verify",
        action="store_true",
        help="fail unless every source-built payload matches its recorded identity",
    )
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    source = rooted(project_root, args.source)
    config = rooted(project_root, args.config)
    manifest = rooted(project_root, args.manifest)
    output_dir = rooted(project_root, args.output_dir)
    for path, description in (
        (source, "SMB2 aggregate source"),
        (config, "SMB2 linker config"),
        (manifest, "SMB2 reconstruction manifest"),
    ):
        if not path.is_file():
            fail(f"{description} not found: {path}")

    payloads = load_payload_contract(manifest)
    expected_total = sum(number(payload["size"], "payload size") for payload in payloads)
    output_dir.mkdir(parents=True, exist_ok=True)
    object_path = output_dir / "smb2.o"
    combined_path = output_dir / "payloads.bin"
    labels_path = output_dir / "smb2.lbl"
    map_path = output_dir / "smb2.map"
    debug_path = output_dir / "smb2.dbg"

    run_tool(
        resolve_tool("ca65", project_root),
        [
            str(source),
            "-g",
            "--debug-info",
            "-I",
            str(source.parent),
            "-I",
            str(project_root / "src"),
            "-o",
            str(object_path),
        ],
        project_root,
    )
    run_tool(
        resolve_tool("ld65", project_root),
        [
            "-C",
            str(config),
            str(object_path),
            "-o",
            str(combined_path),
            "-Ln",
            str(labels_path),
            "--mapfile",
            str(map_path),
            "--dbgfile",
            str(debug_path),
        ],
        output_dir,
    )

    combined = combined_path.read_bytes()
    if len(combined) != expected_total:
        fail(
            f"combined payload size mismatch: expected {expected_total}, got {len(combined)}"
        )

    offset = 0
    mismatches: list[str] = []
    for payload in payloads:
        name = str(payload["name"])
        size = number(payload["size"], f"{name} size")
        data = combined[offset : offset + size]
        offset += size
        output = output_dir / f"{name}.bin"
        output.write_bytes(data)
        actual_hash = sha1(data)
        expected_hash = str(payload["sha1"]).lower()
        status = "OK" if actual_hash == expected_hash else "DIFF"
        print(f"[{status}] {name}: {size} bytes, SHA1 {actual_hash}")
        if actual_hash != expected_hash:
            mismatches.append(
                f"{name}: expected {expected_hash}, got {actual_hash}"
            )

    if offset != len(combined):
        fail("SMB2 payload contract does not consume the combined source output")
    if args.verify and mismatches:
        for mismatch in mismatches:
            print(f"[ERROR] {mismatch}", file=sys.stderr)
        fail(f"{len(mismatches)} SMB2 source payload(s) differ from the recorded identity")
    if mismatches:
        print(
            f"[WARN] Built {len(payloads)} SMB2 payloads with {len(mismatches)} identity difference(s)"
        )
    else:
        print(f"[OK] Built {len(payloads)} byte-identical SMB2 program payloads")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
