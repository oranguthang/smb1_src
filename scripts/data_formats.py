#!/usr/bin/env python3
"""Decode and byte-round-trip representative authored SMB1 data formats."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Callable


VICE_LABEL_RE = re.compile(r"^al ([0-9A-Fa-f]{6}) \.([A-Za-z_][A-Za-z0-9_]*)$")


def load_labels(path: Path) -> dict[str, int]:
    labels: dict[str, int] = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = VICE_LABEL_RE.fullmatch(line)
        if match:
            labels[match.group(2)] = int(match.group(1), 16)
        elif line.strip():
            raise ValueError(f"Unsupported label line {path}:{number}: {line}")
    return labels


def split_lengths(data: bytes, specifications: list[dict[str, Any]]) -> list[tuple[dict[str, Any], bytes]]:
    chunks: list[tuple[dict[str, Any], bytes]] = []
    offset = 0
    for specification in specifications:
        length = int(specification["length"])
        chunks.append((specification, data[offset:offset + length]))
        offset += length
    if offset != len(data):
        raise ValueError(f"Declared field lengths consume {offset} bytes, input has {len(data)}")
    return chunks


def decode_area_pointer_table(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    worlds = []
    offset = 0
    for world_number, length in enumerate(entry["world_lengths"], 1):
        pointers = []
        for value in data[offset:offset + length]:
            pointers.append({
                "area_type": (value >> 5) & 0x03,
                "area_index": value & 0x1F,
                "alternate_bit": bool(value & 0x80),
            })
        worlds.append({"world": world_number, "areas": pointers})
        offset += length
    if offset != len(data):
        raise ValueError("World lengths do not consume the area pointer table")
    return {"worlds": worlds}


def encode_area_pointer_table(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    output = bytearray()
    for world in value["worlds"]:
        for pointer in world["areas"]:
            output.append(
                (0x80 if pointer["alternate_bit"] else 0)
                | ((int(pointer["area_type"]) & 0x03) << 5)
                | (int(pointer["area_index"]) & 0x1F)
            )
    return bytes(output)


def decode_area_object_stream(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    if len(data) < 3 or data[-1] != 0xFD or (len(data) - 3) % 2:
        raise ValueError("Area stream must contain a two-byte header, pairs, and $FD")
    first, second = data[:2]
    objects = []
    for offset in range(2, len(data) - 1, 2):
        position, control = data[offset:offset + 2]
        objects.append({
            "column": position >> 4,
            "row": position & 0x0F,
            "page_advance": bool(control & 0x80),
            "object_control": control & 0x7F,
        })
    return {
        "header": {
            "timer_setting": first >> 6,
            "entrance_control": (first >> 3) & 0x07,
            "foreground_or_color": first & 0x07,
            "area_style": second >> 6,
            "background_scenery": (second >> 4) & 0x03,
            "terrain_control": second & 0x0F,
        },
        "objects": objects,
    }


def encode_area_object_stream(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    header = value["header"]
    output = bytearray([
        (int(header["timer_setting"]) << 6)
        | (int(header["entrance_control"]) << 3)
        | int(header["foreground_or_color"]),
        (int(header["area_style"]) << 6)
        | (int(header["background_scenery"]) << 4)
        | int(header["terrain_control"]),
    ])
    for item in value["objects"]:
        output.extend([
            (int(item["column"]) << 4) | int(item["row"]),
            (0x80 if item["page_advance"] else 0) | int(item["object_control"]),
        ])
    output.append(0xFD)
    return bytes(output)


def decode_enemy_object_stream(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    if not data or data[-1] != 0xFF:
        raise ValueError("Enemy stream must end in $FF")
    records = []
    offset = 0
    while offset < len(data) - 1:
        first = data[offset]
        size = 3 if first & 0x0F == 0x0E else 2
        if offset + size > len(data) - 1:
            raise ValueError("Truncated enemy-stream record")
        second = data[offset + 1]
        record: dict[str, Any] = {
            "kind": "entrance" if size == 3 else ("page" if first & 0x0F == 0x0F else "enemy"),
            "column": first >> 4,
            "row": first & 0x0F,
            "page_advance": bool(second & 0x80),
            "hard_mode": bool(second & 0x40),
            "object_or_page": second & 0x3F,
        }
        if size == 3:
            third = data[offset + 2]
            record["destination_world"] = third >> 5
            record["destination_page"] = third & 0x1F
        records.append(record)
        offset += size
    return {"records": records}


def encode_enemy_object_stream(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    output = bytearray()
    for record in value["records"]:
        output.extend([
            (int(record["column"]) << 4) | int(record["row"]),
            (0x80 if record["page_advance"] else 0)
            | (0x40 if record["hard_mode"] else 0)
            | int(record["object_or_page"]),
        ])
        if record["kind"] == "entrance":
            output.append(
                (int(record["destination_world"]) << 5)
                | int(record["destination_page"])
            )
    output.append(0xFF)
    return bytes(output)


def decode_fixed_records(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    size = int(entry["record_size"])
    if len(data) % size:
        raise ValueError(f"{entry['id']} length is not divisible by {size}")
    return {entry["record_name"] + "s": [list(data[i:i + size]) for i in range(0, len(data), size)]}


def encode_fixed_records(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    return bytes(item for record in value[entry["record_name"] + "s"] for item in record)


def decode_ppu_packets(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    terminator = int(entry["terminator"])
    packets = []
    offset = 0
    while offset < len(data) and data[offset] != terminator:
        if offset + 3 > len(data):
            raise ValueError("Truncated PPU packet header")
        address = (data[offset] << 8) | data[offset + 1]
        control = data[offset + 2]
        length = control & 0x3F
        repeat = bool(control & 0x40)
        payload_length = 1 if repeat else length
        payload = data[offset + 3:offset + 3 + payload_length]
        if len(payload) != payload_length:
            raise ValueError("Truncated PPU packet payload")
        packets.append({
            "address": address,
            "vertical": bool(control & 0x80),
            "repeat": repeat,
            "length": length,
            "values": list(payload),
        })
        offset += 3 + payload_length
    if offset != len(data) - 1 or data[offset] != terminator:
        raise ValueError("PPU packet block has trailing data or no terminator")
    return {"packets": packets}


def encode_ppu_packets(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    output = bytearray()
    for packet in value["packets"]:
        address = int(packet["address"])
        control = (
            (0x80 if packet["vertical"] else 0)
            | (0x40 if packet["repeat"] else 0)
            | int(packet["length"])
        )
        output.extend([address >> 8, address & 0xFF, control, *packet["values"]])
    output.append(int(entry["terminator"]))
    return bytes(output)


def decode_ppu_packet_blocks(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    terminator = int(entry["terminator"])
    blocks = []
    offset = 0
    for name in entry["block_names"]:
        packets = []
        while offset < len(data) and data[offset] != terminator:
            if offset + 3 > len(data):
                raise ValueError(f"Truncated PPU packet header in {name}")
            address = (data[offset] << 8) | data[offset + 1]
            control = data[offset + 2]
            length = control & 0x3F
            repeat = bool(control & 0x40)
            payload_length = 1 if repeat else length
            payload = data[offset + 3:offset + 3 + payload_length]
            if len(payload) != payload_length:
                raise ValueError(f"Truncated PPU packet payload in {name}")
            packets.append({
                "address": address,
                "vertical": bool(control & 0x80),
                "repeat": repeat,
                "length": length,
                "values": list(payload),
            })
            offset += 3 + payload_length
        if offset >= len(data):
            raise ValueError(f"PPU packet block {name} has no terminator")
        offset += 1
        blocks.append({"name": name, "packets": packets})
    if offset != len(data):
        raise ValueError("PPU packet collection has trailing data")
    return {"blocks": blocks}


def encode_ppu_packet_blocks(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    names = list(entry["block_names"])
    blocks = value["blocks"]
    if [block["name"] for block in blocks] != names:
        raise ValueError("PPU packet block names or order differ from the manifest")
    output = bytearray()
    for block in blocks:
        for packet in block["packets"]:
            address = int(packet["address"])
            control = (
                (0x80 if packet["vertical"] else 0)
                | (0x40 if packet["repeat"] else 0)
                | int(packet["length"])
            )
            output.extend([address >> 8, address & 0xFF, control, *packet["values"]])
        output.append(int(entry["terminator"]))
    return bytes(output)


def decode_music_header(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    if len(data) not in {5, 6}:
        raise ValueError("Music header must contain five or six bytes")
    return {
        "length_offset": data[0],
        "data_address": data[1] | (data[2] << 8),
        "triangle_offset": data[3],
        "square1_offset": data[4],
        "noise_offset": data[5] if len(data) == 6 else None,
    }


def encode_music_header(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    address = int(value["data_address"])
    output = bytearray([
        int(value["length_offset"]), address & 0xFF, address >> 8,
        int(value["triangle_offset"]), int(value["square1_offset"]),
    ])
    if value["noise_offset"] is not None:
        output.append(int(value["noise_offset"]))
    return bytes(output)


def decode_music_byte(byte: int, channel_format: str) -> dict[str, Any]:
    if channel_format in {"square2", "triangle"}:
        if byte == 0:
            return {"kind": "terminator", "value": 0}
        if byte & 0x80:
            return {"kind": "length", "unused": (byte >> 3) & 0x0F, "index": byte & 0x07}
        return {"kind": "note", "offset": byte & 0x7F}
    length_index = ((byte & 0x01) << 2) | (byte >> 6)
    if channel_format == "square1":
        return {"kind": "square1", "length_index": length_index, "note_offset": (byte >> 1) & 0x1F}
    return {"kind": "noise", "length_index": length_index, "beat": (byte >> 4) & 0x03, "unused": (byte >> 1) & 0x07}


def encode_music_byte(value: dict[str, Any], channel_format: str) -> int:
    kind = value["kind"]
    if kind == "terminator":
        return 0
    if kind == "length":
        return 0x80 | (int(value["unused"]) << 3) | int(value["index"])
    if kind == "note":
        return int(value["offset"])
    length_index = int(value["length_index"])
    length_bits = ((length_index & 0x03) << 6) | ((length_index >> 2) & 0x01)
    if channel_format == "square1":
        return length_bits | (int(value["note_offset"]) << 1)
    return length_bits | (int(value["beat"]) << 4) | (int(value["unused"]) << 1)


def decode_music_channels(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    channels = []
    for specification, chunk in split_lengths(data, entry["channels"]):
        channels.append({
            "name": specification["name"],
            "format": specification["format"],
            "events": [decode_music_byte(byte, specification["format"]) for byte in chunk],
        })
    return {"channels": channels}


def encode_music_channels(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    output = bytearray()
    for channel in value["channels"]:
        output.extend(encode_music_byte(event, channel["format"]) for event in channel["events"])
    return bytes(output)


def decode_apu_envelope(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    return {"steps": [
        {"duty": byte >> 6, "mode": (byte >> 4) & 0x03, "volume": byte & 0x0F}
        for byte in data
    ]}


def encode_apu_envelope(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    return bytes(
        (int(step["duty"]) << 6) | (int(step["mode"]) << 4) | int(step["volume"])
        for step in value["steps"]
    )


def decode_named_byte_tables(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    tables = []
    for specification, chunk in split_lengths(data, entry["tables"]):
        values = [byte - 256 if specification["signed"] and byte >= 128 else byte for byte in chunk]
        tables.append({"name": specification["name"], "signed": specification["signed"], "values": values})
    return {"tables": tables}


def encode_named_byte_tables(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    return bytes(int(item) & 0xFF for table in value["tables"] for item in table["values"])


def decode_raw_bytes(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    return {"values": list(data)}


def encode_raw_bytes(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    return bytes(int(item) for item in value["values"])


def decode_stream_collection(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    stream_codec = entry["stream_codec"]
    decode = CODECS[stream_codec][0]
    terminator = int(entry["stream_terminator"])
    streams = []
    offset = 0
    for specification in entry["streams"]:
        capacity = int(specification["capacity"])
        chunk = data[offset:offset + capacity]
        terminator_offset = None
        if stream_codec == "area_object_stream":
            for position in range(2, len(chunk), 2):
                if chunk[position] == terminator:
                    terminator_offset = position
                    break
        elif stream_codec == "enemy_object_stream":
            position = 0
            while position < len(chunk):
                if chunk[position] == terminator:
                    terminator_offset = position
                    break
                position += 3 if chunk[position] & 0x0F == 0x0E else 2
        else:
            try:
                terminator_offset = chunk.index(terminator)
            except ValueError:
                pass
        implicit_terminator = terminator_offset is None
        used = len(chunk) if implicit_terminator else terminator_offset + 1
        encoded_stream = chunk[:used] + (bytes([terminator]) if implicit_terminator else b"")
        stream_entry = {"id": specification["name"], "codec": stream_codec}
        streams.append({
            "name": specification["name"],
            "capacity_bytes": capacity,
            "implicit_terminator": implicit_terminator,
            "padding": [] if implicit_terminator else list(chunk[used:]),
            "data": decode(encoded_stream, stream_entry),
        })
        offset += capacity
    if offset != len(data):
        raise ValueError("Stream capacities do not consume the collection")
    return {"streams": streams}


def encode_stream_collection(value: dict[str, Any], entry: dict[str, Any]) -> bytes:
    stream_codec = entry["stream_codec"]
    encode = CODECS[stream_codec][1]
    output = bytearray()
    specifications = entry["streams"]
    streams = value["streams"]
    if [item["name"] for item in streams] != [item["name"] for item in specifications]:
        raise ValueError("Stream names or order differ from the manifest")
    for stream, specification in zip(streams, specifications):
        capacity = int(specification["capacity"])
        if int(stream["capacity_bytes"]) != capacity:
            raise ValueError(f"{stream['name']}: protected capacity changed")
        stream_entry = {"id": stream["name"], "codec": stream_codec}
        encoded = encode(stream["data"], stream_entry)
        implicit_terminator = bool(stream.get("implicit_terminator"))
        if implicit_terminator:
            if len(encoded) != capacity + 1 or encoded[-1] != int(entry["stream_terminator"]):
                raise ValueError(
                    f"{stream['name']}: a shared terminator requires exactly {capacity} data bytes"
                )
            output.extend(encoded[:-1])
            continue
        if len(encoded) > capacity:
            raise ValueError(
                f"{stream['name']}: encoded size {len(encoded)} exceeds {capacity}-byte capacity"
            )
        padding = bytes(int(item) for item in stream.get("padding", []))
        if len(encoded) + len(padding) > capacity:
            padding = padding[-(capacity - len(encoded)):] if len(encoded) < capacity else b""
        output.extend(encoded)
        output.extend(bytes(capacity - len(encoded) - len(padding)))
        output.extend(padding)
    return bytes(output)


CODECS: dict[str, tuple[Callable[[bytes, dict[str, Any]], dict[str, Any]], Callable[[dict[str, Any], dict[str, Any]], bytes]]] = {
    "area_pointer_table": (decode_area_pointer_table, encode_area_pointer_table),
    "area_object_stream": (decode_area_object_stream, encode_area_object_stream),
    "enemy_object_stream": (decode_enemy_object_stream, encode_enemy_object_stream),
    "fixed_records": (decode_fixed_records, encode_fixed_records),
    "ppu_packets": (decode_ppu_packets, encode_ppu_packets),
    "ppu_packet_blocks": (decode_ppu_packet_blocks, encode_ppu_packet_blocks),
    "music_header": (decode_music_header, encode_music_header),
    "music_channels": (decode_music_channels, encode_music_channels),
    "apu_envelope": (decode_apu_envelope, encode_apu_envelope),
    "named_byte_tables": (decode_named_byte_tables, encode_named_byte_tables),
    "raw_bytes": (decode_raw_bytes, encode_raw_bytes),
    "stream_collection": (decode_stream_collection, encode_stream_collection),
}


def roundtrip_artifact(data: bytes, entry: dict[str, Any]) -> dict[str, Any]:
    codec_name = entry["codec"]
    if codec_name not in CODECS:
        raise ValueError(f"Unknown data codec: {codec_name}")
    decode, encode = CODECS[codec_name]
    decoded = decode(data, entry)
    rebuilt = encode(decoded, entry)
    if rebuilt != data:
        difference = next(
            (index for index, pair in enumerate(zip(data, rebuilt)) if pair[0] != pair[1]),
            min(len(data), len(rebuilt)),
        )
        raise ValueError(f"{entry['id']} round trip differs at byte {difference}")
    return decoded


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--prg", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()

    document = json.loads(args.manifest.read_text(encoding="utf-8"))
    labels = load_labels(args.labels)
    prg = args.prg.read_bytes()
    summaries = []
    families: set[str] = set()
    for entry in document["artifacts"]:
        source = args.project_root / entry["source"]
        if not source.is_file():
            raise ValueError(f"Data source does not exist: {source}")
        try:
            start = labels[entry["start"]]
            end = labels[entry["end"]]
        except KeyError as exc:
            raise ValueError(f"Data boundary symbol is missing: {exc.args[0]}") from exc
        if not (0x8000 <= start < end <= 0x10000):
            raise ValueError(f"Invalid PRG data range for {entry['id']}: ${start:04X}-${end:04X}")
        data = prg[start - 0x8000:end - 0x8000]
        decoded = roundtrip_artifact(data, entry)
        families.add(entry["family"])
        summaries.append({
            "id": entry["id"], "family": entry["family"], "codec": entry["codec"],
            "source": entry["source"], "start": f"${start:04X}", "end": f"${end - 1:04X}",
            "size": len(data), "decoded": decoded,
        })
        print(f"[OK] {entry['id']}: {entry['codec']}, {len(data)} bytes")
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps({"format": 1, "artifacts": summaries}, indent=2) + "\n", encoding="utf-8")
    print(f"[OK] Round-tripped {len(summaries)} artifacts across {len(families)} format families")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
