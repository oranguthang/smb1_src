#!/usr/bin/env python3
"""Audit every supported enemy stream for residual object-range behavior"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from data_formats import decode_enemy_object_stream, load_labels


def number(value: Any) -> int:
    if isinstance(value, int):
        return value
    return int(str(value), 0)


def rooted(project_root: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else project_root / path


def read_stream(data: bytes, offset: int) -> bytes:
    if not 0 <= offset < len(data):
        raise ValueError(f"enemy stream offset is outside its artifact: {offset}")
    end = data.find(b"\xff", offset)
    if end < 0:
        raise ValueError(f"enemy stream at offset {offset} lacks an $FF terminator")
    return data[offset:end + 1]


def labeled_streams(
    project_root: Path,
    artifact: dict[str, Any],
) -> list[tuple[str, bytes]]:
    data = rooted(project_root, artifact["binary"]).read_bytes()
    labels = load_labels(rooted(project_root, artifact["labels"]))
    pattern = re.compile(artifact["label_pattern"])
    base = number(artifact["load_address"])
    matches = sorted(
        (address, name)
        for name, address in labels.items()
        if pattern.search(name)
    )
    return [
        (name, read_stream(data, address - base))
        for address, name in matches
    ]


def pointer_table_streams(
    project_root: Path,
    artifact: dict[str, Any],
) -> list[tuple[str, bytes]]:
    data = rooted(project_root, artifact["binary"]).read_bytes()
    pointer_data = rooted(project_root, artifact["pointer_binary"]).read_bytes()
    labels = load_labels(rooted(project_root, artifact["labels"]))
    pointer_label = artifact["pointer_label"]
    if pointer_label not in labels:
        raise ValueError(f"pointer table label is absent: {pointer_label}")
    table_offset = labels[pointer_label] - number(artifact["pointer_load_address"])
    count = int(artifact["pointer_count"])
    table = pointer_data[table_offset:table_offset + count * 2]
    if len(table) != count * 2:
        raise ValueError(f"pointer table is truncated: {pointer_label}")
    data_offset = number(artifact.get("data_offset", 0))
    return [
        (
            f"{pointer_label}[{index}]",
            read_stream(
                data,
                data_offset + int.from_bytes(table[index * 2:index * 2 + 2], "little"),
            ),
        )
        for index in range(count)
    ]


def audit_artifact(
    project_root: Path,
    artifact: dict[str, Any],
    forbidden_ids: set[int],
) -> dict[str, Any]:
    if artifact["kind"] == "labeled_streams":
        streams = labeled_streams(project_root, artifact)
    elif artifact["kind"] == "pointer_table":
        streams = pointer_table_streams(project_root, artifact)
    else:
        raise ValueError(f"unsupported enemy-stream artifact kind: {artifact['kind']}")
    records = 0
    forbidden: list[dict[str, Any]] = []
    for stream_name, data in streams:
        decoded = decode_enemy_object_stream(data, {})
        records += len(decoded["records"])
        for index, record in enumerate(decoded["records"]):
            identifier = int(record["object_or_page"])
            if record["kind"] != "entrance" and identifier in forbidden_ids:
                forbidden.append({
                    "stream": stream_name,
                    "record": index,
                    "kind": record["kind"],
                    "object_id": f"0x{identifier:02x}",
                })
    if len(streams) != int(artifact["expected_streams"]):
        raise ValueError(
            f"{artifact['id']} exposes {len(streams)} streams, "
            f"expected {artifact['expected_streams']}"
        )
    if records != int(artifact["expected_records"]):
        raise ValueError(
            f"{artifact['id']} exposes {records} records, "
            f"expected {artifact['expected_records']}"
        )
    return {
        "id": artifact["id"],
        "streams": len(streams),
        "records": records,
        "forbidden_records": forbidden,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_root = Path(__file__).resolve().parent.parent
    parser.add_argument("--project-root", type=Path, default=default_root)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve()
    manifest = json.loads(args.manifest.resolve().read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise SystemExit("[ERROR] Unsupported enemy-stream evidence schema")
    forbidden_ids = {number(value) for value in manifest["forbidden_object_ids"]}
    try:
        artifacts = [
            audit_artifact(root, artifact, forbidden_ids)
            for artifact in manifest["artifacts"]
        ]
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit(f"[ERROR] Enemy-stream audit failed: {error}") from error
    forbidden = [
        {"artifact": artifact["id"], **record}
        for artifact in artifacts
        for record in artifact["forbidden_records"]
    ]
    totals = {
        "streams": sum(artifact["streams"] for artifact in artifacts),
        "records": sum(artifact["records"] for artifact in artifacts),
    }
    if totals != manifest["expected_totals"]:
        raise SystemExit(
            f"[ERROR] Enemy-stream totals differ: got {totals}, "
            f"expected {manifest['expected_totals']}"
        )
    if forbidden:
        raise SystemExit(
            f"[ERROR] Enemy-stream audit found {len(forbidden)} forbidden record(s)"
        )
    report = {
        "schema_version": 1,
        "forbidden_object_ids": [f"0x{value:02x}" for value in sorted(forbidden_ids)],
        "totals": totals,
        "artifacts": artifacts,
    }
    output = rooted(root, str(args.output))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"[OK] Audited {totals['records']} records in {totals['streams']} "
        "supported enemy streams; no forbidden object IDs are reachable"
    )
    print(f"[OK] Enemy-stream evidence: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
