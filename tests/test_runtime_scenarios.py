from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from validate_runtime_scenarios import (  # noqa: E402
    validate_events,
    validate_final_state,
    validate_patches,
)


class RuntimeScenarioTests(unittest.TestCase):
    def test_event_frames_and_final_state_are_exact(self) -> None:
        scenario = {
            "id": "jumping",
            "expected_events": {"jump": 12},
            "expected_final": {"player_state": "01"},
        }
        rows = [
            {"frame": "12", "event": "jump", "player_state": "00"},
            {"frame": "14", "event": "trace_end", "player_state": "01"},
        ]
        validate_events(scenario, rows)
        validate_final_state(scenario, rows)

    def test_undeclared_controlled_patch_is_rejected(self) -> None:
        scenario = {"id": "natural", "patches": []}
        rows = [{"event": "controlled_patch", "detail": "0010:00>01:unexpected"}]
        with self.assertRaisesRegex(ValueError, "patch scope differs"):
            validate_patches(scenario, rows)


if __name__ == "__main__":
    unittest.main()
