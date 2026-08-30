from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from validate_smb2_overlays import (  # noqa: E402
    checked_signature,
    overlay_plans,
    relocated_payloads,
)


class Smb2OverlayRuntimeTests(unittest.TestCase):
    def test_overlay_plan_covers_every_non_primary_payload_once(self) -> None:
        profile = {
            "primary_payload": "SM2MAIN",
            "verified_payloads": [
                {"name": "SM2MAIN"},
                {"name": "SM2DATA2"},
            ],
            "runtime": {
                "overlay_loads": [{
                    "name": "SM2DATA2",
                    "mode": 1,
                    "mode_task": 0,
                    "disk_task": 1,
                    "file_list": 0,
                    "world": 4,
                    "hard_world": 0,
                    "expected_disk_task": 0,
                    "timeout_frames": 600,
                }]
            },
        }
        self.assertEqual(overlay_plans(profile)[0]["name"], "SM2DATA2")

    def test_overlay_plan_rejects_incomplete_coverage(self) -> None:
        profile = {
            "primary_payload": "SM2MAIN",
            "verified_payloads": [
                {"name": "SM2MAIN"},
                {"name": "SM2DATA2"},
                {"name": "SM2DATA3"},
            ],
            "runtime": {
                "overlay_loads": [{
                    "name": "SM2DATA2",
                    **{field: 0 for field in (
                        "mode", "mode_task", "disk_task", "file_list", "world",
                        "hard_world", "expected_disk_task", "timeout_frames",
                    )},
                }]
            },
        }
        with self.assertRaisesRegex(ValueError, "must cover exactly"):
            overlay_plans(profile)

    def test_signature_is_derived_from_verified_payload(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = bytes(range(32))
            (root / "SM2DATA2.bin").write_bytes(data)
            payload = {
                "name": "SM2DATA2",
                "size": len(data),
                "sha1": hashlib.sha1(data).hexdigest(),
                "records": [{"load_address": 0xc470}],
            }
            address, signature = checked_signature(root, payload)
            self.assertEqual(address, 0xc470)
            self.assertEqual(signature, data[:16].hex())

    def test_signature_skips_prefix_already_present_in_primary_payload(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            primary_data = bytes(range(64))
            overlay_data = bytearray(primary_data[16:48])
            overlay_data[20] = 0xff
            (root / "SM2MAIN.bin").write_bytes(primary_data)
            (root / "SM2DATA4.bin").write_bytes(overlay_data)
            primary = {
                "name": "SM2MAIN",
                "size": len(primary_data),
                "sha1": hashlib.sha1(primary_data).hexdigest(),
                "records": [{"load_address": 0x6000}],
            }
            overlay = {
                "name": "SM2DATA4",
                "size": len(overlay_data),
                "sha1": hashlib.sha1(overlay_data).hexdigest(),
                "records": [{"load_address": 0x6010}],
            }
            address, signature = checked_signature(root, overlay, primary)
            self.assertLessEqual(address, 0x6010 + 20)
            self.assertIn("ff", signature)

    def test_relocation_summary_supplies_candidate_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = root / "smb2.fds"
            image.write_bytes(b"candidate")
            summary = root / "summary.json"
            summary.write_text(json.dumps({
                "candidate_image_sha1": hashlib.sha1(b"candidate").hexdigest(),
                "candidate_payload_sha1": {
                    "SM2MAIN": "main-candidate",
                    "SM2DATA2": "overlay-candidate",
                },
            }), encoding="utf-8")
            profile = {
                "verified_payloads": [
                    {"name": "SM2MAIN", "sha1": "main-baseline"},
                    {"name": "SM2DATA2", "sha1": "overlay-baseline"},
                ]
            }
            payloads = relocated_payloads(profile, summary, image)
            self.assertEqual(payloads["SM2MAIN"]["sha1"], "main-candidate")
            self.assertEqual(payloads["SM2DATA2"]["sha1"], "overlay-candidate")


if __name__ == "__main__":
    unittest.main()
