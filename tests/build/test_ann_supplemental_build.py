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
    def test_make_target_prepares_assets_before_real_assembly(self) -> None:
        make = shutil.which("make")
        if make is None:
            self.skipTest("GNU Make is required for the public build integration test")

        enemy_streams = bytes((index * 3 + 1) & 0xFF for index in range(680))
        area_streams = bytes((index * 5 + 2) & 0xFF for index in range(2263))
        guest_chr = bytes((index * 7 + 3) & 0xFF for index in range(288))
        payload = bytearray(3584)
        payload[352:1032] = enemy_streams
        payload[1032:3295] = area_streams
        payload[3295:3583] = guest_chr
        payload = bytes(payload)
        image = (
            bytes((1,))
            + bytes(55)
            + bytes((2, 1))
            + fds_file(32, b"NSMDATA2", 0xC470, payload)
            + bytes(10)
        )
        template = bytearray(image)
        data_offset = 56 + 2 + 16 + 1
        template[data_offset : data_offset + len(payload)] = bytes(len(payload))

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
            build_dir = clone / "build" / "platforms" / "ann_supplemental_courses"
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
            ]

            profile = {
                "id": "ann_fds",
                "format": "fds_raw_side",
                "disk_size": len(image),
                "disk_sha1": sha1(image),
                "template_sha1": sha1(bytes(template)),
                "primary_payload": "NSMDATA2",
                "verified_payloads": [
                    {
                        "name": "NSMDATA2",
                        "size": len(payload),
                        "sha1": sha1(payload),
                        "records": [
                            {
                                "file_id": 32,
                                "load_address": 0xC470,
                                "size": len(payload),
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

            self.assertFalse(asset_dir.exists())
            result = subprocess.run(
                [
                    make,
                    "build-ann-supplemental-courses",
                    make_assignment("ANN_REFERENCE", reference),
                    make_assignment("PLATFORM_MANIFEST", manifest),
                ],
                cwd=clone,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((build_dir / "payload.bin").stat().st_size, 3584)
            for item, expected in zip(
                source_assets,
                (enemy_streams, area_streams, guest_chr),
                strict=True,
            ):
                self.assertEqual(
                    (asset_dir / f"{item['name']}.bin").read_bytes(), expected
                )


if __name__ == "__main__":
    unittest.main()
