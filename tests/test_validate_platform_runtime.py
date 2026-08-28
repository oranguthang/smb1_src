from __future__ import annotations

import hashlib
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from validate_platform_runtime import validate_fds_bios


class PlatformRuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.directory = Path(self.temporary_directory.name)
        self.fceux = self.directory / "fceux.exe"
        self.fceux.write_bytes(b"emulator")
        self.bios = self.directory / "disksys.rom"
        self.bios.write_bytes(b"bios")
        self.runtime = {
            "fds_bios": {
                "size": 4,
                "sha1": hashlib.sha1(b"bios").hexdigest(),
            }
        }

    def test_accepts_matching_bios_next_to_fceux(self) -> None:
        validate_fds_bios(self.fceux, self.bios, self.runtime)

    def test_ignores_bios_for_non_fds_contract(self) -> None:
        validate_fds_bios(self.fceux, None, {})

    def test_rejects_wrong_bios_hash(self) -> None:
        self.bios.write_bytes(b"fail")
        with self.assertRaisesRegex(ValueError, "SHA1 mismatch"):
            validate_fds_bios(self.fceux, self.bios, self.runtime)

    def test_rejects_bios_outside_fceux_directory(self) -> None:
        other = self.directory / "private" / "disksys.rom"
        other.parent.mkdir()
        other.write_bytes(b"bios")
        with self.assertRaisesRegex(ValueError, "expects its FDS BIOS"):
            validate_fds_bios(self.fceux, other, self.runtime)


if __name__ == "__main__":
    unittest.main()
