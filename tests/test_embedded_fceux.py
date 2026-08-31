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

            destination.write_text(
                '"eoptions" 0\nkeep 9\ninput-config 42\n',
                encoding="utf-8",
            )
            EmbeddedFceux._prepare_config(executable, output)
            self.assertEqual(
                destination.read_text(encoding="utf-8"),
                '"eoptions" 65536\nkeep 9\ninput-config 42\n',
            )

    def test_input_configuration_uses_the_native_fceux_command(self) -> None:
        class Host:
            def __init__(self) -> None:
                self.jobs = []

            def after(self, delay, callback):
                self.jobs.append((delay, callback))
                return "input-dialog-job"

        class Process:
            @staticmethod
            def poll():
                return None

        class User32:
            def __init__(self) -> None:
                self.messages = []
                self.parents = []
                self.styles = []

            @staticmethod
            def ShowWindow(*_arguments):
                return True

            def SetParent(self, *arguments):
                self.parents.append(arguments)
                return 0

            def SetWindowLongPtrW(self, *arguments):
                self.styles.append(arguments)
                return 0

            @staticmethod
            def SetWindowPos(*_arguments):
                return True

            def PostMessageW(self, *arguments):
                self.messages.append(arguments)
                return True

        statuses = []
        emulator = object.__new__(EmbeddedFceux)
        emulator.process = Process()
        emulator.window = 42
        emulator.status = statuses.append
        emulator.host = Host()
        emulator.input_dialog_job = None
        emulator.input_dialog_seen = False
        emulator.input_dialog_polls = 0
        emulator.top_level_style = 0x1234
        emulator.top_level_exstyle = 0x5678
        user32 = User32()
        with patch.object(emulator, "_user32", return_value=user32):
            emulator.configure_input()

        self.assertEqual(
            user32.messages,
            [(42, EmbeddedFceux.WM_COMMAND, EmbeddedFceux.MENU_INPUT, 0)],
        )
        self.assertEqual(user32.parents, [(42, 0)])
        self.assertEqual(
            user32.styles,
            [
                (42, EmbeddedFceux.GWL_STYLE, 0x1234),
                (42, EmbeddedFceux.GWL_EXSTYLE, 0x5678),
            ],
        )
        self.assertEqual(emulator.host.jobs[0][0], 50)
        self.assertEqual(emulator.input_dialog_job, "input-dialog-job")
        self.assertEqual(statuses, ["Opening FCEUX input configuration"])

    def test_input_dialog_reembeds_fceux_after_the_modal_window_closes(self) -> None:
        class Host:
            @staticmethod
            def after(_delay, _callback):
                return "next-poll"

        class Process:
            @staticmethod
            def poll():
                return None

        class User32:
            def __init__(self) -> None:
                self.enabled = False

            @staticmethod
            def GetWindow(_window, _command):
                return 99

            @staticmethod
            def ShowWindow(_window, _command):
                return True

            @staticmethod
            def SetForegroundWindow(_window):
                return True

            def IsWindowEnabled(self, _window):
                return self.enabled

        statuses = []
        emulator = object.__new__(EmbeddedFceux)
        emulator.host = Host()
        emulator.process = Process()
        emulator.window = 42
        emulator.status = statuses.append
        emulator.input_dialog_job = "current-poll"
        emulator.input_dialog_seen = False
        emulator.input_dialog_polls = 0
        user32 = User32()
        with (
            patch.object(emulator, "_user32", return_value=user32),
            patch.object(emulator, "_embed") as embed,
        ):
            emulator._poll_input_dialog()
            self.assertTrue(emulator.input_dialog_seen)
            self.assertEqual(emulator.input_dialog_job, "next-poll")
            embed.assert_not_called()

            user32.enabled = True
            emulator._poll_input_dialog()
            embed.assert_called_once_with()

        self.assertEqual(statuses, ["Playtest running; FCEUX controls applied"])


if __name__ == "__main__":
    unittest.main()
