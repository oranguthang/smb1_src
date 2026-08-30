from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from emulator_image import prepare_emulator_image  # noqa: E402
from studio_common import profile_rgb  # noqa: E402


class EmulatorImageTests(unittest.TestCase):
    def test_vs_palette_uses_the_rp2c04_0004_color_wiring(self) -> None:
        rgb = profile_rgb({"ppu": {"model": "rp2c04_0004"}})
        self.assertEqual(rgb[0x1A], "#5d96ff")
        self.assertEqual(rgb[0x14], "#000000")
        self.assertEqual(rgb[0x3C], "#82d310")

    def test_vs_playtest_image_declares_its_ppu_without_touching_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "canonical.nes"
            output = root / "playtest.nes"
            original = bytearray(b"NES\x1a" + bytes(12) + bytes(range(32)))
            original[6] = 0x39
            original[7] = 0x60
            source.write_bytes(original)
            result = prepare_emulator_image(
                source,
                output,
                {"ppu": {"nes2_vs_ppu_id": 5}},
            )
            prepared = result.read_bytes()
            self.assertEqual(source.read_bytes(), original)
            self.assertEqual(prepared[7], 0x69)
            self.assertEqual(prepared[13], 0x05)
            self.assertEqual(prepared[16:], original[16:])

    def test_regular_profile_uses_the_canonical_image(self) -> None:
        source = Path("canonical.nes")
        self.assertEqual(
            prepare_emulator_image(source, Path("unused.nes"), {}),
            source,
        )


if __name__ == "__main__":
    unittest.main()
