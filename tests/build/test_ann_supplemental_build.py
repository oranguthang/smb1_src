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

        enemy_streams = b"ENY"
        area_streams = b"AREA"
        guest_chr = b"GC"
        payload = enemy_streams + area_streams + guest_chr
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
            reference = root / "reference.fds"
            manifest = root / "profiles.json"
            source = root / "supplemental.asm"
            config = root / "supplemental.cfg"
            asset_dir = root / "assembly_assets"
            redirected_platform_assets = root / "redirected_platform_assets"
            build_dir = root / "build"
            reference.write_bytes(image)

            source_assets = []
            offset = 0
            for name, data in (
                ("supplemental_course_enemy_streams", enemy_streams),
                ("supplemental_course_area_streams", area_streams),
                ("supplemental_guest_chr", guest_chr),
            ):
                source_assets.append(
                    {
                        "name": name,
                        "payload": "NSMDATA2",
                        "offset": offset,
                        "size": len(data),
                        "sha1": sha1(data),
                    }
                )
                offset += len(data)

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

            include_lines = []
            for item in source_assets:
                asset_path = asset_dir / f"{item['name']}.bin"
                include_lines.append(f'.incbin "{asset_path.as_posix()}"')
            source.write_text(
                '.segment "OVERLAY"\n' + "\n".join(include_lines) + "\n",
                encoding="utf-8",
            )
            config.write_text(
                "MEMORY { ROM: file = %O, start = $C470, size = $0009; }\n"
                "SEGMENTS { OVERLAY: load = ROM, type = ro; }\n",
                encoding="utf-8",
            )

            def make_assignment(name: str, path: Path) -> str:
                return f"{name}={path.as_posix()}"

            result = subprocess.run(
                [
                    make,
                    "build-ann-supplemental-courses",
                    make_assignment("ANN_REFERENCE", reference),
                    make_assignment("PLATFORM_MANIFEST", manifest),
                    make_assignment("PLATFORM_ASSET_DIR", redirected_platform_assets),
                    make_assignment("ANN_SUPPLEMENTAL_ASSET_DIR", asset_dir),
                    make_assignment("ANN_SUPPLEMENTAL_COURSES_SOURCE", source),
                    make_assignment("ANN_SUPPLEMENTAL_COURSES_CFG", config),
                    make_assignment("ANN_SUPPLEMENTAL_COURSES_BUILD_DIR", build_dir),
                ],
                cwd=PROJECT_ROOT,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                (build_dir / "payload.bin").read_bytes(),
                payload,
            )
            for item, expected in zip(
                source_assets,
                (enemy_streams, area_streams, guest_chr),
                strict=True,
            ):
                self.assertEqual(
                    (asset_dir / f"{item['name']}.bin").read_bytes(), expected
                )
            self.assertFalse(redirected_platform_assets.exists())


if __name__ == "__main__":
    unittest.main()
