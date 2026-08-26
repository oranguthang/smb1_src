#!/usr/bin/env python3
"""Audit the aggregate Source Reconstruction 2.0 contract."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any


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


def validate_roadmap(text: str, status: str = "tag-ready") -> list[str]:
    complete_limit = 15 if status == "tag-ready" else 13
    errors = [
        f"roadmap milestone {number} is not Complete"
        for number in range(complete_limit)
        if re.search(
            rf"^### {number}\. .* - Complete$", text, re.MULTILINE
        ) is None
    ]
    if status == "development":
        for number, expected in ((13, "In Progress"), (14, "Planned")):
            if re.search(
                rf"^### {number}\. .* - {expected}$", text, re.MULTILINE
            ) is None:
                errors.append(
                    f"roadmap milestone {number} is not {expected}"
                )
    return errors


def validate_source_2(
    project_root: Path,
    manifest_path: Path,
    require_ready: bool = False,
) -> list[str]:
    release = load_json(manifest_path)
    errors: list[str] = []
    status = release.get("status")
    if release.get("schema_version") != 1:
        errors.append("Source Reconstruction 2.0 manifest is not schema 1")
    if status not in {"development", "tag-ready"}:
        errors.append("Source Reconstruction 2.0 status is invalid")
    if require_ready and status != "tag-ready":
        errors.append("Source Reconstruction 2.0 manifest is not tag-ready")
    predecessor = release["predecessor"]
    predecessor_manifest = load_json(project_root / predecessor["manifest"])
    for field in ("tag", "commit"):
        source_field = "local_tag" if field == "tag" else "release_commit"
        if predecessor[field] != predecessor_manifest.get(source_field):
            errors.append(f"predecessor {field} disagrees with the 1.0 manifest")
    try:
        actual_tag_target = git_output(
            project_root,
            "rev-parse",
            f"refs/tags/{predecessor['tag']}^{{commit}}",
        )
    except subprocess.CalledProcessError:
        errors.append(f"predecessor tag is missing: {predecessor['tag']}")
    else:
        if actual_tag_target != predecessor["commit"]:
            errors.append("predecessor tag target differs from the 2.0 contract")
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", predecessor["commit"], "HEAD"],
            cwd=project_root,
            check=False,
        )
        if ancestor.returncode != 0:
            errors.append("Source Reconstruction 1.0 is not an ancestor of HEAD")

    contracts = release["contracts"]
    fixed = load_json(project_root / contracts["fixed_variant_manifest"])
    if len(fixed["variants"]) != contracts["fixed_variants"]:
        errors.append("fixed-layout variant count differs from the 2.0 manifest")
    if any(not item.get("changes") or not item.get("runtime") for item in fixed["variants"]):
        errors.append("every fixed-layout variant must declare changes and runtime evidence")

    expanded = load_json(project_root / contracts["expanded_manifest"])
    if expanded["id"] != contracts["expanded_profile"]:
        errors.append("expanded profile identity differs from the 2.0 manifest")
    if expanded["fixed_cpu_range"].get("allowed_changes") != []:
        errors.append("2.0 CNROM fixed CPU range must permit no changes")

    studios = load_json(project_root / contracts["content_studio_manifest"])
    content_format_path = project_root / contracts["content_format_manifest"]
    format_contract = load_json(content_format_path)
    formats = load_json(content_format_path.parent / format_contract["base_manifest"])
    excluded = set(format_contract.get("excluded_artifacts", []))
    format_artifacts = {
        artifact["id"] for artifact in formats["artifacts"]
        if artifact["id"] not in excluded
    }
    format_artifacts.update(
        artifact["id"] for artifact in format_contract.get("artifacts", [])
    )
    if len(studios["studios"]) != contracts["content_studios"]:
        errors.append("content studio count differs from the 2.0 manifest")
    studio_artifacts = {
        artifact
        for studio in studios["studios"]
        for artifact in studio["artifacts"]
    }
    if studio_artifacts != format_artifacts:
        errors.append("content studios do not cover exactly the stable codec artifacts")
    if len(format_artifacts) != contracts["content_artifacts"]:
        errors.append("content artifact count differs from the 2.0 manifest")

    revisions = load_json(project_root / contracts["revision_manifest"])
    supported = [profile["id"] for profile in revisions["supported"]]
    evaluated = [profile["id"] for profile in revisions["evaluated_not_supported"]]
    if supported != contracts["supported_revisions"]:
        errors.append("supported revision list differs from the 2.0 manifest")
    if evaluated != contracts["evaluated_unsupported_revisions"]:
        errors.append("evaluated revision list differs from the 2.0 manifest")

    platforms = load_json(project_root / contracts["platform_manifest"])
    platform_ids = [profile["id"] for profile in platforms["profiles"]]
    if platform_ids != contracts["planned_platform_profiles"]:
        errors.append("platform profile list differs from the 2.0 manifest")
    if status == "tag-ready" and any(
        profile.get("status") != "supported" for profile in platforms["profiles"]
    ):
        errors.append("tag-ready 2.0 requires every platform profile to be supported")

    for relative in release["required_documents"]:
        if not (project_root / relative).is_file():
            errors.append(f"required 2.0 document is missing: {relative}")
    makefile = (project_root / "Makefile").read_text(encoding="utf-8")
    for target in release["required_targets"]:
        if re.search(rf"^{re.escape(target)}\s*:", makefile, re.MULTILINE) is None:
            errors.append(f"required 2.0 Make target is missing: {target}")
    errors.extend(
        validate_roadmap(
            (project_root / "docs" / "roadmap.md").read_text(encoding="utf-8"),
            status=status,
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
        "--require-ready",
        action="store_true",
        help="fail unless the manifest and every release profile are tag-ready",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parent.parent
        / "config"
        / "source_reconstruction_2_0.json",
    )
    args = parser.parse_args()
    errors = validate_source_2(
        args.project_root.resolve(),
        args.manifest.resolve(),
        require_ready=args.require_ready,
    )
    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        print(f"[FAIL] Source Reconstruction 2.0 audit found {len(errors)} error(s)")
        return 1
    print("[OK] Source Reconstruction 2.0 manifests, milestones, targets, and predecessor agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
