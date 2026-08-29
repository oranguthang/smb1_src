from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from audit_enemy_streams import audit_artifact, read_stream  # noqa: E402


class EnemyStreamAuditTests(unittest.TestCase):
    def test_read_stream_requires_an_in_bounds_terminator(self) -> None:
        self.assertEqual(read_stream(bytes.fromhex("1020ff30"), 0), bytes.fromhex("1020ff"))
        with self.assertRaisesRegex(ValueError, "outside"):
            read_stream(b"\xff", 1)
        with self.assertRaisesRegex(ValueError, "terminator"):
            read_stream(b"\x10\x20", 0)

    def test_labeled_audit_reports_forbidden_non_entrance_records(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "stream.bin").write_bytes(bytes.fromhex("002e0e2e00ff"))
            (root / "stream.lbl").write_text(
                "al 008000 .off_test_enemies\n",
                encoding="utf-8",
            )
            artifact = {
                "id": "test",
                "kind": "labeled_streams",
                "binary": "stream.bin",
                "labels": "stream.lbl",
                "load_address": "0x8000",
                "label_pattern": "^off_test_enemies$",
                "expected_streams": 1,
                "expected_records": 2,
            }
            result = audit_artifact(root, artifact, {0x2E})
            self.assertEqual(len(result["forbidden_records"]), 1)
            self.assertEqual(result["forbidden_records"][0]["kind"], "enemy")


if __name__ == "__main__":
    unittest.main()
