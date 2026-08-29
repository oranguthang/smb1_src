#!/usr/bin/env python3
"""Audit the active Source Reconstruction 3.0 development contract."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any


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
        ("audio", "requires-evidence", 3),
    ]
    actual_budgets = [
        (item.get("id"), item.get("status"), item.get("insertions"))
        for item in budgets
    ]
    if actual_budgets != expected_budgets:
        errors.append("canonical relocation budgets differ or lack evidence")
    if relocation.get("maximum_insertions") != 9:
        errors.append("canonical relocation insertion budget differs")

    for relative in release["required_documents"]:
        if not (project_root / relative).is_file():
            errors.append(f"required 3.0 document is missing: {relative}")
    makefile = (project_root / "Makefile").read_text(encoding="utf-8")
    for target_name in release["required_stable_targets"]:
        if re.search(
            rf"^{re.escape(target_name)}\s*:", makefile, re.MULTILINE
        ) is None:
            errors.append(f"required stable Make target is missing: {target_name}")
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
