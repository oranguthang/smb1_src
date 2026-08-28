from __future__ import annotations

import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from verify_platform_range import verify_range


class VerifyPlatformRangeTests(unittest.TestCase):
    def test_accepts_exact_cpu_address_slice(self) -> None:
        verify_range(b"ABCDEFGH", b"CDE", 0x6000, 0x6002, 0x6005)

    def test_rejects_candidate_size_mismatch(self) -> None:
        with self.assertRaisesRegex(ValueError, "candidate size mismatch"):
            verify_range(b"ABCDEFGH", b"CD", 0x6000, 0x6002, 0x6005)

    def test_reports_first_differing_cpu_address(self) -> None:
        with self.assertRaisesRegex(ValueError, r"CPU \$6003"):
            verify_range(b"ABCDEFGH", b"CXE", 0x6000, 0x6002, 0x6005)

    def test_rejects_range_outside_payload(self) -> None:
        with self.assertRaisesRegex(ValueError, "outside the reference payload"):
            verify_range(b"ABCDEFGH", b"", 0x6000, 0x5FFF, 0x6000)


if __name__ == "__main__":
    unittest.main()
