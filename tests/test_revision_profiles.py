from __future__ import annotations

import hashlib
import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from revision_profiles import build_image, split_rom


class RevisionProfileTests(unittest.TestCase):
    def setUp(self) -> None:
        self.header = b"H" * 16
        self.prg = b"P" * 32
        self.chr = b"C" * 8
        self.extra = b"X" * 4
        self.rom = self.header + self.prg + self.chr + self.extra
        self.profile = {
            "id": "test",
            "rom_size": len(self.rom),
            "rom_sha1": hashlib.sha1(self.rom).hexdigest(),
        }
        for name, data in (
            ("header", self.header),
            ("prg", self.prg),
            ("chr", self.chr),
            ("extra", self.extra),
        ):
            self.profile[f"{name}_size"] = len(data)
            self.profile[f"{name}_sha1"] = hashlib.sha1(data).hexdigest()

    def test_splits_and_rebuilds_exact_profile(self) -> None:
        regions = split_rom(self.rom, self.profile)
        self.assertEqual(build_image(self.profile, *regions), self.rom)

    def test_rejects_wrong_private_reference(self) -> None:
        with self.assertRaisesRegex(ValueError, "private reference ROM"):
            split_rom(self.rom[:-1], self.profile)

    def test_rejects_component_substitution(self) -> None:
        with self.assertRaisesRegex(ValueError, "prg hash mismatch"):
            build_image(self.profile, self.header, b"Q" * 32, self.chr, self.extra)


if __name__ == "__main__":
    unittest.main()
