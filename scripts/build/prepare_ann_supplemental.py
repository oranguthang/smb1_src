#!/usr/bin/env python3
"""Prepare validated private assets required by ANN source builds."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from build.platform_profiles import (
    atomic_write,
    extract_fds_payloads,
    extract_source_assets,
    load_profile,
    make_fds_template,
)


REQUIRED_ASSETS = (
    "ann_metatile_graphics",
    "ann_music_data",
    "primary_course_enemy_streams",
    "primary_course_area_streams",
    "guest_chr",
    "supplemental_course_enemy_streams",
    "supplemental_course_area_streams",
    "supplemental_guest_chr",
)


def prepare_assets(
    manifest: Path,
    profile_id: str,
    reference: Path,
    output_dir: Path,
) -> None:
    """Validate the private disk and write the build-owned source assets."""
    profile = load_profile(manifest, profile_id)
    if profile_id != "ann_fds" or profile.get("format") != "fds_raw_side":
        raise ValueError("ANN supplemental preparation requires the ann_fds profile")

    reference_data = reference.read_bytes()
    payloads = extract_fds_payloads(reference_data, profile)
    source_assets = extract_source_assets(payloads, profile)
    missing = [name for name in REQUIRED_ASSETS if name not in source_assets]
    if missing:
        raise ValueError(f"ANN supplemental source assets are missing: {', '.join(missing)}")

    for name, data in source_assets.items():
        atomic_write(output_dir / f"{name}.bin", data)
    atomic_write(output_dir.parent / "template.fds", make_fds_template(reference_data, profile))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    try:
        prepare_assets(args.manifest, args.profile, args.reference, args.output_dir)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc
    print(f"[OK] Prepared ANN source and container assets: {args.output_dir.parent}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
