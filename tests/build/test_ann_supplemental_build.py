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

        ann_metatile_graphics = bytes(
            (index * 17 + 6) & 0xFF for index in range(408)
        )
        ann_music_data = bytes((index * 19 + 7) & 0xFF for index in range(1546))
        primary_enemy_streams = bytes(
            (index * 23 + 8) & 0xFF for index in range(566)
        )
        primary_area_streams = bytes(
            (index * 29 + 9) & 0xFF for index in range(1987)
        )
        primary_guest_chr = bytes(
            (index * 31 + 10) & 0xFF for index in range(384)
        )
        primary_payload = bytearray(32768)
        primary_payload[2695:3103] = ann_metatile_graphics
        primary_payload[26437:27003] = primary_enemy_streams
        primary_payload[27003:28990] = primary_area_streams
        primary_payload[28990:29374] = primary_guest_chr
        primary_payload[31216:32762] = ann_music_data
        primary_payload = bytes(primary_payload)

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
        ending_payload = bytes((index * 37 + 11) & 0xFF for index in range(3346))

        image = (
            bytes((1,))
            + bytes(55)
            + bytes((2, 4))
            + fds_file(5, b"NSMMAIN", 0x6000, primary_payload)
            + fds_file(32, b"NSMDATA2", 0xC470, supplemental_payload)
            + fds_file(48, b"NSMDATA3", 0xC5D0, ending_payload)
            + fds_file(64, b"NSMDATA4", 0xC296, hard_payload)
            + bytes(10)
        )
        template = (
            bytes((1,))
            + bytes(55)
            + bytes((2, 4))
            + fds_file(5, b"NSMMAIN", 0x6000, bytes(len(primary_payload)))
            + fds_file(32, b"NSMDATA2", 0xC470, bytes(len(supplemental_payload)))
            + fds_file(48, b"NSMDATA3", 0xC5D0, bytes(len(ending_payload)))
            + fds_file(64, b"NSMDATA4", 0xC296, bytes(len(hard_payload)))
            + bytes(10)
        )

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            clone = root / "project"
            clone.mkdir()
            shutil.copy2(PROJECT_ROOT / "Makefile", clone / "Makefile")
            (clone / "assets").mkdir()
            shutil.copy2(
                PROJECT_ROOT / "assets" / "manifest.json",
                clone / "assets" / "manifest.json",
            )
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
                    "name": "ann_metatile_graphics",
                    "payload": "NSMMAIN",
                    "offset": 2695,
                    "size": len(ann_metatile_graphics),
                    "sha1": sha1(ann_metatile_graphics),
                },
                {
                    "name": "ann_music_data",
                    "payload": "NSMMAIN",
                    "offset": 31216,
                    "size": len(ann_music_data),
                    "sha1": sha1(ann_music_data),
                },
                {
                    "name": "primary_course_enemy_streams",
                    "payload": "NSMMAIN",
                    "offset": 26437,
                    "size": len(primary_enemy_streams),
                    "sha1": sha1(primary_enemy_streams),
                },
                {
                    "name": "primary_course_area_streams",
                    "payload": "NSMMAIN",
                    "offset": 27003,
                    "size": len(primary_area_streams),
                    "sha1": sha1(primary_area_streams),
                },
                {
                    "name": "guest_chr",
                    "payload": "NSMMAIN",
                    "offset": 28990,
                    "size": len(primary_guest_chr),
                    "sha1": sha1(primary_guest_chr),
                },
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
                "primary_payload": "NSMMAIN",
                "verified_payloads": [
                    {
                        "name": "NSMMAIN",
                        "size": len(primary_payload),
                        "sha1": sha1(primary_payload),
                        "records": [
                            {
                                "file_id": 5,
                                "load_address": 0x6000,
                                "size": len(primary_payload),
                                "file_type": 0,
                            }
                        ],
                    },
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
                        "name": "NSMDATA3",
                        "size": len(ending_payload),
                        "sha1": sha1(ending_payload),
                        "records": [
                            {
                                "file_id": 48,
                                "load_address": 0xC5D0,
                                "size": len(ending_payload),
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
                    source_assets[5:8],
                    (enemy_streams, area_streams, guest_chr),
                ),
                (
                    "build-ann-hard-courses",
                    clone / "build" / "platforms" / "ann_hard_courses",
                    len(hard_payload),
                    source_assets[8:],
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

            shutil.rmtree(clone / "build")
            shutil.rmtree(clone / "assets" / "generated")
            base_asset_dir = clone / "assets" / "generated" / "source"
            base_asset_dir.mkdir(parents=True)
            for name, size in (
                ("base_course_enemy_streams.bin", 1087),
                ("base_course_area_streams.bin", 3373),
                ("base_music_data.bin", 1602),
                ("base_area_palette_packets.bin", 176),
                ("base_metatile_graphics.bin", 404),
            ):
                (base_asset_dir / name).write_bytes(bytes(size))

            result = subprocess.run(
                [
                    make,
                    "build-platform",
                    "PLATFORM=ann_fds",
                    make_assignment("ANN_REFERENCE", reference),
                    make_assignment("PLATFORM_REFERENCE", reference),
                    make_assignment("PLATFORM_MANIFEST", manifest),
                ],
                cwd=clone,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                (clone / "build" / "platforms" / "ann_fds" / "smb.prg").stat().st_size,
                len(primary_payload),
            )
            self.assertEqual(
                (clone / "build" / "platforms" / "ann_fds" / "smb.fds").stat().st_size,
                len(image),
            )
            self.assertEqual(
                (asset_dir.parent / "template.fds").read_bytes(), template
            )
            for item in source_assets:
                self.assertTrue((asset_dir / f"{item['name']}.bin").is_file())


if __name__ == "__main__":
    unittest.main()
