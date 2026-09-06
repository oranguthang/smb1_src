#!/usr/bin/env python3
"""Validate the machine-readable relationships in the SMB1 scoring contract."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


EXPECTED_SCENARIOS = [
    "coin-award",
    "coin-extra-life",
    "decimal-score-carry",
    "enemy-stomp-award",
    "stomp-chain-award",
    "flagpole-award",
]
TRANSACTION_RE = re.compile(
    r"^source=(?P<source>[^;]+);score=(?P<before>[0-9]+)>(?P<after>[0-9]+);"
    r"coins=[0-9A-F]{2}>[0-9A-F]{2};lives=[0-9A-F]{2}>[0-9A-F]{2};"
    r"coin_display=[0-9]+>[0-9]+$"
)
HUD_RE = re.compile(
    r"^source=(?P<source>[^;]+);score=(?P<score>[0-9]+);tiles=(?P<tiles>[0-9A-F]{12})$"
)
TOP_RE = re.compile(
    r"^source=(?P<source>[^;]+);top=(?P<before>[0-9]+)>(?P<after>[0-9]+)$"
)


def validate_contract(document: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    scenarios = document.get("scenarios", [])
    identifiers = [scenario.get("id") for scenario in scenarios]
    if identifiers != EXPECTED_SCENARIOS:
        return ["scoring scenario order or identity differs"]

    for scenario in scenarios:
        identifier = scenario["id"]
        details = scenario.get("expected_event_details", {})
        transaction = TRANSACTION_RE.fullmatch(details.get("score_transaction", ""))
        hud = HUD_RE.fullmatch(details.get("score_hud_packet", ""))
        top = TOP_RE.fullmatch(details.get("top_score_update", ""))
        if transaction is None or hud is None or top is None:
            errors.append(f"{identifier} lacks a complete scoring transaction")
            continue
        if len(transaction["before"]) != 6 or len(transaction["after"]) != 6:
            errors.append(f"{identifier} score width differs from six digits")
        if transaction["source"] != hud["source"] or hud["source"] != top["source"]:
            errors.append(f"{identifier} scoring sources disagree")
        if transaction["after"] != hud["score"] or hud["score"] != top["after"]:
            errors.append(f"{identifier} score, HUD, and top-score results disagree")
        if transaction["before"] != top["before"]:
            errors.append(f"{identifier} player and top-score baselines disagree")
        if transaction["before"] == transaction["after"]:
            errors.append(f"{identifier} does not change the score")

        declared_patches = scenario.get("patches", [])
        patch_keys = {
            (patch.get("address"), patch.get("reason")) for patch in declared_patches
        }
        if len(patch_keys) != len(declared_patches):
            errors.append(f"{identifier} contains duplicate controlled patches")
        controlled = identifier in {
            "coin-extra-life",
            "decimal-score-carry",
            "stomp-chain-award",
        }
        if controlled != bool(declared_patches):
            errors.append(f"{identifier} controlled-patch classification differs")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    errors = validate_contract(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        return 1
    print(f"[OK] Scoring contract: {len(EXPECTED_SCENARIOS)} scenarios")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
