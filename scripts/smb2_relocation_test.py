#!/usr/bin/env python3
"""Build and statically validate the generated SMB2 FDS relocation candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from build_native import resolve_tool, run_tool
from platform_profiles import load_profile
from relocation_test import debug_labels, replace_fds_payloads


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
        raise ValueError(f"expected one {meaning}, found {count}")
    return text.replace(old, new, 1)


def probe_source(identifier: str) -> str:
    return f"relocation_probe_{identifier}:\n    .byte $ea\n"


def prepare_generated_source(
    project_root: Path,
    manifest: dict[str, Any],
) -> tuple[Path, list[dict[str, Any]]]:
    generated_root = rooted(project_root, manifest["generated_root"]) / "generated"
    generated_root.mkdir(parents=True, exist_ok=True)
    main_text = rooted(project_root, manifest["main_source"]).read_text(
        encoding="utf-8"
    )
    probes: list[dict[str, Any]] = []
    for region in manifest["regions"]:
        for index, insertion in enumerate(region["insertions"]):
            token = insertion["before"]
            main_text = replace_once(
                main_text,
                token,
                probe_source(insertion["id"]) + token,
                f"SMB2 relocation anchor {insertion['id']}",
            )
            probes.append({
                "id": insertion["id"],
                "region": region["id"],
                "shift_before": index,
            })
    main_path = generated_root / "main.asm"
    main_path.write_text(main_text, encoding="utf-8", newline="\n")

    override = manifest["padding_override"]
    padding_text = rooted(project_root, override["source"]).read_text(
        encoding="utf-8"
    )
    padding_text = replace_once(
        padding_text,
        override["original_statement"],
        override["replacement_statement"],
        "SMB2 main unused padding",
    )
    padding_path = generated_root / override["include_path"]
    padding_path.parent.mkdir(parents=True, exist_ok=True)
    padding_path.write_text(padding_text, encoding="utf-8", newline="\n")

    aggregate_text = rooted(project_root, manifest["source"]).read_text(
        encoding="utf-8"
    )
    aggregate_path = generated_root / "build.asm"
    aggregate_path.write_text(aggregate_text, encoding="utf-8", newline="\n")
    return aggregate_path, probes


def payload_contract(
    project_root: Path,
    manifest: dict[str, Any],
) -> list[dict[str, Any]]:
    path = rooted(project_root, manifest["payload_manifest"])
    document = json.loads(path.read_text(encoding="utf-8"))
    payloads = document.get("payloads")
    if not isinstance(payloads, list) or not payloads:
        raise ValueError("SMB2 relocation payload manifest has no payloads")
    return payloads


def build_candidate(
    project_root: Path,
    manifest: dict[str, Any],
    source: Path,
    payloads: list[dict[str, Any]],
) -> dict[str, Path]:
    candidate = rooted(project_root, manifest["generated_root"]) / "candidate"
    candidate.mkdir(parents=True, exist_ok=True)
    outputs = {
        "object": candidate / "smb2.o",
        "combined": candidate / "payloads.bin",
        "labels": candidate / "smb2.lbl",
        "map": candidate / "smb2.map",
        "debug": candidate / "smb2.dbg",
        "image": candidate / "smb2.fds",
        "scenarios": candidate / "runtime_scenarios.json",
        "summary": candidate / "relocation_summary.json",
    }
    source_root = project_root / "src" / "smb2"
    run_tool(
        resolve_tool("ca65", project_root),
        [
            str(source),
            "-g",
            "--debug-info",
            "-I",
            str(source.parent),
            "-I",
            str(source_root),
            "-I",
            str(project_root / "src"),
            "-o",
            str(outputs["object"]),
        ],
        project_root,
    )
    run_tool(
        resolve_tool("ld65", project_root),
        [
            "-C",
            str(rooted(project_root, manifest["linker_config"])),
            str(outputs["object"]),
            "-o",
            str(outputs["combined"]),
            "-Ln",
            str(outputs["labels"]),
            "--mapfile",
            str(outputs["map"]),
            "--dbgfile",
            str(outputs["debug"]),
        ],
        candidate,
    )
    combined = outputs["combined"].read_bytes()
    expected_size = sum(number(payload["size"]) for payload in payloads)
    if len(combined) != expected_size:
        raise ValueError(
            f"candidate payload size is {len(combined)}, expected {expected_size}"
        )
    offset = 0
    for payload in payloads:
        size = number(payload["size"])
        name = str(payload["name"])
        (candidate / f"{name}.bin").write_bytes(combined[offset:offset + size])
        offset += size
    return outputs


def validate_absorbed_bytes(
    manifest: dict[str, Any],
    baseline_main: bytes,
) -> None:
    cpu_base = number(manifest["cpu_base"])
    for region in manifest["regions"]:
        absorbed = region["absorbed_range"]
        start = number(absorbed["start"])
        end = number(absorbed["end"])
        actual = baseline_main[start - cpu_base:end - cpu_base + 1]
        expected = bytes.fromhex(region["absorbed_bytes"])
        if actual != expected:
            raise ValueError(
                f"{region['id']} absorbed bytes differ: "
                f"expected {expected.hex()}, got {actual.hex()}"
            )


def expected_main_shift(
    address: int,
    anchors: list[int],
    fixed_start: int,
) -> int:
    if address >= fixed_start:
        return 0
    return sum(anchor <= address for anchor in anchors)


def validate_layout(
    project_root: Path,
    manifest: dict[str, Any],
    payloads: list[dict[str, Any]],
    probes: list[dict[str, Any]],
    baseline_dir: Path,
    outputs: dict[str, Path],
    original_image: Path,
) -> dict[str, Any]:
    candidate_dir = outputs["combined"].parent
    baseline_data = {
        str(payload["name"]): (baseline_dir / f"{payload['name']}.bin").read_bytes()
        for payload in payloads
    }
    candidate_data = {
        str(payload["name"]): (candidate_dir / f"{payload['name']}.bin").read_bytes()
        for payload in payloads
    }
    for payload in payloads:
        name = str(payload["name"])
        size = number(payload["size"])
        if len(baseline_data[name]) != size or len(candidate_data[name]) != size:
            raise ValueError(f"{name} relocation changed its payload capacity")
    changed = sorted(
        name for name in baseline_data if baseline_data[name] != candidate_data[name]
    )
    if changed != sorted(manifest["expected_changed_payloads"]):
        raise ValueError(f"unexpected changed SMB2 payload set: {changed}")

    baseline_main = baseline_data["SM2MAIN"]
    candidate_main = candidate_data["SM2MAIN"]
    validate_absorbed_bytes(manifest, baseline_main)
    cpu_base = number(manifest["cpu_base"])
    for fixed in manifest["fixed_ranges"]:
        start = number(fixed["start"])
        end = number(fixed["end"])
        left = baseline_main[start - cpu_base:end - cpu_base + 1]
        right = candidate_main[start - cpu_base:end - cpu_base + 1]
        if left != right:
            raise ValueError(f"fixed SMB2 range ${start:04X}-${end:04X} changed")

    baseline_labels = debug_labels(baseline_dir / "smb2.dbg")
    candidate_labels = debug_labels(outputs["debug"])
    anchors: list[int] = []
    probe_addresses: list[int] = []
    for probe in probes:
        name = f"relocation_probe_{probe['id']}"
        if name not in candidate_labels:
            raise ValueError(f"candidate debug data lacks {name}")
        address = candidate_labels[name]
        anchors.append(address - int(probe["shift_before"]))
        probe_addresses.append(address)
        if candidate_main[address - cpu_base] != 0xea:
            raise ValueError(f"SMB2 relocation probe at ${address:04X} is not EA")

    fixed_start = min(number(item["start"]) for item in manifest["fixed_ranges"])
    shifted = 0
    checked = 0
    overlay_checked = 0
    for name, baseline_address in baseline_labels.items():
        if name not in candidate_labels:
            raise ValueError(f"candidate debug data lost source label {name}")
        if "smb2_main" in name:
            expected = expected_main_shift(baseline_address, anchors, fixed_start)
            checked += 1
            shifted += expected != 0
        elif any(marker in name for marker in (
            "smb2_data2", "smb2_data3", "smb2_data4"
        )):
            expected = 0
            overlay_checked += 1
        else:
            continue
        actual = candidate_labels[name] - baseline_address
        if actual != expected:
            raise ValueError(
                f"label {name} shifted by {actual}, expected {expected} "
                f"from ${baseline_address:04X}"
            )
    if shifted < int(manifest["minimum_shifted_labels"]):
        raise ValueError(
            f"only {shifted} SMB2 main labels moved; "
            f"expected at least {manifest['minimum_shifted_labels']}"
        )

    vectors = manifest["vectors"]
    vector_start = number(vectors["start"])
    vector_offset = vector_start - cpu_base
    actual_vectors = [
        int.from_bytes(candidate_main[offset:offset + 2], "little")
        for offset in range(vector_offset, vector_offset + 6, 2)
    ]
    expected_vectors = [candidate_labels[name] for name in vectors["targets"]]
    if actual_vectors != expected_vectors:
        raise ValueError(
            f"SMB2 vectors do not follow shifted handlers: {actual_vectors}"
        )

    profile = load_profile(
        rooted(project_root, manifest["platform_manifest"]),
        manifest["platform_profile"],
    )
    image = replace_fds_payloads(
        original_image.read_bytes(), profile, candidate_data
    )
    outputs["image"].write_bytes(image)
    outputs["scenarios"].write_text(
        json.dumps({
            "schema_version": 1,
            "profile": manifest["id"],
            "rom_sha1": sha1(image),
            "forbidden_execute_addresses": [
                f"0x{address:04x}" for address in probe_addresses
            ],
        }, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    summary = {
        "schema_version": 1,
        "profile": manifest["id"],
        "baseline_payload_sha1": {
            name: sha1(data) for name, data in baseline_data.items()
        },
        "candidate_payload_sha1": {
            name: sha1(data) for name, data in candidate_data.items()
        },
        "candidate_image_sha1": sha1(image),
        "checked_main_labels": checked,
        "shifted_main_labels": shifted,
        "checked_overlay_labels": overlay_checked,
        "probe_addresses": [f"0x{address:04x}" for address in probe_addresses],
        "fixed_ranges": manifest["fixed_ranges"],
        "vectors": [f"0x{address:04x}" for address in actual_vectors],
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
        default=project_root / "config" / "relocation" / "smb2_jp_fds.json",
    )
    parser.add_argument("--baseline-dir", type=Path, required=True)
    parser.add_argument("--original-image", type=Path, required=True)
    args = parser.parse_args()
    root = args.project_root.resolve()
    manifest = json.loads(args.manifest.resolve().read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise SystemExit("[ERROR] Unsupported SMB2 relocation manifest schema")
    try:
        payloads = payload_contract(root, manifest)
        source, probes = prepare_generated_source(root, manifest)
        outputs = build_candidate(root, manifest, source, payloads)
        summary = validate_layout(
            root,
            manifest,
            payloads,
            probes,
            args.baseline_dir.resolve(),
            outputs,
            args.original_image.resolve(),
        )
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"[ERROR] SMB2 relocation test failed: {error}") from error
    print(
        f"[OK] SMB2 relocation moved {summary['shifted_main_labels']} labels "
        f"through {len(summary['probe_addresses'])} non-executed probe bytes"
    )
    print(f"[OK] SMB2 relocation summary: {outputs['summary']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
