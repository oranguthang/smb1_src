#!/usr/bin/env python3
"""Validate focused SMB1 runtime traces and controlled-patch boundaries."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


PATCH_RE = re.compile(r"^([0-9A-F]{4}):[0-9A-F]{2}>[0-9A-F]{2}:([a-z0-9_]+)$")
REQUIRED_COLUMNS = {
    "frame", "event", "detail", "mode", "task", "player_state",
    "player_status", "page", "x", "y", "x_speed", "y_speed", "coins",
    "lives", "world", "area",
}


def load_trace(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream))
    if not rows or not REQUIRED_COLUMNS.issubset(rows[0]):
        raise ValueError(f"Trace is empty or uses an obsolete schema: {path}")
    if rows[0]["event"] != "trace_start" or rows[-1]["event"] != "trace_end":
        raise ValueError(f"Trace did not complete cleanly: {path}")
    return rows


def validate_events(scenario: dict[str, object], rows: list[dict[str, str]]) -> None:
    observed: dict[str, int] = {}
    for row in rows:
        observed.setdefault(row["event"], int(row["frame"]))
    expected = scenario.get("expected_events", {})
    for event, frame in expected.items():  # type: ignore[union-attr]
        if observed.get(event) != frame:
            raise ValueError(
                f"Unexpected {event} frame for {scenario['id']}: "
                f"expected={frame}, observed={observed.get(event)}"
            )


def validate_patches(scenario: dict[str, object], rows: list[dict[str, str]]) -> None:
    declared = {
        (str(patch["address"])[1:].upper(), str(patch["reason"]))
        for patch in scenario.get("patches", [])  # type: ignore[union-attr]
    }
    observed: set[tuple[str, str]] = set()
    for row in rows:
        if row["event"] != "controlled_patch":
            continue
        match = PATCH_RE.fullmatch(row["detail"])
        if not match:
            raise ValueError(f"Malformed controlled patch: {row['detail']}")
        observed.add((match.group(1), match.group(2)))
    if observed != declared:
        raise ValueError(
            f"Controlled patch scope differs for {scenario['id']}: "
            f"declared={sorted(declared)}, observed={sorted(observed)}"
        )


def validate_final_state(scenario: dict[str, object], rows: list[dict[str, str]]) -> None:
    final = rows[-1]
    for field, expected in scenario.get("expected_final", {}).items():  # type: ignore[union-attr]
        if final.get(field) != expected:
            raise ValueError(
                f"Unexpected final {field} for {scenario['id']}: "
                f"expected={expected}, observed={final.get(field)}"
            )


def validate_forbidden_execution(
    scenario: dict[str, object],
    rows: list[dict[str, str]],
) -> None:
    executed = [row["detail"] for row in rows if row["event"] == "forbidden_execute"]
    if executed:
        raise ValueError(
            f"Forbidden execution in {scenario['id']}: {', '.join(executed)}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenarios", required=True, type=Path)
    parser.add_argument("--trace-dir", required=True, type=Path)
    args = parser.parse_args()

    document = json.loads(args.scenarios.read_text(encoding="utf-8"))
    for scenario in document["scenarios"]:
        rows = load_trace(args.trace_dir / f"{scenario['id']}.csv")
        validate_events(scenario, rows)
        validate_patches(scenario, rows)
        validate_final_state(scenario, rows)
        validate_forbidden_execution(scenario, rows)
        print(f"[OK] {scenario['id']}: {scenario['method']}")
    print(f"[OK] All {len(document['scenarios'])} runtime scenarios passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
