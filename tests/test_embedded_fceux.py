from __future__ import annotations

import ctypes
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from embedded_fceux import EmbeddedFceux  # noqa: E402


@unittest.skipUnless(sys.platform == "win32", "Native FCEUX embedding is Windows-only")
class EmbeddedFceuxTests(unittest.TestCase):
    def test_resize_fits_child_to_the_exact_host_client_area(self) -> None:
        from ctypes import wintypes

        class Host:
            @staticmethod
            def winfo_id() -> int:
                return 7

            @staticmethod
            def winfo_width() -> int:
                return 1000

            @staticmethod
            def winfo_height() -> int:
                return 700

        class User32:
            def __init__(self) -> None:
                self.positions = []

            @staticmethod
            def GetClientRect(window, rectangle_pointer):
                self.assertEqual(window, 7)
                rectangle = ctypes.cast(
                    rectangle_pointer,
                    ctypes.POINTER(wintypes.RECT),
                ).contents
                rectangle.right = 1000
                rectangle.bottom = 700
                return True

            def SetWindowPos(self, *arguments):
                self.positions.append(arguments)

        emulator = object.__new__(EmbeddedFceux)
        emulator.host = Host()
        emulator.window = 42
        user32 = User32()
        with patch.object(emulator, "_user32", return_value=user32):
            emulator.resize()

        self.assertEqual(len(user32.positions), 1)
        self.assertEqual(user32.positions[0][2:6], (127, 0, 746, 700))

    def test_game_rectangle_centers_pillarbox_and_letterbox_bars(self) -> None:
        self.assertEqual(
            EmbeddedFceux._fit_game_rectangle(1000, 700),
            (127, 0, 746, 700),
        )
        self.assertEqual(
            EmbeddedFceux._fit_game_rectangle(600, 900),
            (0, 169, 600, 562),
        )

    def test_embedded_config_enables_best_fit_without_changing_user_config(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / "fceux64.exe"
            source = root / "fceux.cfg"
            output = root / "build"
            executable.write_bytes(b"")
            source.write_text('"eoptions" 1196161\nkeep 7\n', encoding="utf-8")
            output.mkdir()

            destination = EmbeddedFceux._prepare_config(executable, output)

            self.assertEqual(source.read_text(encoding="utf-8"), '"eoptions" 1196161\nkeep 7\n')
            self.assertEqual(
                destination.read_text(encoding="utf-8"),
                '"eoptions" 196737\nkeep 7\n',
            )


if __name__ == "__main__":
    unittest.main()
