#!/usr/bin/env python3
"""Audit the repository contract for Preservation Source 1.0."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_hash_contracts(
    release: dict[str, Any], assets: dict[str, Any], runtime: dict[str, Any]
) -> list[str]:
    errors: list[str] = []
    expected = release["reference"]
    reference = assets["reference_rom"]
    comparisons = {
        "ROM SHA-1": (expected["rom_sha1"], reference["sha1"]),
        "PRG SHA-1": (expected["prg_sha1"], reference["prg_sha1"]),
        "CHR SHA-1": (expected["chr_sha1"], reference["chr_sha1"]),
        "mapper": (expected["mapper"], reference["mapper"]),
        "mirroring": (expected["mirroring"], reference["mirroring"]),
        "runtime ROM SHA-1": (expected["rom_sha1"], runtime["rom_sha1"]),
        "runtime movie SHA-1": (release["evidence"]["movie_sha1"], runtime["movie_sha1"]),
    }
    for name, (left, right) in comparisons.items():
        if left != right:
            errors.append(f"{name} contract mismatch: release={left}, source={right}")
    return errors


def validate_roadmap(text: str) -> list[str]:
    errors = []
    for milestone in range(10):
        pattern = rf"^### {milestone}\. .* - Complete$"
        if re.search(pattern, text, re.MULTILINE) is None:
            errors.append(f"roadmap milestone {milestone} is not Complete")
    return errors


def git_lines(project_root: Path, *arguments: str) -> list[str]:
    result = subprocess.run(
        ["git", *arguments], cwd=project_root, check=True,
        capture_output=True, text=True, encoding="utf-8",
    )
    return [line for line in result.stdout.splitlines() if line]


def tool_version(path: Path) -> str:
    result = subprocess.run(
        [str(path), "--version"], check=False, capture_output=True,
        text=True, encoding="utf-8", errors="replace",
    )
    return (result.stdout + result.stderr).strip()


def validate_release(project_root: Path, manifest_path: Path) -> list[str]:
    release = load_json(manifest_path)
    assets = load_json(project_root / "assets" / "manifest.json")
    runtime = load_json(project_root / "scenarios" / "runtime_scenarios.json")
    formats = load_json(project_root / "config" / "data_formats.json")
    errors = validate_hash_contracts(release, assets, runtime)

    tag = release.get("local_tag")
    release_commit = release.get("release_commit")
    if tag and release_commit:
        try:
            actual_commit = git_lines(
                project_root, "rev-parse", f"refs/tags/{tag}^{{commit}}"
            )
        except subprocess.CalledProcessError:
            errors.append(f"required annotated release tag is missing: {tag}")
        else:
            if actual_commit != [release_commit]:
                errors.append(
                    f"release tag target mismatch: expected={release_commit}, "
                    f"actual={actual_commit[0] if actual_commit else 'missing'}"
                )

    if len(runtime["scenarios"]) != release["evidence"]["runtime_scenarios"]:
        errors.append("runtime scenario count differs from release manifest")
    if len(formats["artifacts"]) != release["evidence"]["data_format_artifacts"]:
        errors.append("data-format artifact count differs from release manifest")
    for relative in release["required_documents"]:
        if not (project_root / relative).is_file():
            errors.append(f"required release document is missing: {relative}")

    errors.extend(validate_roadmap((project_root / "docs" / "roadmap.md").read_text(encoding="utf-8")))
    tracked = git_lines(project_root, "ls-files")
    prohibited = {extension.lower() for extension in release["prohibited_tracked_extensions"]}
    for relative in tracked:
        path = Path(relative)
        if path.suffix.lower() in prohibited:
            errors.append(f"proprietary/build payload is tracked: {relative}")
        if relative.replace("\\", "/").startswith("assets/generated/"):
            errors.append(f"generated asset is tracked: {relative}")
    reachable_paths = []
    for record in git_lines(project_root, "rev-list", "--objects", "--all"):
        _, separator, relative = record.partition(" ")
        if separator:
            reachable_paths.append(relative)
    for relative in reachable_paths:
        path = Path(relative)
        if path.suffix.lower() in prohibited:
            errors.append(f"proprietary/build payload remains in reachable history: {relative}")
        if relative.replace("\\", "/").startswith("assets/generated/"):
            errors.append(f"generated asset remains in reachable history: {relative}")

    makefile = (project_root / "Makefile").read_text(encoding="utf-8")
    for target in release["release_commands"]:
        if re.search(rf"^{re.escape(target)}\s*:", makefile, re.MULTILINE) is None:
            errors.append(f"release command has no Make target: {target}")
    for tool in ("ca65", "ld65"):
        expected_version = release["toolchain"][tool]
        actual_version = tool_version(project_root / "bin" / f"{tool}.exe")
        if expected_version not in actual_version:
            errors.append(f"unexpected {tool} version: {actual_version!r}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument(
        "--manifest", type=Path,
        default=Path(__file__).resolve().parent.parent / "config" / "preservation_source_1_0.json",
    )
    args = parser.parse_args()
    project_root = args.project_root.resolve()
    errors = validate_release(project_root, args.manifest.resolve())
    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        print(f"[FAIL] Preservation Source 1.0 audit found {len(errors)} error(s)")
        return 1
    print("[OK] Preservation Source 1.0 manifest, history policy, tools, docs, and evidence agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
