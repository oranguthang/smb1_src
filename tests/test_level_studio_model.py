from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from level_studio_model import (  # noqa: E402
    area_name,
    describe_area_object,
    positioned_area_objects,
    positioned_enemy_objects,
)


class LevelStudioModelTests(unittest.TestCase):
    def test_world_pointer_name_uses_one_based_area_number(self) -> None:
        self.assertEqual(area_name(1, 5), "ground_6")

    def test_object_description_decodes_standard_and_page_records(self) -> None:
        self.assertEqual(describe_area_object(0x05, 0x01), "question block (coin)")
        self.assertEqual(describe_area_object(0x0D, 0x47), "set page 7")

    def test_object_positions_follow_page_advance_and_page_setter(self) -> None:
        stream = {"data": {"objects": [
            {"column": 2, "row": 4, "page_advance": False, "object_control": 1},
            {"column": 1, "row": 4, "page_advance": True, "object_control": 1},
            {"column": 0, "row": 13, "page_advance": False, "object_control": 0x45},
            {"column": 3, "row": 4, "page_advance": False, "object_control": 1},
        ]}}
        self.assertEqual([item["x"] for item in positioned_area_objects(stream)], [2, 17, 80, 83])

    def test_enemy_positions_and_names_are_semantic(self) -> None:
        stream = {"data": {"records": [{
            "kind": "enemy", "column": 3, "row": 8, "page_advance": True,
            "hard_mode": False, "object_or_page": 6,
        }]}}
        item = positioned_enemy_objects(stream)[0]
        self.assertEqual(item["x"], 19)
        self.assertEqual(item["description"], "Goomba")


if __name__ == "__main__":
    unittest.main()
