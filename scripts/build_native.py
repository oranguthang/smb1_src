#!/usr/bin/env python3
"""Build the native ca65 source and optionally verify the complete ROM."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_number(value: Any, field: str) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        try:
            return int(value, 0)
        except ValueError:
            pass
    fail(f"invalid integer for {field}: {value!r}")
    raise AssertionError


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def rooted(project_root: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else project_root / path


def resolve_tool(name: str, project_root: Path) -> Path:
    bundled = project_root / "bin" / f"{name}.exe"
    if bundled.is_file():
        return bundled
    found = shutil.which(name)
    if found:
        return Path(found)
    fail(f"{name} not found (expected in bin/ or PATH)")
    raise AssertionError


def run_tool(tool: Path, arguments: list[str], cwd: Path) -> None:
    command = [str(tool), *arguments]
    if os.name != "nt" and tool.suffix.lower() == ".exe":
        wine = shutil.which("wine")
        if not wine:
            fail(f"wine not found in PATH (needed to run {tool.name})")
        command.insert(0, wine)
    print("[RUN]", " ".join(command))
    result = subprocess.run(command, cwd=cwd, check=False)
    if result.returncode:
        fail(f"command failed with exit code {result.returncode}")


def first_difference(left: bytes, right: bytes) -> int | None:
    for offset, (left_byte, right_byte) in enumerate(zip(left, right)):
        if left_byte != right_byte:
            return offset
    return min(len(left), len(right)) if len(left) != len(right) else None


def parse_ines(rom: bytes) -> tuple[bytes, bytes, bytes]:
    if len(rom) < 16 or rom[:4] != b"NES\x1a":
        fail("reference ROM is not a valid iNES image")
    trainer_size = 512 if rom[6] & 0x04 else 0
    prg_size = rom[4] * 16_384
    chr_size = rom[5] * 8_192
    prg_start = 16 + trainer_size
    chr_start = prg_start + prg_size
    expected_size = chr_start + chr_size
    if len(rom) != expected_size:
        fail(
            f"reference ROM size is {len(rom)}, expected exactly {expected_size}"
        )
    return rom[:prg_start], rom[prg_start:chr_start], rom[chr_start:]


def require_file(path: Path, description: str) -> bytes:
    if not path.is_file():
        fail(f"{description} not found: {path}")
    return path.read_bytes()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="src/main.asm")
    parser.add_argument("--config", default="src/nrom256_prg_only.cfg")
    parser.add_argument("--manifest", default="assets/manifest.json")
    parser.add_argument("--original-rom")
    parser.add_argument("--header")
    parser.add_argument("--chr")
    parser.add_argument("--object", default="build/native/smbdis.o")
    parser.add_argument("--prg", default="build/native/smb.prg")
    parser.add_argument("--labels", default="build/native/smb.lbl")
    parser.add_argument("--map", default="build/native/smb.map")
    parser.add_argument("--debug-info", default="build/native/smb.dbg")
    parser.add_argument("--output-rom", default="build/native/smb.nes")
    parser.add_argument(
        "--prg-only",
        action="store_true",
        help="build the PRG without requiring local ROM assets",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="fail unless the generated output matches the reference",
    )
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    source = rooted(project_root, args.source)
    config = rooted(project_root, args.config)
    manifest_path = rooted(project_root, args.manifest)
    object_path = rooted(project_root, args.object)
    prg_path = rooted(project_root, args.prg)
    labels_path = rooted(project_root, args.labels)
    map_path = rooted(project_root, args.map)
    debug_path = rooted(project_root, args.debug_info)
    output_rom = rooted(project_root, args.output_rom)

    for path, description in (
        (source, "source"),
        (config, "linker config"),
        (manifest_path, "asset manifest"),
    ):
        if not path.is_file():
            fail(f"{description} not found: {path}")

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read manifest: {exc}")
    if manifest.get("schema_version") != 1:
        fail("unsupported asset manifest schema")
    reference = manifest.get("reference_rom", {})
    expected_prg_size = parse_number(reference.get("prg_size"), "prg_size")
    expected_prg_hash = str(reference.get("prg_sha1", "")).lower()

    for path in (object_path, prg_path, labels_path, map_path, debug_path):
        path.parent.mkdir(parents=True, exist_ok=True)
    ca65 = resolve_tool("ca65", project_root)
    ld65 = resolve_tool("ld65", project_root)
    run_tool(
        ca65,
        [
            str(source),
            "-g",
            "-I",
            str(source.parent),
            "-o",
            str(object_path),
        ],
        project_root,
    )
    run_tool(
        ld65,
        [
            "-C",
            str(config),
            str(object_path),
            "-o",
            str(prg_path),
            "-Ln",
            str(labels_path),
            "--mapfile",
            str(map_path),
            "--dbgfile",
            str(debug_path),
        ],
        prg_path.parent,
    )

    prg = require_file(prg_path, "linked PRG")
    prg_hash = sha1(prg)
    print(f"[INFO] PRG size: {len(prg)} bytes")
    print(f"[INFO] PRG SHA1: {prg_hash}")
    if len(prg) != expected_prg_size:
        fail(
            f"PRG size mismatch: expected {expected_prg_size}, got {len(prg)}"
        )
    if args.verify and prg_hash != expected_prg_hash:
        fail(
            f"PRG SHA1 mismatch: expected {expected_prg_hash}, got {prg_hash}"
        )

    if args.prg_only:
        if prg_hash == expected_prg_hash:
            print("[OK] PRG matches the recorded reconstruction baseline.")
        else:
            print(f"[WARN] PRG differs from baseline {expected_prg_hash}.")
        return 0

    if not args.original_rom or not args.header or not args.chr:
        fail("--original-rom, --header, and --chr are required for a ROM build")
    original_path = rooted(project_root, args.original_rom)
    header_path = rooted(project_root, args.header)
    chr_path = rooted(project_root, args.chr)
    original = require_file(original_path, "reference ROM")
    header = require_file(header_path, "generated header asset")
    chr_data = require_file(chr_path, "generated CHR asset")

    expected_rom_hash = str(reference.get("sha1", "")).lower()
    original_hash = sha1(original)
    if original_hash != expected_rom_hash:
        fail(
            f"reference ROM SHA1 mismatch: expected {expected_rom_hash}, "
            f"got {original_hash}"
        )
    original_header, original_prg, original_chr = parse_ines(original)
    expected_header_size = parse_number(
        reference.get("header_size"), "header_size"
    )
    expected_chr_size = parse_number(reference.get("chr_size"), "chr_size")
    if len(header) != expected_header_size:
        fail(
            f"header size mismatch: expected {expected_header_size}, "
            f"got {len(header)}"
        )
    if len(chr_data) != expected_chr_size:
        fail(
            f"CHR size mismatch: expected {expected_chr_size}, "
            f"got {len(chr_data)}"
        )

    for name, actual, expected in (
        ("header", header, original_header),
        ("PRG", prg, original_prg),
        ("CHR", chr_data, original_chr),
    ):
        difference = first_difference(actual, expected)
        if difference is not None:
            message = f"first {name} difference at offset 0x{difference:X}"
            if name == "PRG":
                cpu_base = parse_number(
                    reference.get("prg_cpu_base"), "prg_cpu_base"
                )
                message += f" (CPU 0x{cpu_base + difference:04X})"
            if args.verify:
                fail(message)
            print(f"[WARN] {message}")

    candidate = header + prg + chr_data
    output_rom.parent.mkdir(parents=True, exist_ok=True)
    output_rom.write_bytes(candidate)
    candidate_hash = sha1(candidate)
    print(f"[INFO] ROM SHA1: {candidate_hash}")
    if candidate == original:
        print(f"[OK] Byte-identical ROM reproduced: {output_rom}")
        return 0
    difference = first_difference(candidate, original)
    print(f"[WARN] First ROM difference at file offset 0x{difference:06X}")
    return 1 if args.verify else 0


if __name__ == "__main__":
    raise SystemExit(main())
