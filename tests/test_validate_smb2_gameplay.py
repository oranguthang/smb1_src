from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from validate_smb2_gameplay import gameplay_environment  # noqa: E402


class Smb2GameplayTests(unittest.TestCase):
    def test_environment_is_derived_from_manifest_contract(self) -> None:
        runtime = {
            "frame": 1200,
            "gameplay": {
                "boot_task": 4,
                "ready_mode": 1,
                "ready_task": 4,
                "ready_engine": 7,
                "ready_timeout_frames": 900,
                "run_frames": 360,
                "minimum_active_frames": 300,
                "minimum_progress_pixels": 64,
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            result = Path(directory) / "result.txt"
            environment = gameplay_environment(runtime, result, ["0x6000"])
        self.assertEqual(environment["SMB2_GAMEPLAY_BOOT_TASK"], "4")
        self.assertEqual(environment["SMB2_GAMEPLAY_RUN_FRAMES"], "360")
        self.assertEqual(environment["SMB_RUNTIME_FORBID_EXECUTE"], "0x6000")

    def test_incomplete_contract_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "lacks"):
            gameplay_environment({"frame": 1, "gameplay": {}}, Path("x"), [])


if __name__ == "__main__":
    unittest.main()
