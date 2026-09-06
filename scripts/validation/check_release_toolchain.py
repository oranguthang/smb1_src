#!/usr/bin/env python3
"""Verify the pinned Source Reconstruction release toolchain and private BIOS."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resolve_path(project_root: Path, value: str | Path) -> Path:
    path = Path(value)
    return path if path.is_absolute() else (project_root / path).resolve()


def verify_file(path: Path, component: dict[str, Any]) -> list[str]:
    identifier = component.get("id", "unknown")
    if not path.is_file():
        return [f"{identifier} is missing: {path}"]
    errors: list[str] = []
    if path.stat().st_size != component.get("size"):
        errors.append(f"{identifier} size differs")
    if sha256(path) != str(component.get("sha256", "")).lower():
        errors.append(f"{identifier} SHA-256 differs")
    return errors


def verify_version(path: Path, expected: str, identifier: str) -> list[str]:
    result = subprocess.run(
        [str(path), "--version"],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    reported = "\n".join((result.stdout, result.stderr))
    if result.returncode != 0 or expected not in reported:
        return [f"{identifier} version differs from {expected}"]
    return []


def validate_toolchain(
    project_root: Path,
    manifest: dict[str, Any],
    *,
    fceux: Path | None = None,
    fds_bios: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    if manifest.get("schema_version") != 1:
        errors.append("release toolchain manifest schema differs")
        return errors

    components = manifest.get("components", [])
    identifiers = [item.get("id") for item in components]
    if identifiers != ["ca65", "ld65", "fceux", "fds_bios"]:
        errors.append("release toolchain component set differs")
        return errors

    for component in components:
        identifier = component["id"]
        override = fceux if identifier == "fceux" else fds_bios if identifier == "fds_bios" else None
        relative = component.get("path") or component.get("default_path")
        path = override.resolve() if override is not None else resolve_path(project_root, relative)
        errors.extend(verify_file(path, component))

        if component.get("kind") == "bundled_tool":
            for field in ("provenance", "license"):
                evidence = project_root / component.get(field, "")
                if not evidence.is_file():
                    errors.append(f"{identifier} {field} record is missing")
            errors.extend(verify_version(path, component.get("version", ""), identifier))

        if identifier == "fceux":
            repository = resolve_path(project_root, component.get("source_repository", ""))
            if not (repository / ".git").exists():
                errors.append(f"fceux source repository is missing: {repository}")
            else:
                result = subprocess.run(
                    ["git", "rev-parse", "HEAD"],
                    cwd=repository,
                    check=False,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                )
                if result.returncode != 0 or result.stdout.strip() != component.get("source_commit"):
                    errors.append("fceux source commit differs")

        if identifier == "fds_bios" and component.get("committed") is not False:
            errors.append("FDS BIOS must remain an uncommitted private input")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    project_root = Path(__file__).resolve().parents[2]
    parser.add_argument("--project-root", type=Path, default=project_root)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=project_root / "config" / "release_toolchain_3_0.json",
    )
    parser.add_argument("--fceux", type=Path)
    parser.add_argument("--fds-bios", type=Path)
    args = parser.parse_args()
    errors = validate_toolchain(
        args.project_root.resolve(),
        load_json(args.manifest.resolve()),
        fceux=args.fceux,
        fds_bios=args.fds_bios,
    )
    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        print(f"[FAIL] Release toolchain audit found {len(errors)} error(s)")
        return 1
    print("[OK] Source Reconstruction 3.0 toolchain matches pinned files and commits")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
