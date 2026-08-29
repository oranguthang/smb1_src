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
    if supported != contract.get("supported_profiles"):
        errors.append("Source 3.0 supported content profile list differs")
    if planned != contract.get("planned_profiles"):
        errors.append("Source 3.0 planned content profile list differs")
    return errors


def validate_source_3(project_root: Path, manifest_path: Path) -> list[str]:
    release = load_json(manifest_path)
    errors: list[str] = []
    status = release.get("status")
    if release.get("schema_version") != 1:
        errors.append("Source Reconstruction 3.0 manifest is not schema 1")
    if status not in {"development", "tag-ready"}:
        errors.append("Source Reconstruction 3.0 status is invalid")
        return errors

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
    args = parser.parse_args()
    errors = validate_source_3(
        args.project_root.resolve(),
        args.manifest.resolve(),
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
