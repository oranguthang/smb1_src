#!/usr/bin/env python3
"""Audit the active Source Reconstruction 3.0 development contract."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any

from content_profiles import validate_profiles


EXPECTED_MILESTONES = [
    "relocation_architecture",
    "canonical_relocation",
    "revision_relocation",
    "platform_relocation",
    "platform_interfaces",
    "semantic_runtime_evidence",
    "profile_aware_authoring",
    "later_engine_feasibility",
    "smb2_architecture",
    "smb2_identity_build",
    "smb2_source_reconstruction",
    "smb2_runtime_relocation",
    "smb2_authoring",
    "source_reconstruction_3_0",
]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def git_output(project_root: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=project_root,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.stdout.strip()


def validate_milestones(
    milestones: list[dict[str, str]], status: str
) -> list[str]:
    errors: list[str] = []
    identifiers = [item.get("id") for item in milestones]
    if identifiers != EXPECTED_MILESTONES:
        errors.append("Source 3.0 milestone order or identity differs")
        return errors

    states = [item.get("status") for item in milestones]
    if any(state not in {"planned", "in-progress", "complete"} for state in states):
        errors.append("Source 3.0 milestone status is invalid")
        return errors
    if status == "tag-ready":
        if any(state != "complete" for state in states):
            errors.append("tag-ready Source 3.0 has incomplete milestones")
        return errors

    seen_open = False
    active = 0
    for state in states:
        if state == "complete":
            if seen_open:
                errors.append("completed Source 3.0 milestone follows an open milestone")
                break
        else:
            seen_open = True
        if state == "in-progress":
            active += 1
    if active != 1:
        errors.append("development Source 3.0 requires exactly one active milestone")
    first_open = next(
        (state for state in states if state != "complete"),
        None,
    )
    if first_open != "in-progress":
        errors.append("first open Source 3.0 milestone is not active")
    return errors


def validate_roadmap(text: str, status: str) -> list[str]:
    errors = [
        f"roadmap milestone {number} is not Complete"
        for number in range(15)
        if re.search(
            rf"^### {number}\. .* - Complete$", text, re.MULTILINE
        ) is None
    ]
    expected = "Complete" if status == "tag-ready" else "In Progress"
    if re.search(rf"^### 15\. .* - {expected}$", text, re.MULTILINE) is None:
        errors.append(f"roadmap milestone 15 is not {expected}")
    return errors


def validate_scenario_ids(
    document: dict[str, Any], expected: list[str]
) -> list[str]:
    actual = [scenario.get("id") for scenario in document.get("scenarios", [])]
    if actual != expected:
        return ["Source 3.0 semantic runtime scenario list differs"]
    return []


def validate_resolved_unknowns(text: str, expected: list[str]) -> list[str]:
    errors: list[str] = []
    for identifier in expected:
        match = re.search(
            rf"^### {re.escape(identifier)}\b.*?(?=^### |\Z)",
            text,
            re.MULTILINE | re.DOTALL,
        )
        if match is None or "- **Status:** Resolved" not in match.group(0):
            errors.append(f"semantic evidence unknown is not resolved: {identifier}")
    return errors


def validate_authoring_contract(
    project_root: Path, contract: dict[str, Any]
) -> list[str]:
    format_relative = contract.get("format_manifest", "")
    if not (project_root / format_relative).is_file():
        return ["Source 3.0 content format manifest is missing"]
    relative = contract.get("profile_manifest", "")
    path = project_root / relative
    if not path.is_file():
        return ["Source 3.0 content authoring profile manifest is missing"]
    document = load_json(path)
    errors = validate_profiles(document)
    if errors:
        return [f"content authoring contract: {error}" for error in errors]

    if document["default_profile"] != contract.get("default_profile"):
        errors.append("Source 3.0 default content authoring profile differs")
    if document["studio_ids"] != contract.get("studio_ids"):
        errors.append("Source 3.0 content authoring studio list differs")
    supported = [
        profile["id"]
        for profile in document["profiles"]
        if profile["status"] == "supported"
    ]
    planned = [
        profile["id"]
        for profile in document["profiles"]
        if profile["status"] == "planned"
    ]
    partial = [
        profile["id"]
        for profile in document["profiles"]
        if profile["status"] == "partial"
    ]
    if supported != contract.get("supported_profiles"):
        errors.append("Source 3.0 supported content profile list differs")
    if planned != contract.get("planned_profiles"):
        errors.append("Source 3.0 planned content profile list differs")
    if partial != contract.get("partial_profiles"):
        errors.append("Source 3.0 partial content profile list differs")
    return errors


def validate_later_engine_contract(
    project_root: Path, contract: dict[str, Any]
) -> list[str]:
    relative = contract.get("feasibility_manifest", "")
    path = project_root / relative
    if not path.is_file():
        return ["Source 3.0 later-engine feasibility manifest is missing"]
    document = load_json(path)
    decision = document.get("decision", {})
    expected = {
        "subject": document.get("subject"),
        "classification": decision.get("classification"),
        "source_3_scope": decision.get("source_3_scope"),
        "shared_profile": decision.get("shared_profile"),
        "future_boundary": decision.get("future_boundary"),
    }
    actual = {field: contract.get(field) for field in expected}
    if actual != expected:
        return ["Source 3.0 later-engine decision differs from its evidence manifest"]
    if actual != {
        "subject": "smb2_jp_fds",
        "classification": "later-engine-sibling",
        "source_3_scope": "sibling-reconstruction",
        "shared_profile": False,
        "future_boundary": "smb2-owned-source",
    }:
        return ["Source 3.0 later-engine sibling boundary differs"]
    return []


def validate_smb2_contract(project_root: Path, contract: dict[str, Any]) -> list[str]:
    relative = contract.get("reconstruction_manifest", "")
    path = project_root / relative
    if not path.is_file():
        return ["Source 3.0 SMB2 reconstruction manifest is missing"]
    document = load_json(path)
    if document.get("schema_version") != 1 or document.get("id") != "smb2_jp_fds":
        return ["Source 3.0 SMB2 reconstruction identity differs"]
    if document.get("status") != "source-ready":
        return ["Source 3.0 SMB2 source is not ready"]
    if contract.get("profile") != document["id"]:
        return ["Source 3.0 SMB2 profile differs from its reconstruction manifest"]
    if contract.get("source_roots") != document.get("source_roots"):
        return ["Source 3.0 SMB2 source boundary differs"]
    if contract.get("shared_profile") is not False:
        return ["Source 3.0 SMB2 must remain a sibling engine"]
    complexity = document.get("complexity_contract", {})
    expected = {
        "existing_smb1_smb2_conditionals": 0,
        "executable_incbin": False,
        "shared_code_requires_independent_equivalence": True,
        "payloads_build_independently": True,
        "source_2_files_may_change": False,
    }
    if complexity != expected:
        return ["Source 3.0 SMB2 complexity boundary differs"]
    if len(document.get("payloads", [])) != 4:
        return ["Source 3.0 SMB2 program payload set differs"]
    source_build = document.get("source_build", {})
    expected_order = ["SM2MAIN", "SM2DATA2", "SM2DATA3", "SM2DATA4"]
    if source_build.get("payload_order") != expected_order:
        return ["Source 3.0 SMB2 source payload order differs"]
    if source_build.get("combined_size") != sum(
        int(payload["size"]) for payload in document["payloads"]
    ):
        return ["Source 3.0 SMB2 combined source size differs"]
    if any(
        source_build.get(field) != value
        for field, value in {
            "build_target": "build-smb2-source",
            "payload_verify_target": "verify-smb2-source",
            "image_verify_target": "verify-smb2",
        }.items()
    ):
        return ["Source 3.0 SMB2 source targets differ"]
    for field in (
        "aggregate_source",
        "linker_config",
        "build_script",
        "provenance_manifest",
        "import_script",
    ):
        if not (project_root / source_build.get(field, "")).is_file():
            return [f"Source 3.0 SMB2 {field} is missing"]
    for payload in document["payloads"]:
        if not (project_root / payload.get("source", "")).is_file():
            return [f"Source 3.0 SMB2 payload source is missing: {payload.get('name')}"]
    provenance = load_json(project_root / source_build["provenance_manifest"])
    if provenance.get("schema_version") != 1:
        return ["Source 3.0 SMB2 provenance schema differs"]
    if provenance.get("counts", {}).get("labels") != len(
        [item for item in provenance.get("renames", []) if item.get("kind") == "label"]
    ):
        return ["Source 3.0 SMB2 provenance label count differs"]
    platform_path = project_root / document.get("platform_manifest", "")
    if not platform_path.is_file():
        return ["Source 3.0 SMB2 platform manifest is missing"]
    platform_document = load_json(platform_path)
    profiles = platform_document.get("profiles", [])
    if len(profiles) != 1 or profiles[0].get("id") != document["id"]:
        return ["Source 3.0 SMB2 platform identity differs"]
    platform_payloads = profiles[0].get("verified_payloads", [])
    source_payloads = document["payloads"]
    if [item.get("name") for item in platform_payloads] != [
        item.get("name") for item in source_payloads
    ]:
        return ["Source 3.0 SMB2 platform payload set differs"]
    for platform_payload, source_payload in zip(
        platform_payloads, source_payloads, strict=True
    ):
        if any(
            platform_payload.get(field) != source_payload.get(field)
            for field in ("size", "sha1")
        ):
            return ["Source 3.0 SMB2 payload identity differs"]
    errors = []
    source_roots = [project_root / value for value in document["source_roots"]]
    declaration_modules = {
        (project_root / value).resolve()
        for value in document.get("declaration_modules", [])
    }
    actual_declarations: set[Path] = set()
    assembly_root = project_root / "src"
    if assembly_root.is_dir():
        for path in assembly_root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".asm", ".inc"}:
                continue
            text = path.read_text(encoding="utf-8")
            inside_smb2 = any(
                source_root == path.parent or source_root in path.parents
                for source_root in source_roots
            )
            if inside_smb2 and path.suffix.lower() == ".inc":
                actual_declarations.add(path.resolve())
            if inside_smb2 and any(
                part.lower() in {"data2", "data3", "data4"}
                for part in path.relative_to(assembly_root).parts
            ):
                errors.append(f"SMB2 source path uses a physical payload number: {path}")
            if not inside_smb2 and re.search(
                r"^\s*\.(?:if|ifdef|ifndef|elseif).*\bsmb2\b",
                text,
                re.IGNORECASE | re.MULTILINE,
            ):
                errors.append(f"SMB1 source contains an SMB2 conditional: {path}")
            if inside_smb2 and re.search(
                r"^\s*\.incbin\b", text, re.IGNORECASE | re.MULTILINE
            ):
                errors.append(f"SMB2 source hides bytes with incbin: {path}")
            if inside_smb2 and len(text.splitlines()) > 700:
                errors.append(f"SMB2 source module exceeds 700 lines: {path}")
    if actual_declarations != declaration_modules:
        errors.append("SMB2 .inc declaration boundary differs")
    common_root = project_root / document.get("shared_source_root", "")
    common_modules = document.get("common_modules", [])
    for module in common_modules:
        common_path = project_root / module.get("source", "")
        if not common_path.is_file() or common_root not in common_path.parents:
            errors.append(f"Late-FDS common module boundary differs: {common_path}")
            continue
        common_text = common_path.read_text(encoding="utf-8")
        if re.search(
            r"^\s*\.(?:if|ifdef|ifndef|elseif).*\b(?:ann|smb2)\b",
            common_text,
            re.IGNORECASE | re.MULTILINE,
        ):
            errors.append(f"Late-FDS common module contains a revision branch: {common_path}")
        if re.search(r"^\s*\.incbin\b", common_text, re.IGNORECASE | re.MULTILINE):
            errors.append(f"Late-FDS common module hides bytes with incbin: {common_path}")
        common_include = common_path.relative_to(common_root.parent).as_posix()
        for consumer_value in module.get("consumer_sources", []):
            consumer_path = project_root / consumer_value
            if not consumer_path.is_file():
                errors.append(f"Late-FDS common consumer is missing: {consumer_path}")
                continue
            consumer_text = consumer_path.read_text(encoding="utf-8")
            if common_include not in consumer_text.replace("\\", "/"):
                errors.append(
                    f"Late-FDS common consumer omits {common_include}: {consumer_path}"
                )
    return errors


def validate_source_3(
    project_root: Path,
    manifest_path: Path,
    require_ready: bool = False,
) -> list[str]:
    release = load_json(manifest_path)
    errors: list[str] = []
    status = release.get("status")
    if release.get("schema_version") != 1:
        errors.append("Source Reconstruction 3.0 manifest is not schema 1")
    if status not in {"development", "tag-ready"}:
        errors.append("Source Reconstruction 3.0 status is invalid")
        return errors
    if require_ready and status != "tag-ready":
        errors.append("Source Reconstruction 3.0 manifest is not tag-ready")
    if status == "tag-ready" and release.get("tag") != "source-reconstruction-3.0":
        errors.append("Source Reconstruction 3.0 release tag differs")

    predecessor = release["predecessor"]
    predecessor_manifest = load_json(project_root / predecessor["manifest"])
    if predecessor_manifest.get("tag") != predecessor["tag"]:
        errors.append("Source 3.0 predecessor tag disagrees with the 2.0 manifest")
    if predecessor_manifest.get("status") != "tag-ready":
        errors.append("Source 3.0 predecessor manifest is not tag-ready")
    try:
        target = git_output(
            project_root,
            "rev-parse",
            f"refs/tags/{predecessor['tag']}^{{commit}}",
        )
    except subprocess.CalledProcessError:
        errors.append(f"predecessor tag is missing: {predecessor['tag']}")
    else:
        if target != predecessor["commit"]:
            errors.append("Source 2.0 tag target differs from the 3.0 contract")
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", predecessor["commit"], "HEAD"],
            cwd=project_root,
            check=False,
        )
        if ancestor.returncode != 0:
            errors.append("Source Reconstruction 2.0 is not an ancestor of HEAD")

    errors.extend(validate_milestones(release["milestones"], status))
    relocation = release["relocation"]
    expected_layout = {
        "cpu_range": {"start": "0x8000", "end": "0xffff"},
        "fixed_audio": {"start": "0xf2d0", "end": "0xfeff"},
        "fixed_tail": {"start": "0xff00", "end": "0xffff"},
    }
    for field, expected in expected_layout.items():
        if relocation.get(field) != expected:
            errors.append(f"canonical relocation {field} differs")
    budgets = relocation.get("relocation_budgets", [])
    expected_budgets = [
        ("game_and_rendering", "source-declared-unused", 6),
        ("audio", "decoder-and-runtime-proven", 3),
    ]
    actual_budgets = [
        (item.get("id"), item.get("status"), item.get("insertions"))
        for item in budgets
    ]
    if actual_budgets != expected_budgets:
        errors.append("canonical relocation budgets differ or lack evidence")
    if relocation.get("maximum_insertions") != 9:
        errors.append("canonical relocation insertion budget differs")

    semantic = release.get("semantic_evidence", {})
    enemy_manifest = project_root / semantic.get("enemy_stream_manifest", "")
    unreachable_manifest = project_root / semantic.get(
        "unreachable_code_manifest", ""
    )
    runtime_manifest = project_root / semantic.get("runtime_manifest", "")
    if not enemy_manifest.is_file():
        errors.append("Source 3.0 enemy-stream evidence manifest is missing")
    if not unreachable_manifest.is_file():
        errors.append("Source 3.0 unreachable-code evidence manifest is missing")
    if not runtime_manifest.is_file():
        errors.append("Source 3.0 semantic runtime manifest is missing")
    else:
        errors.extend(
            validate_scenario_ids(
                load_json(runtime_manifest),
                semantic.get("runtime_scenarios", []),
            )
        )
    preservation = load_json(
        project_root / "config" / "preservation_source_1_0.json"
    )
    stable_runtime = load_json(project_root / "scenarios" / "runtime_scenarios.json")
    stable_scenario_count = preservation["evidence"]["runtime_scenarios"]
    if len(stable_runtime.get("scenarios", [])) != stable_scenario_count:
        errors.append("Preservation Source 1.0 runtime scenario count changed")
    errors.extend(
        validate_resolved_unknowns(
            (project_root / "docs" / "unknowns.md").read_text(encoding="utf-8"),
            semantic.get("resolved_unknowns", []),
        )
    )
    errors.extend(validate_authoring_contract(project_root, release.get("authoring", {})))
    errors.extend(
        validate_later_engine_contract(project_root, release.get("later_engine", {}))
    )
    errors.extend(validate_smb2_contract(project_root, release.get("smb2", {})))

    for relative in release["required_documents"]:
        if not (project_root / relative).is_file():
            errors.append(f"required 3.0 document is missing: {relative}")
    makefile = (project_root / "Makefile").read_text(encoding="utf-8")
    for target_name in release["required_stable_targets"]:
        if re.search(
            rf"^{re.escape(target_name)}\s*:", makefile, re.MULTILINE
        ) is None:
            errors.append(f"required stable Make target is missing: {target_name}")
    relocation_manifests = relocation.get("manifests", [])
    if len(relocation_manifests) != 3 or any(
        not (project_root / relative).is_file()
        for relative in relocation_manifests
    ):
        errors.append("revision relocation manifest matrix is incomplete")
    platform_manifests = relocation.get("platform_manifests", [])
    if len(platform_manifests) != 3 or any(
        not (project_root / relative).is_file()
        for relative in platform_manifests
    ):
        errors.append("platform relocation manifest matrix is incomplete")
    for target_name in release["required_development_targets"]:
        if re.search(
            rf"^{re.escape(target_name)}\s*:", makefile, re.MULTILINE
        ) is None:
            errors.append(f"required development Make target is missing: {target_name}")
    errors.extend(
        validate_roadmap(
            (project_root / "docs" / "roadmap.md").read_text(encoding="utf-8"),
            status,
        )
    )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parent.parent
        / "config"
        / "source_reconstruction_3_0.json",
    )
    parser.add_argument(
        "--require-ready",
        action="store_true",
        help="fail unless every milestone and the release manifest are tag-ready",
    )
    args = parser.parse_args()
    errors = validate_source_3(
        args.project_root.resolve(),
        args.manifest.resolve(),
        args.require_ready,
    )
    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        print(f"[FAIL] Source Reconstruction 3.0 audit found {len(errors)} error(s)")
        return 1
    print("[OK] Source Reconstruction 3.0 boundary and milestones agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
