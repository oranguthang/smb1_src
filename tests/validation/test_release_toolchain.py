from __future__ import annotations

import hashlib
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from validation.check_release_toolchain import verify_file


class ReleaseToolchainTests(unittest.TestCase):
    def test_verify_file_accepts_exact_size_and_hash(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tool.bin"
            payload = b"pinned tool"
            path.write_bytes(payload)
            component = {
                "id": "tool",
                "size": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
            }
            self.assertEqual(verify_file(path, component), [])

    def test_verify_file_rejects_replacement(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tool.bin"
            path.write_bytes(b"replacement")
            component = {"id": "tool", "size": 1, "sha256": "0" * 64}
            errors = verify_file(path, component)
            self.assertIn("tool size differs", errors)
            self.assertIn("tool SHA-256 differs", errors)


if __name__ == "__main__":
    unittest.main()
