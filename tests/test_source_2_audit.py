from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from source_2_audit import validate_roadmap


class Source2AuditTests(unittest.TestCase):
    def test_roadmap_requires_every_milestone_through_fourteen(self) -> None:
        text = "\n".join(
            f"### {number}. Milestone - Complete" for number in range(14)
        )
        self.assertEqual(
            validate_roadmap(text),
            ["roadmap milestone 14 is not Complete"],
        )

    def test_complete_roadmap_is_accepted(self) -> None:
        text = "\n".join(
            f"### {number}. Milestone - Complete" for number in range(15)
        )
        self.assertEqual(validate_roadmap(text), [])

    def test_development_roadmap_requires_open_release_milestones(self) -> None:
        text = "\n".join(
            [
                *(f"### {number}. Milestone - Complete" for number in range(13)),
                "### 13. Milestone - In Progress",
                "### 14. Milestone - Planned",
            ]
        )
        self.assertEqual(validate_roadmap(text, status="development"), [])

    def test_development_roadmap_rejects_a_premature_complete_status(self) -> None:
        text = "\n".join(
            f"### {number}. Milestone - Complete" for number in range(15)
        )
        self.assertEqual(
            validate_roadmap(text, status="development"),
            [
                "roadmap milestone 13 is not In Progress",
                "roadmap milestone 14 is not Planned",
            ],
        )


if __name__ == "__main__":
    unittest.main()
