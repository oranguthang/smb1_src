from __future__ import annotations

import hashlib
import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from expanded_rom import build_image, verify_image


class ExpandedRomTests(unittest.TestCase):
    def setUp(self) -> None:
        self.prg = bytes([0x5A]) * 32_768
        self.chr = bytes([0xA5]) * 8_192
        self.manifest = {
            "schema_version": 1,
            "mapper": 3,
            "mirroring": "vertical",
            "prg_banks_16k": 2,
            "chr_banks_8k": 2,
            "prg_sha1": hashlib.sha1(self.prg).hexdigest(),
            "chr_bank_sha1": [hashlib.sha1(self.chr).hexdigest()] * 2,
        }

    def test_builds_reviewed_cnrom_layout(self) -> None:
        image = build_image(self.manifest, self.prg, self.chr)
        self.assertEqual(image[:8], b"NES\x1a\x02\x02\x31\x00")
        self.assertEqual(len(image), 16 + 32_768 + 16_384)
        verify_image(self.manifest, image, self.prg)

    def test_rejects_fixed_prg_change(self) -> None:
        image = bytearray(build_image(self.manifest, self.prg, self.chr))
        image[16 + 123] ^= 1
        with self.assertRaisesRegex(ValueError, "fixed CPU range differs"):
            verify_image(self.manifest, bytes(image), self.prg)


if __name__ == "__main__":
    unittest.main()
