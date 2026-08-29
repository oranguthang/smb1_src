from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from validate_revision_runtime import load_forbidden_addresses  # noqa: E402


class ValidateRevisionRuntimeTests(unittest.TestCase):
    def test_optional_relocation_probes_are_loaded_from_generated_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenarios.json"
            path.write_text(
                json.dumps({"forbidden_execute_addresses": ["0x8000", "0xf2d1"]}),
                encoding="utf-8",
            )
            self.assertEqual(
                load_forbidden_addresses(path),
                ["0x8000", "0xf2d1"],
            )
        self.assertEqual(load_forbidden_addresses(None), [])
