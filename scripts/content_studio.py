#!/usr/bin/env python3
"""Export, validate, and build ignored authored-content workspaces."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from pathlib import Path
from typing import Any

from data_formats import CODECS, load_labels


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def atomic_write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=path.parent,
        text=True,
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def load_configuration(
    format_path: Path,
    studio_path: Path,
) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    formats = json.loads(format_path.read_text(encoding="utf-8"))
    studios = json.loads(studio_path.read_text(encoding="utf-8"))
    if formats.get("format") != 1 or studios.get("schema_version") != 1:
        raise ValueError("unsupported content manifest schema")
    entries = {entry["id"]: entry for entry in formats["artifacts"]}
    profiles = {studio["id"]: studio for studio in studios["studios"]}
    referenced = {
        artifact_id
        for profile in profiles.values()
        for artifact_id in profile["artifacts"]
    }
    missing = referenced - set(entries)
    if missing:
        raise ValueError(f"studio manifest references unknown artifacts: {sorted(missing)}")
    return entries, profiles


def selected_entries(
    entries: dict[str, dict[str, Any]],
    profiles: dict[str, dict[str, Any]],
    selected: list[str] | None,
) -> list[tuple[str, dict[str, Any]]]:
    studio_ids = selected or list(profiles)
    unknown = set(studio_ids) - set(profiles)
    if unknown:
        raise ValueError(f"unknown studio: {', '.join(sorted(unknown))}")
    result: list[tuple[str, dict[str, Any]]] = []
    seen: set[str] = set()
    for studio_id in studio_ids:
        for artifact_id in profiles[studio_id]["artifacts"]:
            if artifact_id not in seen:
                result.append((studio_id, entries[artifact_id]))
                seen.add(artifact_id)
    return result


def artifact_range(
    entry: dict[str, Any],
    labels: dict[str, int],
    prg_size: int,
) -> tuple[int, int]:
    try:
        start_cpu = labels[entry["start"]]
        end_cpu = labels[entry["end"]]
    except KeyError as exc:
        raise ValueError(f"missing data boundary symbol: {exc.args[0]}") from exc
    start = start_cpu - 0x8000
    end = end_cpu - 0x8000
    if not (0 <= start < end <= prg_size):
        raise ValueError(f"invalid range for {entry['id']}: {start_cpu:04x}-{end_cpu:04x}")
    return start, end


def encode_workspace_document(
    document: dict[str, Any],
    entry: dict[str, Any],
    capacity: int,
) -> bytes:
    if document.get("schema_version") != 1:
        raise ValueError(f"{entry['id']}: unsupported workspace schema")
    for field, expected in (
        ("artifact_id", entry["id"]),
        ("codec", entry["codec"]),
        ("capacity_bytes", capacity),
    ):
        if document.get(field) != expected:
            raise ValueError(
                f"{entry['id']}: protected field {field} must remain {expected!r}"
            )
    codec_name = entry["codec"]
    decode, encode = CODECS[codec_name]
    encoded = encode(document["data"], entry)
    if len(encoded) != capacity:
        raise ValueError(
            f"{entry['id']}: encoded size {len(encoded)} exceeds or underfills "
            f"fixed capacity {capacity}"
        )
    canonical = decode(encoded, entry)
    if canonical != document["data"]:
        raise ValueError(f"{entry['id']}: values are outside the canonical codec domain")
    return encoded


def process_workspace(
    workspace: Path,
    selection: list[tuple[str, dict[str, Any]]],
    labels: dict[str, int],
    baseline: bytes,
    candidate: bytearray | None,
) -> list[dict[str, Any]]:
    report: list[dict[str, Any]] = []
    for studio_id, entry in selection:
        start, end = artifact_range(entry, labels, len(baseline))
        path = workspace / studio_id / f"{entry['id']}.json"
        if not path.is_file():
            raise ValueError(f"workspace artifact not found: {path}")
        document = json.loads(path.read_text(encoding="utf-8"))
        encoded = encode_workspace_document(document, entry, end - start)
        original = baseline[start:end]
        changed_offsets = [
            offset
            for offset, (left, right) in enumerate(zip(original, encoded))
            if left != right
        ]
        if candidate is not None:
            candidate[start:end] = encoded
        report.append(
            {
                "studio": studio_id,
                "artifact_id": entry["id"],
                "capacity_bytes": end - start,
                "changed_bytes": len(changed_offsets),
                "first_changed_cpu_address": (
                    f"0x{0x8000 + start + changed_offsets[0]:04x}"
                    if changed_offsets else None
                ),
                "encoded_sha1": sha1(encoded),
            }
        )
        print(
            f"[OK] {studio_id}/{entry['id']}: {end - start} bytes, "
            f"{len(changed_offsets)} changed"
        )
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("export", "validate", "build"))
    parser.add_argument("--formats", required=True, type=Path)
    parser.add_argument("--studios", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--prg", required=True, type=Path)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--studio", action="append", dest="selected")
    parser.add_argument("--header", type=Path)
    parser.add_argument("--chr", type=Path)
    parser.add_argument("--output-prg", type=Path)
    parser.add_argument("--output-rom", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        entries, profiles = load_configuration(args.formats, args.studios)
        selection = selected_entries(entries, profiles, args.selected)
        labels = load_labels(args.labels)
        baseline = args.prg.read_bytes()
        if args.command == "export":
            for studio_id, entry in selection:
                start, end = artifact_range(entry, labels, len(baseline))
                decode = CODECS[entry["codec"]][0]
                document = {
                    "schema_version": 1,
                    "studio": studio_id,
                    "artifact_id": entry["id"],
                    "codec": entry["codec"],
                    "source": entry["source"],
                    "cpu_range": [f"0x{0x8000 + start:04x}", f"0x{0x8000 + end - 1:04x}"],
                    "capacity_bytes": end - start,
                    "original_sha1": sha1(baseline[start:end]),
                    "data": decode(baseline[start:end], entry),
                }
                path = args.workspace / studio_id / f"{entry['id']}.json"
                atomic_write_json(path, document)
                print(f"[OK] Exported {path}")
            return 0
        candidate = bytearray(baseline) if args.command == "build" else None
        report = process_workspace(
            args.workspace, selection, labels, baseline, candidate
        )
        if args.report:
            atomic_write_json(args.report, {"schema_version": 1, "artifacts": report})
        if args.command == "validate":
            return 0
        if not all((args.header, args.chr, args.output_prg, args.output_rom)):
            raise ValueError("build requires header, CHR, PRG output, and ROM output")
        output_prg = bytes(candidate)
        header = args.header.read_bytes()
        chr_data = args.chr.read_bytes()
        args.output_prg.parent.mkdir(parents=True, exist_ok=True)
        args.output_rom.parent.mkdir(parents=True, exist_ok=True)
        args.output_prg.write_bytes(output_prg)
        args.output_rom.write_bytes(header + output_prg + chr_data)
        print(
            f"[OK] Content build: {sum(item['changed_bytes'] for item in report)} "
            f"changed PRG bytes, ROM SHA1 {sha1(header + output_prg + chr_data)}"
        )
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
