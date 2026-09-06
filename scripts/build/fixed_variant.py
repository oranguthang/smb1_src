#!/usr/bin/env python3
"""Verify that a fixed-layout variant differs only at declared bytes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_number(value: object) -> int:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return int(value, 0)
    raise ValueError(f"invalid integer: {value!r}")


def load_variant(path: Path, variant_id: str) -> dict[str, object]:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1:
        raise ValueError("unsupported fixed-layout variant manifest schema")
    matches = [item for item in document["variants"] if item["id"] == variant_id]
    if len(matches) != 1:
        raise ValueError(f"expected one variant named {variant_id!r}")
    return matches[0]


def verify_bytes(
    baseline: bytes,
    candidate: bytes,
    changes: list[dict[str, object]],
) -> None:
    if len(candidate) != len(baseline):
        raise ValueError(
            f"fixed-layout size changed: baseline={len(baseline)}, candidate={len(candidate)}"
        )
    declared = {parse_number(change["offset"]): change for change in changes}
    actual = {
        offset
        for offset, (original, replacement) in enumerate(zip(baseline, candidate))
        if original != replacement
    }
    if actual != set(declared):
        missing = sorted(set(declared) - actual)
        unexpected = sorted(actual - set(declared))
        raise ValueError(
            f"variant diff does not match manifest: missing={missing}, unexpected={unexpected}"
        )
    for offset, change in declared.items():
        expected_original = parse_number(change["original"])
        expected_replacement = parse_number(change["replacement"])
        if baseline[offset] != expected_original:
            raise ValueError(
                f"baseline byte at 0x{offset:04x} is 0x{baseline[offset]:02x}, "
                f"expected 0x{expected_original:02x}"
            )
        if candidate[offset] != expected_replacement:
            raise ValueError(
                f"variant byte at 0x{offset:04x} is 0x{candidate[offset]:02x}, "
                f"expected 0x{expected_replacement:02x}"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--variant", required=True)
    parser.add_argument("--baseline-prg", required=True, type=Path)
    parser.add_argument("--candidate-prg", required=True, type=Path)
    parser.add_argument("--baseline-rom", required=True, type=Path)
    parser.add_argument("--candidate-rom", required=True, type=Path)
    args = parser.parse_args()

    variant = load_variant(args.manifest, args.variant)
    changes = list(variant["changes"])
    if any(change.get("region") != "prg" for change in changes):
        raise SystemExit("[ERROR] Only PRG changes are supported by fixed-layout variants")
    try:
        verify_bytes(args.baseline_prg.read_bytes(), args.candidate_prg.read_bytes(), changes)
        rom_changes = [dict(change, offset=parse_number(change["offset"]) + 16) for change in changes]
        verify_bytes(args.baseline_rom.read_bytes(), args.candidate_rom.read_bytes(), rom_changes)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    print(f"[OK] {args.variant}: {len(changes)} declared byte difference(s), no others")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
