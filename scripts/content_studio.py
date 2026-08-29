#!/usr/bin/env python3
"""Export, validate, and build ignored authored-content workspaces."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any

from content_profiles import load_profiles, require_supported
from data_formats import CODECS, load_labels
from platform_profiles import FdsFileRecord, parse_fds_side


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def parse_named_paths(values: list[str] | None) -> dict[str, Path]:
    paths: dict[str, Path] = {}
    for value in values or []:
        name, separator, path = value.partition("=")
        if (
            not separator
            or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", name)
            or not path
        ):
            raise ValueError(f"invalid named path: {value}")
        if name in {"prg", "chr"} or name in paths:
            raise ValueError(f"duplicate or reserved payload name: {name}")
        paths[name] = Path(path)
    return paths


def merge_labels(primary: Path, additional: dict[str, Path]) -> dict[str, int]:
    labels = load_labels(primary)
    for payload_id, path in additional.items():
        for name, address in load_labels(path).items():
            previous = labels.get(name)
            if previous is not None and previous != address:
                raise ValueError(
                    f"conflicting label {name} in payload {payload_id}: "
                    f"0x{previous:04x} != 0x{address:04x}"
                )
            labels[name] = address
    return labels


def load_named_payloads(
    paths: dict[str, Path], profile: dict[str, Any]
) -> dict[str, bytes]:
    contracts = profile.get("payloads", {})
    payloads = {}
    for payload_id, path in paths.items():
        contract = contracts.get(payload_id)
        if not isinstance(contract, dict):
            raise ValueError(f"missing payload contract: {payload_id}")
        data = path.read_bytes()
        if len(data) != int(contract["size"]):
            raise ValueError(f"content payload size mismatch: {payload_id}")
        if sha1(data) != contract["sha1"]:
            raise ValueError(f"content payload hash mismatch: {payload_id}")
        payloads[payload_id] = data
    return payloads


def fds_record_data(image: bytes, record_ids: list[int]) -> bytes:
    records = parse_fds_side(image)
    parts = []
    for file_id in record_ids:
        matches = [record for record in records if record.file_id == file_id]
        if len(matches) != 1:
            raise ValueError(f"FDS file ID is not unique: {file_id}")
        record = matches[0]
        parts.append(image[record.data_offset : record.data_offset + record.size])
    return b"".join(parts)


def load_profile_chr(source: Path, profile: dict[str, Any] | None = None) -> bytes:
    data = source.read_bytes()
    if (profile or {}).get("chr_source") != "fds_records":
        return data
    expected_template = profile.get("template_sha1")
    if expected_template is not None and sha1(data) != expected_template:
        raise ValueError(f"FDS CHR source template mismatch for {profile['id']}")
    return fds_record_data(data, [int(value) for value in profile["chr_record_ids"]])


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


def atomic_write_bytes(path: Path, value: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def load_format_manifest(path: Path) -> dict[str, Any]:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("format") != 1:
        raise ValueError("unsupported content format manifest schema")
    if "base_manifest" not in document:
        return document
    base_path = path.parent / document["base_manifest"]
    base = json.loads(base_path.read_text(encoding="utf-8"))
    if base.get("format") != 1:
        raise ValueError("unsupported base data format manifest schema")
    excluded = set(document.get("excluded_artifacts", []))
    artifacts = [entry for entry in base["artifacts"] if entry["id"] not in excluded]
    artifacts.extend(document.get("artifacts", []))
    return {"format": 1, "artifacts": artifacts}


def load_configuration(
    format_path: Path,
    studio_path: Path,
) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    formats = load_format_manifest(format_path)
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
    load_address: int = 0x8000,
) -> tuple[int, int]:
    def address(value: str | int) -> int:
        if isinstance(value, int):
            return value
        try:
            return labels[value]
        except KeyError as exc:
            raise ValueError(f"missing data boundary symbol: {value}") from exc

    try:
        start_cpu = address(entry["start"])
        end_cpu = address(entry["end"])
    except KeyError as exc:
        raise ValueError(f"missing data boundary: {exc.args[0]}") from exc
    start = start_cpu - load_address
    end = end_cpu - load_address
    if not (0 <= start < end <= prg_size):
        raise ValueError(f"invalid range for {entry['id']}: {start_cpu:04x}-{end_cpu:04x}")
    return start, end


def resolve_entry(entry: dict[str, Any], labels: dict[str, int]) -> dict[str, Any]:
    if entry["codec"] != "stream_collection" or "streams" in entry:
        return entry
    resolved = dict(entry)
    boundaries = list(entry["stream_boundaries"])
    streams = []
    for name, start_name, end_name in zip(
        entry["stream_names"], boundaries, boundaries[1:]
    ):
        start = labels[start_name] if isinstance(start_name, str) else int(start_name)
        end = labels[end_name] if isinstance(end_name, str) else int(end_name)
        capacity = end - start
        if capacity <= 0:
            raise ValueError(f"invalid stream boundary order: {start_name}, {end_name}")
        streams.append({"name": name, "capacity": capacity})
    resolved["streams"] = streams
    return resolved


def stream_end(data: bytes, start: int, codec: str, limit: int) -> int:
    position = start
    if codec == "area_object_stream":
        position += 2
        while position <= limit:
            if data[position] == 0xFD:
                return position
            position += 2
    elif codec == "enemy_object_stream":
        while position <= limit:
            first = data[position]
            if first == 0xFF:
                return position
            position += 3 if first & 0x0F == 0x0E else 2
    else:
        raise ValueError(f"unsupported external stream codec: {codec}")
    raise ValueError(f"stream at CHR offset 0x{start:04x} lacks a terminator")


def group_names(groups: list[list[Any]]) -> list[str]:
    names = []
    for group in groups:
        if len(group) != 2 or not isinstance(group[0], str):
            raise ValueError("invalid external stream group")
        count = int(group[1])
        if count <= 0:
            raise ValueError("external stream group must be nonempty")
        names.extend(f"{group[0]}_{index}" for index in range(1, count + 1))
    return names


def resolve_profile_selection(
    selection: list[tuple[str, dict[str, Any]]],
    profile: dict[str, Any],
    labels: dict[str, int],
    payloads: dict[str, bytes],
) -> list[tuple[str, dict[str, Any]]]:
    overrides = profile.get("artifact_overrides", {})
    load_address = int(profile["baseline"]["load_address"], 0)
    payload_contracts = profile.get("payloads", {})
    resolved_selection = []
    for studio_id, original in selection:
        entry = dict(original)
        override = overrides.get(entry["id"], {})
        entry.update({
            key: value for key, value in override.items()
            if key not in {"pointer_table", "groups", "bank_offset"}
        })
        payload_id = str(override.get("payload", "prg"))
        entry["_payload"] = payload_id
        if payload_id == "prg":
            payload_load_address = load_address
        elif payload_id == "chr":
            payload_load_address = 0
        else:
            contract = payload_contracts.get(payload_id)
            if not isinstance(contract, dict) or "load_address" not in contract:
                raise ValueError(f"missing payload contract: {payload_id}")
            payload_load_address = int(str(contract["load_address"]), 0)
        if payload_id not in payloads:
            raise ValueError(f"content payload is unavailable: {payload_id}")
        entry["_load_address"] = payload_load_address
        if "pointer_table" in override:
            if payload_id != "chr" or entry["codec"] != "stream_collection":
                raise ValueError(f"invalid external stream payload: {entry['id']}")
            names = group_names(override["groups"])
            table_address = labels.get(override["pointer_table"])
            if table_address is None:
                raise ValueError(
                    f"missing external pointer table: {override['pointer_table']}"
                )
            table_offset = table_address - load_address
            prg = payloads["prg"]
            table_end = table_offset + len(names) * 2
            if not 0 <= table_offset < table_end <= len(prg):
                raise ValueError(f"external pointer table is outside PRG: {entry['id']}")
            pointers = [
                prg[table_offset + index * 2]
                | (prg[table_offset + index * 2 + 1] << 8)
                for index in range(len(names))
            ]
            if len(set(pointers)) != len(pointers):
                raise ValueError(f"external stream pointers are not unique: {entry['id']}")
            bank_offset = int(override["bank_offset"])
            chr_data = payloads["chr"]
            ordered = sorted(
                (bank_offset + pointer, name)
                for pointer, name in zip(pointers, names)
            )
            boundaries = [offset for offset, _name in ordered]
            for index, (start, _name) in enumerate(ordered):
                limit = (
                    ordered[index + 1][0]
                    if index + 1 < len(ordered)
                    else len(chr_data) - 1
                )
                end = stream_end(chr_data, start, entry["stream_codec"], limit)
                if index + 1 < len(ordered) and end > limit:
                    raise ValueError(f"external streams overlap: {entry['id']}")
            boundaries.append(end + 1)
            entry["start"] = boundaries[0]
            entry["end"] = boundaries[-1]
            entry["stream_names"] = [name for _offset, name in ordered]
            entry["stream_boundaries"] = boundaries
            entry["source"] = (
                f"{profile['id']} CHR via {override['pointer_table']}"
            )
        resolved_selection.append((studio_id, resolve_entry(entry, labels)))
    return resolved_selection


def encode_workspace_document(
    document: dict[str, Any],
    entry: dict[str, Any],
    capacity: int,
    profile_id: str | None = None,
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
    if profile_id is not None and document.get("profile") != profile_id:
        raise ValueError(
            f"{entry['id']}: protected field profile must remain {profile_id!r}"
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
    payloads: dict[str, bytes],
    candidates: dict[str, bytearray] | None,
    profile_id: str = "ju",
    load_address: int = 0x8000,
) -> list[dict[str, Any]]:
    report: list[dict[str, Any]] = []
    for studio_id, entry in selection:
        entry = resolve_entry(entry, labels)
        payload_id = entry.get("_payload", "prg")
        baseline = payloads[payload_id]
        entry_load_address = int(entry.get("_load_address", load_address))
        start, end = artifact_range(
            entry, labels, len(baseline), entry_load_address
        )
        path = workspace / studio_id / f"{entry['id']}.json"
        if not path.is_file():
            raise ValueError(f"workspace artifact not found: {path}")
        document = json.loads(path.read_text(encoding="utf-8"))
        encoded = encode_workspace_document(
            document, entry, end - start, profile_id
        )
        original = baseline[start:end]
        changed_offsets = [
            offset
            for offset, (left, right) in enumerate(zip(original, encoded))
            if left != right
        ]
        if candidates is not None:
            candidates[payload_id][start:end] = encoded
        report.append(
            {
                "studio": studio_id,
                "profile": profile_id,
                "artifact_id": entry["id"],
                "capacity_bytes": end - start,
                "changed_bytes": len(changed_offsets),
                "first_changed_cpu_address": (
                    f"0x{entry_load_address + start + changed_offsets[0]:04x}"
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


def write_workspace_documents(
    workspace: Path,
    selection: list[tuple[str, dict[str, Any]]],
    labels: dict[str, int],
    payloads: dict[str, bytes],
    overwrite: bool,
    profile_id: str = "ju",
    load_address: int = 0x8000,
) -> None:
    for studio_id, entry in selection:
        entry = resolve_entry(entry, labels)
        payload_id = entry.get("_payload", "prg")
        baseline = payloads[payload_id]
        entry_load_address = int(entry.get("_load_address", load_address))
        start, end = artifact_range(
            entry, labels, len(baseline), entry_load_address
        )
        path = workspace / studio_id / f"{entry['id']}.json"
        if path.exists() and not overwrite:
            print(f"[OK] Kept existing {path}")
            continue
        decode = CODECS[entry["codec"]][0]
        document = {
            "schema_version": 1,
            "profile": profile_id,
            "studio": studio_id,
            "artifact_id": entry["id"],
            "codec": entry["codec"],
            "source": entry["source"],
            "cpu_range": [
                f"0x{entry_load_address + start:04x}",
                f"0x{entry_load_address + end - 1:04x}",
            ],
            "capacity_bytes": end - start,
            "original_sha1": sha1(baseline[start:end]),
            "data": decode(baseline[start:end], entry),
        }
        atomic_write_json(path, document)
        print(f"[OK] {'Exported' if overwrite else 'Initialized'} {path}")


def initialize_chr_workspace(
    workspace: Path,
    source: Path | None,
    selection: list[tuple[str, dict[str, Any]]],
    overwrite: bool,
    profile: dict[str, Any] | None = None,
) -> None:
    if source is None or not any(studio_id == "graphics" for studio_id, _ in selection):
        return
    data = load_profile_chr(source, profile)
    layout = (profile or {}).get("chr_layout", {})
    source_size = int(layout.get("source_size", 8192))
    editable_offset = int(layout.get("editable_offset", 0))
    editable_size = int(layout.get("editable_size", 8192))
    if len(data) != source_size:
        raise ValueError(f"CHR source must be exactly {source_size} bytes, got {len(data)}")
    expected_sha1 = (profile or {}).get("chr_sha1")
    if expected_sha1 is not None and sha1(data) != expected_sha1:
        raise ValueError(f"CHR source hash mismatch for {profile['id']}")
    if not 0 <= editable_offset < editable_offset + editable_size <= len(data):
        raise ValueError("editable CHR range is outside the source")
    destination = workspace / "graphics" / "smb.chr"
    if destination.exists() and not overwrite:
        print(f"[OK] Kept existing {destination}")
        return
    atomic_write_bytes(
        destination, data[editable_offset : editable_offset + editable_size]
    )
    print(f"[OK] {'Exported' if overwrite else 'Initialized'} {destination}")


def load_workspace_chr(
    workspace: Path,
    source: Path,
    profile: dict[str, Any] | None = None,
) -> tuple[bytes, int]:
    baseline = load_profile_chr(source, profile)
    layout = (profile or {}).get("chr_layout", {})
    source_size = int(layout.get("source_size", 8192))
    editable_offset = int(layout.get("editable_offset", 0))
    editable_size = int(layout.get("editable_size", 8192))
    if len(baseline) != source_size:
        raise ValueError(f"CHR source must be exactly {source_size} bytes, got {len(baseline)}")
    expected_sha1 = (profile or {}).get("chr_sha1")
    if expected_sha1 is not None and sha1(baseline) != expected_sha1:
        raise ValueError(f"CHR source hash mismatch for {profile['id']}")
    if not 0 <= editable_offset < editable_offset + editable_size <= len(baseline):
        raise ValueError("editable CHR range is outside the source")
    path = workspace / "graphics" / "smb.chr"
    editable_baseline = baseline[editable_offset : editable_offset + editable_size]
    editable = path.read_bytes() if path.exists() else editable_baseline
    if len(editable) != editable_size:
        raise ValueError(f"Workspace CHR must be exactly {editable_size} bytes")
    changed = sum(left != right for left, right in zip(editable_baseline, editable))
    candidate = bytearray(baseline)
    candidate[editable_offset : editable_offset + editable_size] = editable
    print(f"[OK] graphics/smb.chr: {len(editable)} bytes, {changed} changed")
    return bytes(candidate), changed


def validate_unmodified_image(
    profile: dict[str, Any], image: bytes, changed_bytes: int
) -> None:
    if changed_bytes:
        return
    if len(image) != int(profile["image_size"]):
        raise ValueError(
            f"unmodified {profile['id']} image size differs: {len(image)}"
        )
    digest = sha1(image)
    if digest != profile["image_sha1"]:
        raise ValueError(
            f"unmodified {profile['id']} image SHA1 differs: {digest}"
        )
    print(f"[OK] Unmodified {profile['id']} image matches its profile baseline")


def replace_fds_records(
    image: bytearray,
    records: list[FdsFileRecord],
    record_ids: list[int],
    data: bytes,
    *,
    require_empty: bool = False,
) -> None:
    selected = []
    for file_id in record_ids:
        matches = [record for record in records if record.file_id == file_id]
        if len(matches) != 1:
            raise ValueError(f"FDS file ID is not unique: {file_id}")
        selected.append(matches[0])
    if sum(record.size for record in selected) != len(data):
        raise ValueError("FDS record sizes do not cover authored payload")
    position = 0
    for record in selected:
        end = record.data_offset + record.size
        if require_empty and any(image[record.data_offset:end]):
            raise ValueError(f"FDS template program record is not empty: {record.file_id}")
        image[record.data_offset:end] = data[position : position + record.size]
        position += record.size


def compose_profile_image(
    profile: dict[str, Any],
    program: bytes,
    chr_data: bytes,
    *,
    payloads: dict[str, bytes] | None = None,
    header: bytes | None = None,
    extra: bytes = b"",
    template: bytes | None = None,
) -> bytes:
    container = profile.get("container")
    if container is None:
        container = "ines" if profile["baseline"]["kind"] == "revision" else "fds"
    if container == "ines":
        if header is None:
            raise ValueError("cartridge content build requires an iNES header")
        expected_header = profile.get("header_sha1")
        if expected_header is not None and sha1(header) != expected_header:
            raise ValueError(f"iNES header hash mismatch for {profile['id']}")
        return header + program + chr_data + extra
    if container != "fds":
        raise ValueError(f"unsupported content container: {container}")
    if template is None:
        raise ValueError("FDS content build requires a private disk template")
    if sha1(template) != profile["template_sha1"]:
        raise ValueError(f"FDS template hash mismatch for {profile['id']}")
    image = bytearray(template)
    records = parse_fds_side(template)
    chr_record_ids = [int(value) for value in profile["chr_record_ids"]]
    chr_records = []
    for file_id in chr_record_ids:
        matches = [record for record in records if record.file_id == file_id]
        if len(matches) != 1:
            raise ValueError(f"FDS file ID is not unique: {file_id}")
        chr_records.append(matches[0])
    template_chr = b"".join(
        template[record.data_offset : record.data_offset + record.size]
        for record in chr_records
    )
    if sha1(template_chr) != profile["chr_sha1"]:
        raise ValueError(f"FDS CHR baseline mismatch for {profile['id']}")
    program_data = {"prg": program}
    program_data.update(payloads or {})
    program_payloads = profile.get("program_payloads")
    if program_payloads is None:
        program_payloads = [{
            "payload": "prg",
            "record_ids": profile["program_record_ids"],
        }]
    for specification in program_payloads:
        payload_id = specification["payload"]
        if payload_id not in program_data:
            raise ValueError(f"FDS program payload is unavailable: {payload_id}")
        replace_fds_records(
            image,
            records,
            [int(value) for value in specification["record_ids"]],
            program_data[payload_id],
            require_empty=True,
        )
    replace_fds_records(
        image,
        records,
        chr_record_ids,
        chr_data,
    )
    return bytes(image)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("init", "export", "validate", "build"))
    parser.add_argument("--formats", required=True, type=Path)
    parser.add_argument("--studios", required=True, type=Path)
    parser.add_argument("--profiles", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--prg", required=True, type=Path)
    parser.add_argument("--payload", action="append")
    parser.add_argument("--payload-labels", action="append")
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--studio", action="append", dest="selected")
    parser.add_argument("--header", type=Path)
    parser.add_argument("--chr", type=Path)
    parser.add_argument("--extra", type=Path)
    parser.add_argument("--template", type=Path)
    parser.add_argument("--output-prg", type=Path)
    parser.add_argument("--output-rom", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        entries, profiles = load_configuration(args.formats, args.studios)
        selection = selected_entries(entries, profiles, args.selected)
        profile_document = load_profiles(args.profiles)
        authoring_profile = require_supported(profile_document, args.profile)
        for studio_id, _entry in selection:
            require_supported(profile_document, args.profile, studio_id)
        load_address = int(authoring_profile["baseline"]["load_address"], 0)
        payload_paths = parse_named_paths(args.payload)
        label_paths = parse_named_paths(args.payload_labels)
        if set(label_paths) - set(payload_paths):
            raise ValueError("payload labels require a matching content payload")
        labels = merge_labels(args.labels, label_paths)
        baseline_prg = args.prg.read_bytes()
        baseline_chr = (
            load_profile_chr(args.chr, authoring_profile) if args.chr else b""
        )
        payloads = {"prg": baseline_prg, "chr": baseline_chr}
        payloads.update(load_named_payloads(payload_paths, authoring_profile))
        selection = resolve_profile_selection(
            selection, authoring_profile, labels, payloads
        )
        if args.command in {"init", "export"}:
            overwrite = args.command == "export"
            write_workspace_documents(
                args.workspace,
                selection,
                labels,
                payloads,
                overwrite,
                args.profile,
                load_address,
            )
            initialize_chr_workspace(
                args.workspace,
                args.chr,
                selection,
                overwrite,
                authoring_profile,
            )
            return 0
        workspace_chr = None
        chr_changed = 0
        if args.chr:
            workspace_chr, chr_changed = load_workspace_chr(
                args.workspace, args.chr, authoring_profile
            )
        candidates = None
        if args.command == "build":
            candidates = {name: bytearray(data) for name, data in payloads.items()}
            candidates["chr"] = bytearray(workspace_chr)
        report = process_workspace(
            args.workspace,
            selection,
            labels,
            payloads,
            candidates,
            args.profile,
            load_address,
        )
        if args.report:
            atomic_write_json(
                args.report,
                {
                    "schema_version": 1,
                    "profile": args.profile,
                    "artifacts": report,
                },
            )
        if args.command == "validate":
            return 0
        if not all((args.chr, args.output_prg, args.output_rom)):
            raise ValueError("build requires CHR, PRG output, and image output")
        output_prg = bytes(candidates["prg"])
        chr_data = bytes(candidates["chr"])
        args.output_prg.parent.mkdir(parents=True, exist_ok=True)
        args.output_rom.parent.mkdir(parents=True, exist_ok=True)
        args.output_prg.write_bytes(output_prg)
        extra = args.extra.read_bytes() if args.extra else b""
        output_image = compose_profile_image(
            authoring_profile,
            output_prg,
            chr_data,
            payloads={
                name: bytes(data)
                for name, data in candidates.items()
                if name not in {"prg", "chr"}
            },
            header=args.header.read_bytes() if args.header else None,
            extra=extra,
            template=args.template.read_bytes() if args.template else None,
        )
        changed_artifacts = sum(item["changed_bytes"] for item in report)
        validate_unmodified_image(
            authoring_profile, output_image, changed_artifacts + chr_changed
        )
        args.output_rom.write_bytes(output_image)
        print(
            f"[OK] Content build: {changed_artifacts} changed artifact bytes, "
            f"image SHA1 {sha1(output_image)}"
        )
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
