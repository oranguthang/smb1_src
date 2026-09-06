#!/usr/bin/env python3
"""Normalize ld65 debug data and export semantic symbols for NES debuggers."""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path


RECORD_FIELD_RE = re.compile(r'(?:^|,)([a-z]+)=("(?:[^"]|"")*"|[^,]*)')
VICE_LABEL_RE = re.compile(r"^al ([0-9A-Fa-f]{6}) \.([A-Za-z_][A-Za-z0-9_]*)$")


def parse_record(line: str) -> tuple[str, dict[str, str]]:
    kind, separator, payload = line.partition("\t")
    if not separator:
        return kind, {}
    fields: dict[str, str] = {}
    for match in RECORD_FIELD_RE.finditer(payload.rstrip("\n")):
        value = match.group(2)
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1].replace('""', '"')
        fields[match.group(1)] = value
    return kind, fields


def normalize_dbg_for_ines(
    raw_path: Path,
    output_path: Path,
    linked_prg_path: Path,
    output_rom_path: Path,
    header_size: int = 16,
) -> None:
    """Retarget ld65 file offsets from the bare PRG to the final iNES image."""

    linked_names = {
        str(linked_prg_path),
        linked_prg_path.as_posix(),
        str(linked_prg_path.resolve()),
        linked_prg_path.resolve().as_posix(),
    }
    rewritten: list[str] = []
    segment_count = 0
    for line in raw_path.read_text(encoding="utf-8").splitlines(keepends=True):
        kind, fields = parse_record(line)
        if kind == "seg" and fields.get("oname") in linked_names:
            if "ooffs" not in fields:
                raise ValueError("ld65 segment record is missing ooffs")
            line = line.replace(
                f'oname="{fields["oname"]}"', f'oname="{output_rom_path}"'
            ).replace(
                f'ooffs={fields["ooffs"]}',
                f'ooffs={int(fields["ooffs"], 0) + header_size}',
            )
            segment_count += 1
        rewritten.append(line)
    if segment_count == 0:
        raise ValueError(f"No output segments for {linked_prg_path} in {raw_path}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("".join(rewritten), encoding="utf-8", newline="\n")


def load_vice_labels(path: Path) -> list[tuple[int, str]]:
    labels: list[tuple[int, str]] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = VICE_LABEL_RE.fullmatch(line)
        if match:
            labels.append((int(match.group(1), 16), match.group(2)))
        elif line.strip():
            raise ValueError(f"Unsupported label line {path}:{line_number}: {line}")
    return labels


def load_debug_symbols(path: Path) -> list[tuple[int, str, str]]:
    symbols: list[tuple[int, str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        kind, fields = parse_record(line)
        if kind != "sym" or "val" not in fields or "name" not in fields:
            continue
        symbols.append((int(fields["val"], 0), fields["name"], fields.get("type", "")))
    return symbols


def symbol_priority(name: str) -> tuple[int, int, str]:
    prefixes = (
        "sub_", "vec_", "handler_", "loc_", "bra_", "tbl_", "off_",
        "unused_", "ram_", "zp_",
    )
    profile_specific_ram = name.startswith(
        ("ram_ann_", "ram_fds_", "ram_vs_", "ram_pal_", "ram_pc10_")
    )
    for priority, prefix in enumerate(prefixes):
        if name.startswith(prefix):
            return priority, int(profile_specific_ram), name
    return len(prefixes), int(profile_specific_ram), name


def choose_unique_addresses(labels: list[tuple[int, str]]) -> list[tuple[int, str]]:
    by_address: dict[int, list[str]] = defaultdict(list)
    for address, name in labels:
        by_address[address].append(name)
    return [
        (address, min(names, key=symbol_priority))
        for address, names in sorted(by_address.items())
    ]


def write_fceux_nl(debug_path: Path, rom_path: Path, output_dir: Path) -> tuple[Path, Path]:
    symbols = load_debug_symbols(debug_path)
    rom_labels = [
        (address, name)
        for address, name, symbol_type in symbols
        if symbol_type == "lab" and 0x8000 <= address <= 0xFFFF
    ]
    ram_labels = [
        (address, name)
        for address, name, symbol_type in symbols
        if address < 0x8000
        and (name.startswith("ram_") or name.startswith("zp_"))
        and symbol_type in {"equ", "lab"}
    ]
    output_dir.mkdir(parents=True, exist_ok=True)
    rom_output = output_dir / f"{rom_path.name}.0.nl"
    ram_output = output_dir / f"{rom_path.name}.ram.nl"
    for output, selected in (
        (rom_output, choose_unique_addresses(rom_labels)),
        (ram_output, choose_unique_addresses(ram_labels)),
    ):
        output.write_text(
            "".join(f"${address:04X}#{name}#\n" for address, name in selected),
            encoding="utf-8",
            newline="\n",
        )
    return rom_output, ram_output


def validate_debug_artifacts(
    debug_path: Path,
    map_path: Path,
    labels_path: Path,
    rom_path: Path,
    non_ines_container: bool = False,
) -> dict[str, int]:
    counts: dict[str, int] = defaultdict(int)
    segment_offsets: dict[str, int] = {}
    files: dict[int, str] = {}
    lines: dict[int, tuple[int, int]] = {}
    symbols: dict[str, dict[str, str]] = {}
    for line in debug_path.read_text(encoding="utf-8").splitlines():
        kind, fields = parse_record(line)
        counts[kind] += 1
        if kind == "file" and {"id", "name"} <= fields.keys():
            files[int(fields["id"], 0)] = fields["name"]
        elif kind == "line" and {"id", "file", "line"} <= fields.keys():
            lines[int(fields["id"], 0)] = (int(fields["file"], 0), int(fields["line"], 0))
        elif kind == "sym" and "name" in fields:
            symbols[fields["name"]] = fields
        if kind == "seg" and Path(fields.get("oname", "")).name == rom_path.name:
            segment_offsets[fields["name"]] = int(fields["ooffs"], 0)

    if counts["file"] < 30 or counts["line"] == 0 or counts["span"] == 0:
        raise ValueError("Debug file lacks source-line mapping records")
    if counts["sym"] == 0:
        raise ValueError("Debug file lacks symbols")
    rom = rom_path.read_bytes()
    if not rom:
        raise ValueError(f"Debugger image is empty: {rom_path}")
    if not non_ines_container and (len(rom) < 16 or rom[:4] != b"NES\x1a"):
        raise ValueError(f"Debugger ROM is not valid iNES: {rom_path}")
    if not non_ines_container and (
        segment_offsets.get("PRG") != 16
        or segment_offsets.get("VECTORS") != 16 + 0x7FFA
    ):
        raise ValueError(f"Unexpected debugger segment offsets: {segment_offsets}")
    if non_ines_container and not {"PRG", "VECTORS"} <= segment_offsets.keys():
        raise ValueError(f"Debugger lacks program segment offsets: {segment_offsets}")
    map_text = map_path.read_text(encoding="utf-8")
    if "PRG" not in map_text or "VECTORS" not in map_text:
        raise ValueError("Map file lacks PRG or VECTORS segments")

    label_names = {name for _, name in load_vice_labels(labels_path)}
    required = {
        "vec_reset_handler",
        "vec_nmi_handler",
        "sub_oper_mode_execution_tree",
        "sub_update_player_movement",
        "sub_bump_block",
        "sub_give_one_coin",
        "handler_vertical_pipe_entry",
        "handler_flagpole_slide",
        "sub_sound_engine",
    }
    missing = sorted(required - label_names)
    if missing:
        raise ValueError(f"Required debugger symbols missing: {', '.join(missing)}")

    expected_sources = {
        "vec_reset_handler": "src/system/boot_and_frame.asm",
        "sub_oper_mode_execution_tree": "src/system/boot_and_frame.asm",
        "sub_update_player_movement": "src/game/player/physics.asm",
        "sub_bump_block": "src/game/objects/blocks.asm",
        "sub_give_one_coin": "src/game/objects/dynamic.asm",
        "sub_handle_pipe_entry": "src/game/collisions/player_background.asm",
        "sub_flagpole_routine": "src/game/objects/projectiles_and_interactions.asm",
        "sub_sound_engine": "src/audio/sound_effects.asm",
    }
    for symbol, expected_suffix in expected_sources.items():
        fields = symbols.get(symbol)
        if not fields or "def" not in fields:
            raise ValueError(f"Symbol lacks source definition: {symbol}")
        definition_id = int(fields["def"].split("+")[0], 0)
        if definition_id not in lines:
            raise ValueError(f"Definition line missing for symbol: {symbol}")
        file_id, source_line = lines[definition_id]
        source_name = files.get(file_id, "").replace("\\", "/")
        if not source_name.endswith(expected_suffix):
            raise ValueError(f"Unexpected source mapping for {symbol}: {source_name}:{source_line}")
        source_path = Path(files[file_id])
        if source_path.is_file():
            source_text = source_path.read_text(encoding="utf-8").splitlines()
            if not (1 <= source_line <= len(source_text)) or not source_text[source_line - 1].lstrip().startswith(f"{symbol}:"):
                raise ValueError(f"Stale source line for {symbol}: {source_path}:{source_line}")
    return dict(counts)


def resolve_debugger_config(debug_path: Path, config_path: Path) -> dict[str, list[dict[str, object]]]:
    addresses: dict[str, int] = {}
    for address, name, _ in load_debug_symbols(debug_path):
        addresses.setdefault(name, address)
    config = json.loads(config_path.read_text(encoding="utf-8"))
    if not isinstance(config, dict):
        raise ValueError(f"Debugger config must be an object: {config_path}")
    resolved: dict[str, list[dict[str, object]]] = {}
    for group, entries in config.items():
        if not isinstance(entries, list) or not entries:
            raise ValueError(f"Debugger group must be a non-empty list: {group}")
        resolved_entries: list[dict[str, object]] = []
        for entry in entries:
            if not isinstance(entry, dict) or not isinstance(entry.get("symbol"), str):
                raise ValueError(f"Invalid debugger entry in {group}: {entry!r}")
            symbol = entry["symbol"]
            if symbol not in addresses:
                raise ValueError(f"Unknown debugger symbol in {config_path}: {symbol}")
            resolved_entry = dict(entry)
            resolved_entry["address"] = addresses[symbol]
            resolved_entry["address_hex"] = f"${addresses[symbol]:04X}"
            resolved_entries.append(resolved_entry)
        resolved[group] = resolved_entries
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--debug", required=True, type=Path)
    parser.add_argument("--map", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--rom", required=True, type=Path)
    parser.add_argument("--fceux-output-dir", required=True, type=Path)
    parser.add_argument("--breakpoints", required=True, type=Path)
    parser.add_argument("--watches", required=True, type=Path)
    parser.add_argument("--summary", type=Path)
    parser.add_argument("--non-ines-container", action="store_true")
    args = parser.parse_args()

    counts = validate_debug_artifacts(
        args.debug,
        args.map,
        args.labels,
        args.rom,
        non_ines_container=args.non_ines_container,
    )
    rom_nl, ram_nl = write_fceux_nl(args.debug, args.rom, args.fceux_output_dir)
    summary = {
        "debug_file": str(args.debug),
        "map_file": str(args.map),
        "labels_file": str(args.labels),
        "fceux_rom_labels": str(rom_nl),
        "fceux_ram_labels": str(ram_nl),
        "records": counts,
        "breakpoint_groups": resolve_debugger_config(args.debug, args.breakpoints),
        "watch_groups": resolve_debugger_config(args.debug, args.watches),
    }
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"[OK] Debug artifacts: {counts.get('sym', 0)} symbols, {counts.get('file', 0)} files, {counts.get('line', 0)} source lines")
    print(f"[OK] FCEUX labels: {rom_nl}, {ram_nl}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
