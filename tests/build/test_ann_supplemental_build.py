from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def fds_file(file_id: int, name: bytes, load_address: int, data: bytes) -> bytes:
    header = bytes((3, 0, file_id))
    header += name.ljust(8, b" ")[:8]
    header += load_address.to_bytes(2, "little")
    header += len(data).to_bytes(2, "little")
    header += bytes((0,))
    return header + bytes((4,)) + data


class AnnSupplementalBuildTests(unittest.TestCase):
    def test_make_targets_prepare_assets_before_real_assembly(self) -> None:
        make = shutil.which("make")
        if make is None:
            self.skipTest("GNU Make is required for the public build integration test")

        enemy_streams = bytes((index * 3 + 1) & 0xFF for index in range(680))
        area_streams = bytes((index * 5 + 2) & 0xFF for index in range(2263))
        guest_chr = bytes((index * 7 + 3) & 0xFF for index in range(288))
        supplemental_payload = bytearray(3584)
        supplemental_payload[352:1032] = enemy_streams
        supplemental_payload[1032:3295] = area_streams
        supplemental_payload[3295:3583] = guest_chr
        supplemental_payload = bytes(supplemental_payload)

        extended_enemy_streams = bytes(
            (index * 11 + 4) & 0xFF for index in range(654)
        )
        extended_area_streams = bytes(
            (index * 13 + 5) & 0xFF for index in range(2009)
        )
        hard_payload = bytearray(3568)
        hard_payload[826:1480] = extended_enemy_streams
        hard_payload[1480:3489] = extended_area_streams
        hard_payload = bytes(hard_payload)

        image = (
            bytes((1,))
            + bytes(55)
            + bytes((2, 2))
            + fds_file(32, b"NSMDATA2", 0xC470, supplemental_payload)
            + fds_file(64, b"NSMDATA4", 0xC296, hard_payload)
            + bytes(10)
        )
        template = (
            bytes((1,))
            + bytes(55)
            + bytes((2, 2))
            + fds_file(32, b"NSMDATA2", 0xC470, bytes(len(supplemental_payload)))
            + fds_file(64, b"NSMDATA4", 0xC296, bytes(len(hard_payload)))
            + bytes(10)
        )

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            clone = root / "project"
            clone.mkdir()
            shutil.copy2(PROJECT_ROOT / "Makefile", clone / "Makefile")
            for name in ("mk", "scripts", "src", "config", "bin"):
                shutil.copytree(
                    PROJECT_ROOT / name,
                    clone / name,
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
                )

            reference = clone / "ann-reference.fds"
            manifest = clone / "config" / "test_ann_platform_profiles.json"
            asset_dir = clone / "assets" / "generated" / "platforms" / "ann_fds" / "source"
            reference.write_bytes(image)

            source_assets = [
                {
                    "name": "supplemental_course_enemy_streams",
                    "payload": "NSMDATA2",
                    "offset": 352,
                    "size": len(enemy_streams),
                    "sha1": sha1(enemy_streams),
                },
                {
                    "name": "supplemental_course_area_streams",
                    "payload": "NSMDATA2",
                    "offset": 1032,
                    "size": len(area_streams),
                    "sha1": sha1(area_streams),
                },
                {
                    "name": "supplemental_guest_chr",
                    "payload": "NSMDATA2",
                    "offset": 3295,
                    "size": len(guest_chr),
                    "sha1": sha1(guest_chr),
                },
                {
                    "name": "extended_course_enemy_streams",
                    "payload": "NSMDATA4",
                    "offset": 826,
                    "size": len(extended_enemy_streams),
                    "sha1": sha1(extended_enemy_streams),
                },
                {
                    "name": "extended_course_area_streams",
                    "payload": "NSMDATA4",
                    "offset": 1480,
                    "size": len(extended_area_streams),
                    "sha1": sha1(extended_area_streams),
                },
            ]

            profile = {
                "id": "ann_fds",
                "format": "fds_raw_side",
                "disk_size": len(image),
                "disk_sha1": sha1(image),
                "template_sha1": sha1(template),
                "primary_payload": "NSMDATA2",
                "verified_payloads": [
                    {
                        "name": "NSMDATA2",
                        "size": len(supplemental_payload),
                        "sha1": sha1(supplemental_payload),
                        "records": [
                            {
                                "file_id": 32,
                                "load_address": 0xC470,
                                "size": len(supplemental_payload),
                                "file_type": 0,
                            }
                        ],
                    },
                    {
                        "name": "NSMDATA4",
                        "size": len(hard_payload),
                        "sha1": sha1(hard_payload),
                        "records": [
                            {
                                "file_id": 64,
                                "load_address": 0xC296,
                                "size": len(hard_payload),
                                "file_type": 0,
                            }
                        ],
                    }
                ],
                "source_assets": source_assets,
            }
            manifest.write_text(
                json.dumps({"schema_version": 1, "profiles": [profile]}),
                encoding="utf-8",
            )

            def make_assignment(name: str, path: Path) -> str:
                return f"{name}={path.as_posix()}"

            cases = (
                (
                    "build-ann-supplemental-courses",
                    clone / "build" / "platforms" / "ann_supplemental_courses",
                    len(supplemental_payload),
                    source_assets[:3],
                    (enemy_streams, area_streams, guest_chr),
                ),
                (
                    "build-ann-hard-courses",
                    clone / "build" / "platforms" / "ann_hard_courses",
                    len(hard_payload),
                    source_assets[3:],
                    (extended_enemy_streams, extended_area_streams),
                ),
            )
            for target, build_dir, payload_size, assets, expected_assets in cases:
                with self.subTest(target=target):
                    if asset_dir.exists():
                        shutil.rmtree(asset_dir)
                    self.assertFalse(asset_dir.exists())
                    result = subprocess.run(
                        [
                            make,
                            target,
                            make_assignment("ANN_REFERENCE", reference),
                            make_assignment("PLATFORM_MANIFEST", manifest),
                        ],
                        cwd=clone,
                        capture_output=True,
                        text=True,
                        encoding="utf-8",
                    )
                    self.assertEqual(
                        result.returncode, 0, result.stdout + result.stderr
                    )
                    self.assertEqual(
                        (build_dir / "payload.bin").stat().st_size, payload_size
                    )
                    for item, expected in zip(
                        assets, expected_assets, strict=True
                    ):
                        self.assertEqual(
                            (asset_dir / f"{item['name']}.bin").read_bytes(),
                            expected,
                        )


if __name__ == "__main__":
    unittest.main()
