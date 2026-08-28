#!/usr/bin/env python3
"""Compare a reconstructed CPU-address range with a verified FDS payload"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from platform_profiles import extract_fds_payloads, load_profile


def parse_number(value: str) -> int:
    return int(value, 0)


def verify_range(
    payload: bytes,
    candidate: bytes,
    load_address: int,
    start: int,
    end: int,
) -> None:
    if start < load_address or end <= start or end - load_address > len(payload):
        raise ValueError("verified range is outside the reference payload")
    expected = payload[start - load_address : end - load_address]
    if len(candidate) != len(expected):
        raise ValueError(
            f"candidate size mismatch: expected {len(expected)}, got {len(candidate)}"
        )
    if candidate != expected:
        offset = next(
            index
            for index, (actual, wanted) in enumerate(zip(candidate, expected))
            if actual != wanted
        )
        address = start + offset
        raise ValueError(
            f"candidate differs at CPU ${address:04X}: "
            f"${candidate[offset]:02X} != ${expected[offset]:02X}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--load-address", required=True, type=parse_number)
    parser.add_argument("--start", required=True, type=parse_number)
    parser.add_argument("--end", required=True, type=parse_number)
    args = parser.parse_args()
    try:
        profile = load_profile(args.manifest, args.profile)
        if profile.get("format") != "fds_raw_side":
            raise ValueError("range verification currently requires an FDS profile")
        primary = profile.get("primary_payload")
        if not primary:
            raise ValueError("profile does not declare a primary payload")
        payloads = extract_fds_payloads(args.reference.read_bytes(), profile)
        verify_range(
            payloads[primary],
            args.candidate.read_bytes(),
            args.load_address,
            args.start,
            args.end,
        )
        digest = hashlib.sha1(args.candidate.read_bytes()).hexdigest()
        print(
            f"[OK] {args.profile}: ${args.start:04X}-${args.end:04X} "
            f"matches {primary} (SHA1 {digest})"
        )
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
