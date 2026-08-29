from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from source_3_audit import (
    EXPECTED_MILESTONES,
    validate_milestones,
    validate_resolved_unknowns,
    validate_roadmap,
    validate_scenario_ids,
)


def milestones(*states: str) -> list[dict[str, str]]:
    return [
        {"id": identifier, "status": state}
        for identifier, state in zip(EXPECTED_MILESTONES, states, strict=True)
    ]


class Source3AuditTests(unittest.TestCase):
    def test_development_allows_one_active_milestone_after_complete_prefix(self) -> None:
        states = ["complete", "complete", "in-progress", *(["planned"] * 6)]
        self.assertEqual(validate_milestones(milestones(*states), "development"), [])

    def test_development_rejects_multiple_active_milestones(self) -> None:
        states = ["in-progress", "in-progress", *(["planned"] * 7)]
        self.assertIn(
            "development Source 3.0 requires exactly one active milestone",
            validate_milestones(milestones(*states), "development"),
        )

    def test_roadmap_keeps_stable_history_complete(self) -> None:
        text = "\n".join(
            [
                *(f"### {number}. Milestone - Complete" for number in range(15)),
                "### 15. Milestone - In Progress",
            ]
        )
        self.assertEqual(validate_roadmap(text, "development"), [])

    def test_semantic_scenario_order_is_manifest_owned(self) -> None:
        document = {"scenarios": [{"id": "time-up-clear"}]}
        self.assertEqual(validate_scenario_ids(document, ["time-up-clear"]), [])
        self.assertTrue(validate_scenario_ids(document, ["different-scenario"]))

    def test_resolved_unknowns_require_registry_status(self) -> None:
        text = """### DATA-001 TIME UP clear packet

- **Status:** Resolved

### RAM-001 Sprite control

- **Status:** Open
"""
        self.assertEqual(validate_resolved_unknowns(text, ["DATA-001"]), [])
        self.assertTrue(validate_resolved_unknowns(text, ["RAM-001"]))


if __name__ == "__main__":
    unittest.main()
