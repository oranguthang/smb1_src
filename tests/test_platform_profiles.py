from __future__ import annotations

import hashlib
import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from platform_profiles import build_ines_image, split_ines_reference


class PlatformProfileTests(unittest.TestCase):
    def setUp(self) -> None:
        self.header = b"H" * 16
        self.prg = b"P" * 32
        self.chr_data = b"C" * 16
        self.image = self.header + self.prg + self.chr_data
        self.profile = {
            "id": "test",
            "format": "ines",
            "rom_size": len(self.image),
            "rom_sha1": hashlib.sha1(self.image).hexdigest(),
        }
        for name, data in (
            ("header", self.header),
            ("prg", self.prg),
            ("chr", self.chr_data),
        ):
            self.profile[f"{name}_size"] = len(data)
            self.profile[f"{name}_sha1"] = hashlib.sha1(data).hexdigest()

    def test_splits_and_rebuilds_exact_ines_profile(self) -> None:
        regions = split_ines_reference(self.image, self.profile)
        self.assertEqual(build_ines_image(self.profile, *regions), self.image)

    def test_rejects_wrong_private_reference(self) -> None:
        with self.assertRaisesRegex(ValueError, "private platform reference"):
            split_ines_reference(self.image[:-1], self.profile)

    def test_rejects_component_substitution(self) -> None:
        with self.assertRaisesRegex(ValueError, "prg hash mismatch"):
            build_ines_image(
                self.profile,
                self.header,
                b"Q" * len(self.prg),
                self.chr_data,
            )


if __name__ == "__main__":
    unittest.main()
