from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from runtime.validate_scoring_contract import validate_contract  # noqa: E402


class ScoringRuntimeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(
            (PROJECT_ROOT / "scenarios" / "scoring_runtime_scenarios.json").read_text(
                encoding="utf-8"
            )
        )

    def test_repository_contract_is_self_consistent(self) -> None:
        self.assertEqual(validate_contract(self.contract), [])

    def test_score_hud_disagreement_is_rejected(self) -> None:
        contract = copy.deepcopy(self.contract)
        contract["scenarios"][0]["expected_event_details"]["score_hud_packet"] = (
            "source=coin;score=999999;tiles=240000000200"
        )
        self.assertIn(
            "coin-award score, HUD, and top-score results disagree",
            validate_contract(contract),
        )

    def test_undeclared_controlled_boundary_is_rejected(self) -> None:
        contract = copy.deepcopy(self.contract)
        contract["scenarios"][1]["patches"] = []
        self.assertIn(
            "coin-extra-life controlled-patch classification differs",
            validate_contract(contract),
        )


if __name__ == "__main__":
    unittest.main()
