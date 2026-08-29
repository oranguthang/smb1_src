from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from validate_runtime_scenarios import (  # noqa: E402
    validate_events,
    validate_event_details,
    validate_final_state,
    validate_forbidden_events,
    validate_forbidden_execution,
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

    def test_event_details_are_exact(self) -> None:
        scenario = {
            "id": "block-slot",
            "expected_event_details": {"block_slot_toggle": "0>1"},
        }
        rows = [{"event": "block_slot_toggle", "detail": "0>1"}]
        validate_event_details(scenario, rows)
        rows[0]["detail"] = "1>0"
        with self.assertRaisesRegex(ValueError, "Unexpected block_slot_toggle detail"):
            validate_event_details(scenario, rows)

    def test_undeclared_controlled_patch_is_rejected(self) -> None:
        scenario = {"id": "natural", "patches": []}
        rows = [{"event": "controlled_patch", "detail": "0010:00>01:unexpected"}]
        with self.assertRaisesRegex(ValueError, "patch scope differs"):
            validate_patches(scenario, rows)

    def test_forbidden_probe_execution_is_rejected(self) -> None:
        scenario = {"id": "relocation"}
        rows = [{"event": "forbidden_execute", "detail": "F2D0"}]
        with self.assertRaisesRegex(ValueError, "Forbidden execution"):
            validate_forbidden_execution(scenario, rows)

    def test_forbidden_semantic_event_is_rejected(self) -> None:
        scenario = {"id": "timer", "forbidden_events": ["coin_second_tone"]}
        rows = [{"event": "coin_second_tone", "detail": "counter=30"}]
        with self.assertRaisesRegex(ValueError, "Forbidden semantic event"):
            validate_forbidden_events(scenario, rows)


if __name__ == "__main__":
    unittest.main()
