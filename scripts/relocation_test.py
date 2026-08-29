#!/usr/bin/env python3
"""Build and statically validate the canonical generated relocation candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from data_formats import load_labels
from platform_profiles import (
    find_fds_record,
    load_profile as load_platform_profile,
    parse_fds_side,
    split_ines_reference,
    validate_fds_reference,
)
from revision_profiles import load_profile, split_rom
from sound_studio_model import HEADER_NAMES, MusicBank


SYMBOL_PATTERN = re.compile(
    r'^sym\t.*name="([^"]+)".*val=0x([0-9A-Fa-f]+),type=lab$',
    re.MULTILINE,
)


def fail(message: str) -> None:
    raise ValueError(message)


def number(value: Any) -> int:
    if isinstance(value, int):
        return value
    return int(str(value), 0)


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def rooted(project_root: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else project_root / path


def replace_once(text: str, old: str, new: str, meaning: str) -> str:
    count = text.count(old)
    if count != 1:
        fail(f"expected one {meaning}, found {count}")
    return text.replace(old, new, 1)


def probe_source(identifier: str) -> str:
    return f"relocation_probe_{identifier}:\n    .byte $ea\n"


def insert_probe(
    text: str,
    insertion: dict[str, str],
    prefix: str = "",
) -> str:
    identifier = insertion["id"]
    snippet = prefix + probe_source(identifier)
    if "before" in insertion:
        token = insertion["before"]
        return replace_once(text, token, f"{snippet}{token}", identifier)
    token = insertion["after"]
    return replace_once(text, token, f"{token}\n{snippet.rstrip()}", identifier)


def prepare_generated_source(
    project_root: Path,
    manifest: dict[str, Any],
) -> tuple[Path, list[dict[str, Any]]]:
    generated_root = rooted(project_root, manifest["generated_root"])
    source_root = generated_root / "generated"
    source_root.mkdir(parents=True, exist_ok=True)
    main_text = rooted(project_root, manifest["source"]).read_text(encoding="utf-8")
    if "profile_id" in manifest:
        main_text = f"con_revision_profile = {int(manifest['profile_id'])}\n\n{main_text}"
    preamble = "".join(
        f'.include "{include}"\n'
        for include in manifest.get("preamble_includes", [])
    )
    if preamble:
        main_text = f"{preamble}\n{main_text}"
    probes: list[dict[str, Any]] = []
    for region in manifest["regions"]:
        for index, insertion in enumerate(region["insertions"]):
            prefix = ""
            if region["id"] == "audio" and index == 0:
                prefix = '.segment "AUDIO"\n'
            main_text = insert_probe(main_text, insertion, prefix)
            probes.append({
                "id": insertion["id"],
                "region": region["id"],
                "shift_before": index,
            })
    main_path = source_root / "main.asm"
    main_path.write_text(main_text, encoding="utf-8", newline="\n")

    game_override = manifest.get("game_padding_override")
    if game_override:
        positioning_source = rooted(project_root, game_override["source"])
        positioning_text = positioning_source.read_text(encoding="utf-8")
        positioning_text = replace_once(
            positioning_text,
            game_override["original_statement"],
            game_override["replacement_statement"],
            "source-declared game padding",
        )
        positioning_path = source_root / game_override["include_path"]
        positioning_path.parent.mkdir(parents=True, exist_ok=True)
        positioning_path.write_text(positioning_text, encoding="utf-8", newline="\n")

    evidence_regions = [
        region for region in manifest["regions"] if "evidence" in region
    ]
    music_override = manifest.get("music_padding_override")
    if evidence_regions or music_override:
        music_source = project_root / "src" / "audio" / "music_streams.asm"
        music_text = music_source.read_text(encoding="utf-8")
        if music_override:
            music_text = replace_once(
                music_text,
                music_override["original_statement"],
                music_override["replacement_statement"],
                "decoded music padding",
            )
        if evidence_regions:
            evidence_region = evidence_regions[0]
            fixed_tail_name = evidence_region["evidence"]["fixed_tail"]
            fixed_tail_address = number(evidence_region["end"]) + 1
        else:
            fixed_tail_name = "tbl_music_note_periods"
            fixed_tail_address = 0xFF00
        fixed_label = f"{fixed_tail_name}:"
        fixed_header = (
            f'.assert * = ${fixed_tail_address:04x}, error, '
            '"audio relocation budget differs"\n'
            '.segment "FIXED_TAIL"\n\n'
            f"{fixed_label}"
        )
        music_text = replace_once(
            music_text,
            fixed_label,
            fixed_header,
            "fixed synthesis-table boundary",
        )
        music_path = source_root / "audio" / "music_streams.asm"
        music_path.parent.mkdir(parents=True, exist_ok=True)
        music_path.write_text(music_text, encoding="utf-8", newline="\n")
    return main_path, probes


def run_build(
    project_root: Path,
    manifest: dict[str, Any],
    source: Path,
    original_rom: Path,
) -> dict[str, Path]:
    output_root = rooted(project_root, manifest["generated_root"]) / "candidate"
    outputs = {
        "object": output_root / "smb.o",
        "prg": output_root / "smb.prg",
        "labels": output_root / "smb.lbl",
        "map": output_root / "smb.map",
        "debug": output_root / "smb.dbg",
        "rom": output_root / manifest["container"].get("output_name", "smb.nes"),
        "scenarios": output_root / "runtime_scenarios.json",
        "summary": output_root / "relocation_summary.json",
    }
    command = [
        sys.executable,
        str(project_root / "scripts" / "build_native.py"),
        "--source", str(source),
        "--config", str(rooted(project_root, manifest["linker_config"])),
        "--manifest", str(project_root / "assets" / "manifest.json"),
        "--object", str(outputs["object"]),
        "--prg", str(outputs["prg"]),
        "--labels", str(outputs["labels"]),
        "--map", str(outputs["map"]),
        "--debug-info", str(outputs["debug"]),
        "--output-rom", str(outputs["rom"]),
        "--prg-only",
    ]
    subprocess.run(command, cwd=project_root, check=True)
    container = manifest["container"]
    candidate_prg = outputs["prg"].read_bytes()
    reference = original_rom.read_bytes()
    if container["kind"] == "revision":
        profile = load_profile(
            rooted(project_root, container["manifest"]),
            container["profile"],
        )
        header, _reference_prg, chr_data, extra = split_rom(reference, profile)
        candidate = header + candidate_prg + chr_data + extra
    else:
        profile = load_platform_profile(
            rooted(project_root, container["manifest"]),
            container["profile"],
        )
        if profile["format"] == "ines":
            header, _reference_prg, chr_data = split_ines_reference(reference, profile)
            candidate = header + candidate_prg + chr_data
        else:
            validate_fds_reference(reference, profile)
            records = parse_fds_side(reference)
            payload = next(
                item
                for item in profile["verified_payloads"]
                if item["name"] == profile["primary_payload"]
            )
            if len(candidate_prg) != int(payload["size"]):
                fail("relocated FDS primary payload size differs")
            candidate_data = bytearray(reference)
            position = 0
            for descriptor in payload["records"]:
                record = find_fds_record(records, descriptor)
                part = candidate_prg[position:position + record.size]
                candidate_data[
                    record.data_offset:record.data_offset + record.size
                ] = part
                position += record.size
            candidate = bytes(candidate_data)
    outputs["rom"].write_bytes(candidate)
    return outputs


def debug_labels(path: Path) -> dict[str, int]:
    text = path.read_text(encoding="utf-8")
    return {name: int(value, 16) for name, value in SYMBOL_PATTERN.findall(text)}


def music_bank(labels: dict[str, int], prg: bytes, cpu_base: int) -> MusicBank:
    model = MusicBank.__new__(MusicBank)
    model.labels = labels
    model.prg = prg
    model.base = labels["tbl_music_header_offsets"]
    model.end = labels["tbl_music_note_periods"]
    model.stream_addresses = sorted({
        address
        for name, address in labels.items()
        if name.startswith("off_music_stream_")
    })
    model.header_labels = sorted(
        [name for name in HEADER_NAMES if name in labels],
        key=labels.__getitem__,
    )
    model._prg_bytes = lambda label, length: prg[
        labels[label] - cpu_base:labels[label] - cpu_base + length
    ]
    values = list(prg[model.base - cpu_base:model.end - cpu_base])
    model.document = type(
        "RelocationMusicDocument",
        (),
        {"document": {"data": {"values": values}}},
    )()
    model.periods = model._periods()
    model.lengths = model._lengths()
    model.envelope_bytes = (
        model._prg_bytes("tbl_castle_clear_music_envelope", 53)
        if "tbl_castle_clear_music_envelope" in labels
        else bytes(53)
    )
    model.header_by_offset = {
        labels[name] - model.base: name for name in model.header_labels
    }
    return model


def verify_music_padding(
    manifest: dict[str, Any],
    labels: dict[str, int],
    prg: bytes,
    cpu_base: int,
) -> dict[str, Any] | None:
    audio = next(
        (region for region in manifest["regions"] if "evidence" in region),
        None,
    )
    if audio is None:
        return None
    evidence = audio["evidence"]
    song = music_bank(labels, prg, cpu_base).song(evidence["song"])
    decoded_end = max(channel["end"] for channel in song["channels"])
    expected_end = number(evidence["decoded_end"])
    if decoded_end != expected_end:
        fail(
            f"victory music decodes through ${decoded_end:04X}, "
            f"expected ${expected_end:04X}"
        )
    fixed_tail = labels[evidence["fixed_tail"]]
    if fixed_tail != number(audio["end"]) + 1:
        fail("audio fixed-tail label differs from the relocation contract")
    if decoded_end != number(audio["absorbed_range"]["start"]):
        fail("candidate audio padding begins before decoded music ends")
    return {
        "song": evidence["song"],
        "frames": song["frames"],
        "decoded_end": f"0x{decoded_end:04x}",
        "channels": {
            channel["name"]: {
                "start": f"0x{channel['start']:04x}",
                "end": f"0x{channel['end']:04x}",
            }
            for channel in song["channels"]
        },
    }


def verify_absorbed_bytes(
    manifest: dict[str, Any],
    base_prg: bytes,
) -> None:
    cpu_base = number(manifest["cpu_base"])
    for region in manifest["regions"]:
        absorbed = region["absorbed_range"]
        start = number(absorbed["start"])
        end = number(absorbed["end"])
        actual = base_prg[start - cpu_base:end - cpu_base + 1]
        expected = bytes.fromhex(region["absorbed_bytes"])
        if actual != expected:
            fail(
                f"{region['id']} absorbed bytes differ: "
                f"expected {expected.hex()}, got {actual.hex()}"
            )


def verify_layout(
    project_root: Path,
    manifest: dict[str, Any],
    probes: list[dict[str, Any]],
    base_prg_path: Path,
    base_labels_path: Path,
    base_debug_path: Path,
    outputs: dict[str, Path],
) -> dict[str, Any]:
    base_prg = base_prg_path.read_bytes()
    candidate_prg = outputs["prg"].read_bytes()
    if len(base_prg) != 0x8000 or len(candidate_prg) != len(base_prg):
        fail("relocation comparison requires two complete 32 KiB PRGs")
    if candidate_prg == base_prg:
        fail("relocation candidate unexpectedly matches the preservation PRG")
    verify_absorbed_bytes(manifest, base_prg)

    cpu_base = number(manifest["cpu_base"])
    for fixed in manifest["fixed_ranges"]:
        start = number(fixed["start"])
        end = number(fixed["end"])
        left = base_prg[start - cpu_base:end - cpu_base + 1]
        right = candidate_prg[start - cpu_base:end - cpu_base + 1]
        if left != right:
            fail(f"fixed relocation range ${start:04X}-${end:04X} changed")

    base_labels = debug_labels(base_debug_path)
    candidate_labels = debug_labels(outputs["debug"])
    label_file = load_labels(base_labels_path)
    music_evidence = verify_music_padding(manifest, label_file, base_prg, cpu_base)

    vectors_contract = manifest["vectors"]
    vector_start = number(vectors_contract["start"])
    vector_offset = vector_start - cpu_base
    vectors = [
        int.from_bytes(candidate_prg[offset:offset + 2], "little")
        for offset in range(vector_offset, vector_offset + 6, 2)
    ]
    expected_vectors = [
        candidate_labels[target]
        if not str(target).startswith("0x")
        else number(target)
        for target in vectors_contract["targets"]
    ]
    if vectors != expected_vectors:
        fail(
            "candidate vectors do not follow relocated semantic handlers: "
            f"expected {expected_vectors}, got {vectors}"
        )

    anchors_by_region: dict[str, list[int]] = {}
    probe_addresses: list[int] = []
    for probe in probes:
        name = f"relocation_probe_{probe['id']}"
        if name not in candidate_labels:
            fail(f"candidate debug data lacks {name}")
        address = candidate_labels[name]
        base_address = address - probe["shift_before"]
        anchors_by_region.setdefault(probe["region"], []).append(base_address)
        probe_addresses.append(address)
        if candidate_prg[address - cpu_base] != 0xEA:
            fail(f"relocation probe at ${address:04X} is not an EA byte")

    shifted = 0
    checked = 0
    for name, base_address in base_labels.items():
        if name not in candidate_labels:
            fail(f"candidate debug data lost source label {name}")
        region = next(
            (
                item for item in manifest["regions"]
                if number(item["start"]) <= base_address <= number(item["end"])
            ),
            None,
        )
        if region is None:
            expected_shift = 0
        else:
            anchors = anchors_by_region[region["id"]]
            expected_shift = sum(anchor <= base_address for anchor in anchors)
        actual_shift = candidate_labels[name] - base_address
        if actual_shift != expected_shift:
            fail(
                f"label {name} shifted by {actual_shift}, "
                f"expected {expected_shift} from ${base_address:04X}"
            )
        checked += 1
        shifted += actual_shift != 0
    if shifted < int(manifest["minimum_shifted_labels"]):
        fail(
            f"only {shifted} labels moved; "
            f"expected at least {manifest['minimum_shifted_labels']}"
        )

    scenario_relative = manifest.get("runtime_scenarios")
    scenarios = {}
    if scenario_relative:
        scenario_path = rooted(project_root, scenario_relative)
        scenarios = json.loads(scenario_path.read_text(encoding="utf-8"))
    scenarios["rom_sha1"] = sha1(outputs["rom"].read_bytes())
    scenarios["forbidden_execute_addresses"] = [
        f"0x{address:04x}" for address in probe_addresses
    ]
    if manifest.get("runtime_ignored_addresses"):
        scenarios["runtime_ignored_addresses"] = manifest[
            "runtime_ignored_addresses"
        ]
    outputs["scenarios"].write_text(
        json.dumps(scenarios, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    summary = {
        "schema_version": 1,
        "profile": manifest["id"],
        "base_prg_sha1": sha1(base_prg),
        "candidate_prg_sha1": sha1(candidate_prg),
        "candidate_rom_sha1": sha1(outputs["rom"].read_bytes()),
        "checked_labels": checked,
        "shifted_labels": shifted,
        "probe_addresses": [f"0x{address:04x}" for address in probe_addresses],
        "fixed_ranges": manifest["fixed_ranges"],
        "vectors": [f"0x{address:04x}" for address in vectors],
        "music_evidence": music_evidence,
    }
    outputs["summary"].write_text(
        json.dumps(summary, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    project_root = Path(__file__).resolve().parent.parent
    parser.add_argument("--project-root", type=Path, default=project_root)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=project_root / "config" / "relocation_test.json",
    )
    parser.add_argument("--base-prg", type=Path, required=True)
    parser.add_argument("--base-labels", type=Path, required=True)
    parser.add_argument("--base-debug", type=Path, required=True)
    parser.add_argument("--original-rom", type=Path, required=True)
    args = parser.parse_args()

    root = args.project_root.resolve()
    manifest = json.loads(args.manifest.resolve().read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise SystemExit("[ERROR] Unsupported relocation manifest schema")
    try:
        source, probes = prepare_generated_source(root, manifest)
        outputs = run_build(
            root,
            manifest,
            source,
            args.original_rom.resolve(),
        )
        summary = verify_layout(
            root,
            manifest,
            probes,
            args.base_prg.resolve(),
            args.base_labels.resolve(),
            args.base_debug.resolve(),
            outputs,
        )
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"[ERROR] Relocation test failed: {error}") from error
    print(
        f"[OK] Relocation candidate moved {summary['shifted_labels']} labels "
        f"through {len(summary['probe_addresses'])} non-executed probe bytes"
    )
    print(f"[OK] Relocation summary: {outputs['summary']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
