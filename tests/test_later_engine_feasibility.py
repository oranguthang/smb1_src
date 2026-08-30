from __future__ import annotations

import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from later_engine_feasibility import compare_bytes, load_manifest


class LaterEngineFeasibilityTests(unittest.TestCase):
    def test_exact_payload_is_reported_without_exporting_bytes(self) -> None:
        comparison = compare_bytes(b"shared engine", b"shared engine")
        self.assertTrue(comparison["exact"])
        self.assertEqual(comparison["matching_bytes"], 13)
        self.assertNotIn("payload", comparison)

    def test_shifted_code_is_counted_as_shared_evidence(self) -> None:
        comparison = compare_bytes(b"prefix-CODE-suffix", b"CODE")
        self.assertFalse(comparison["exact"])
        self.assertEqual(comparison["matching_bytes"], 4)
        self.assertEqual(comparison["subject_coverage"], 1.0)

    def test_project_manifest_records_a_separate_engine_boundary(self) -> None:
        manifest = load_manifest(
            PROJECT_ROOT / "config" / "later_engine_feasibility.json"
        )
        self.assertEqual(
            manifest["decision"]["classification"], "later-engine-sibling"
        )
        self.assertFalse(manifest["decision"]["shared_profile"])


if __name__ == "__main__":
    unittest.main()
