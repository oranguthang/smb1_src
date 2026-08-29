#!/usr/bin/env python3
"""Prove selected residual entries have no source or binary references."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SYMBOL_PATTERN = re.compile(
    r'^sym\t.*name="([^"]+)".*val=0x([0-9A-Fa-f]+),type=lab$'
)


def parse_address(value: str) -> int:
    return int(value.removeprefix("$"), 16)


def parse_debug_symbols(text: str) -> dict[str, dict[str, int]]:
    symbols: dict[str, dict[str, int]] = {}
    for line in text.splitlines():
        match = SYMBOL_PATTERN.match(line)
        if match is None:
            continue
        references = re.search(r",ref=([^,]+)", line)
        symbols[match.group(1)] = {
            "address": int(match.group(2), 16),
            "references": 0 if references is None else len(references.group(1).split("+")),
        }
    return symbols


def find_word_occurrences(data: bytes, address: int, base: int = 0x8000) -> list[int]:
    encoded = address.to_bytes(2, "little")
    return [
        base + offset
        for offset in range(len(data) - 1)
        if data[offset:offset + 2] == encoded
    ]


def audit_entry(
    entry: dict[str, Any], symbols: dict[str, dict[str, int]], prg: bytes
) -> tuple[dict[str, Any], list[str]]:
    errors: list[str] = []
    label = entry["label"]
    symbol = symbols.get(label)
    expected_address = parse_address(entry["expected_address"])
    if symbol is None:
        errors.append(f"missing debug symbol: {label}")
        actual_address = None
        reference_count = None
    else:
        actual_address = symbol["address"]
        reference_count = symbol["references"]
        if actual_address != expected_address:
            errors.append(
                f"{label} address differs: expected=${expected_address:04X}, "
                f"actual=${actual_address:04X}"
            )
        if reference_count != entry["expected_symbol_references"]:
            errors.append(
                f"{label} symbolic reference count differs: "
                f"expected={entry['expected_symbol_references']}, actual={reference_count}"
            )

    occurrences = find_word_occurrences(prg, expected_address)
    if len(occurrences) != entry["expected_address_occurrences"]:
        locations = ", ".join(f"${address:04X}" for address in occurrences) or "none"
        errors.append(
            f"{label} raw address occurrence count differs: "
            f"expected={entry['expected_address_occurrences']}, "
            f"actual={len(occurrences)} ({locations})"
        )

    terminator = entry["predecessor_terminator"]
    terminator_address = parse_address(terminator["address"])
    expected_bytes = bytes.fromhex(terminator["bytes"])
    start = terminator_address - 0x8000
    actual_bytes = prg[start:start + len(expected_bytes)]
    if actual_bytes != expected_bytes:
        errors.append(
            f"{label} predecessor terminator differs: "
            f"expected={expected_bytes.hex()}, actual={actual_bytes.hex()}"
        )
    if terminator_address + len(expected_bytes) != expected_address:
        errors.append(f"{label} predecessor does not end at the residual entry")

    report = {
        "id": entry["id"],
        "label": label,
        "address": None if actual_address is None else f"${actual_address:04X}",
        "symbol_references": reference_count,
        "address_occurrences": [f"${address:04X}" for address in occurrences],
        "predecessor_terminator": terminator["instruction"],
        "status": "passed" if not errors else "failed",
    }
    return report, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--debug", required=True, type=Path)
    parser.add_argument("--prg", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    symbols = parse_debug_symbols(args.debug.read_text(encoding="utf-8"))
    prg = args.prg.read_bytes()
    reports: list[dict[str, Any]] = []
    errors: list[str] = []
    for entry in manifest["entries"]:
        report, entry_errors = audit_entry(entry, symbols, prg)
        reports.append(report)
        errors.extend(entry_errors)

    document = {
        "format": manifest["format"],
        "profile": manifest["profile"],
        "entries": reports,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        print(f"[FAIL] Unreachable-code audit found {len(errors)} error(s)")
        return 1
    print(f"[OK] Proved {len(reports)} residual code entry unreachable")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
