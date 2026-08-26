from __future__ import annotations

import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from fixed_variant import verify_bytes


class FixedVariantTests(unittest.TestCase):
    def test_accepts_exact_declared_difference(self) -> None:
        changes = [{"offset": "0x1", "original": "0x20", "replacement": "0x21"}]
        verify_bytes(bytes([0x10, 0x20, 0x30]), bytes([0x10, 0x21, 0x30]), changes)

    def test_rejects_undeclared_difference(self) -> None:
        changes = [{"offset": "0x1", "original": "0x20", "replacement": "0x21"}]
        with self.assertRaisesRegex(ValueError, "unexpected"):
            verify_bytes(bytes([0x10, 0x20, 0x30]), bytes([0x11, 0x21, 0x30]), changes)

    def test_rejects_changed_layout(self) -> None:
        with self.assertRaisesRegex(ValueError, "size changed"):
            verify_bytes(b"abc", b"abcd", [])


if __name__ == "__main__":
    unittest.main()
