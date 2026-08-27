from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from level_studio_model import (  # noqa: E402
    LevelVisuals,
    area_pointer,
    area_name,
    describe_area_object,
    default_preview_theme,
    first_world_context,
    positioned_area_objects,
    positioned_enemy_objects,
    render_level_scene,
)


class LevelStudioModelTests(unittest.TestCase):
    def test_area_names_map_to_runtime_pointer_bytes(self) -> None:
        self.assertEqual(area_pointer("water_1"), 0x00)
        self.assertEqual(area_pointer("ground_6"), 0x25)
        self.assertEqual(area_pointer("underground_1"), 0x40)
        self.assertEqual(area_pointer("castle_6"), 0x65)
        self.assertEqual(first_world_context("ground_6"), (0, 0))
        self.assertEqual(first_world_context("castle_6"), (7, 3))

    def test_world_pointer_name_uses_one_based_area_number(self) -> None:
        self.assertEqual(area_name(1, 5), "ground_6")

    def test_object_description_decodes_standard_and_page_records(self) -> None:
        self.assertEqual(describe_area_object(0x05, 0x01), "question block (coin)")
        self.assertEqual(describe_area_object(0x0D, 0x07), "set page 7")
        self.assertEqual(describe_area_object(0x0D, 0x41), "flagpole")

    def test_object_positions_follow_page_advance_and_page_setter(self) -> None:
        stream = {"data": {"objects": [
            {"column": 2, "row": 4, "page_advance": False, "object_control": 1},
            {"column": 1, "row": 4, "page_advance": True, "object_control": 1},
            {"column": 0, "row": 13, "page_advance": False, "object_control": 0x05},
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

    def test_scene_reconstructs_terrain_blocks_pipes_and_enemies(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 2, "terrain_control": 1,
            },
            "objects": [
                {"column": 0, "row": 7, "page_advance": False, "object_control": 1},
                {"column": 2, "row": 7, "page_advance": False, "object_control": 0x23},
                {"column": 7, "row": 7, "page_advance": False, "object_control": 0x72},
            ],
        }}
        enemies = {"data": {"records": [{
            "kind": "enemy", "column": 6, "row": 11, "page_advance": False,
            "hard_mode": False, "object_or_page": 6,
        }]}}
        scene = render_level_scene("ground_6", area, enemies)
        self.assertEqual(scene.metatiles[0][7], 0xC0)
        self.assertEqual([scene.metatiles[x][7] for x in range(2, 6)], [0x51] * 4)
        self.assertEqual(scene.metatiles[7][7:10], (0x12, 0x14, 0x14))
        self.assertEqual(scene.metatiles[8][7:10], (0x13, 0x15, 0x15))
        self.assertEqual(scene.metatiles[10][11:13], (0x54, 0x54))
        self.assertEqual(scene.enemies[0]["description"], "Goomba")

    def test_visual_data_resolves_metatile_groups_and_sprite_frames(self) -> None:
        records = [[index] * 4 for index in range(101)]
        palettes = [{"name": "ground", "packets": [{"values": list(range(32))}]}]
        frames = [[0xFC] * 8 for _ in range(26)]
        frames[25] = list(range(8))
        frames[23] = list(range(8))
        visuals = LevelVisuals([], records, palettes, frames)
        self.assertEqual(visuals.metatile_record(0x80), (85, 85, 85, 85))
        records[3] = [1, 2, 3, 4]
        self.assertEqual(visuals.display_metatile_record(3), (1, 3, 2, 4))
        self.assertEqual(visuals.player_tiles(), (4, 5, 6, 7))
        self.assertEqual(visuals.player_horizontal_flips(), (False, False, False, True))
        self.assertEqual(visuals.enemy_tiles(6), (0xFC, 0xFC, 0x70, 0x71, 0x72, 0x73))

    def test_preview_theme_follows_vanilla_background_color(self) -> None:
        header = {"data": {"header": {"foreground_or_color": 0}}}
        self.assertEqual(default_preview_theme("ground_6", header), "Day")
        self.assertEqual(default_preview_theme("castle_1", header), "Night")
        header["data"]["header"]["foreground_or_color"] = 5
        self.assertEqual(default_preview_theme("castle_1", header), "Day")


if __name__ == "__main__":
    unittest.main()
