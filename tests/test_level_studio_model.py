from __future__ import annotations

import sys
import unittest
from pathlib import Path
from types import SimpleNamespace


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from level_studio_model import (  # noqa: E402
    LevelDocument,
    LevelVisuals,
    area_pointer,
    area_name,
    describe_area_object,
    default_preview_theme,
    enemy_group_preview,
    enemy_preview_y,
    firebar_preview_offsets,
    first_world_context,
    player_entrance_preview_position,
    positioned_area_objects,
    positioned_enemy_objects,
    render_level_scene,
    resolve_level_rendering,
)


class LevelStudioModelTests(unittest.TestCase):
    def test_unused_area_names_are_explicit_and_not_editable(self) -> None:
        area_document = SimpleNamespace(document={"data": {"streams": [
            {"name": "ground_1"}, {"name": "ground_24"},
        ]}})
        enemy_document = SimpleNamespace(document={"data": {"streams": [
            {"name": "ground_1"}, {"name": "ground_24"},
        ]}})
        model = LevelDocument(
            area_document, enemy_document, ["ground_24"],
        )
        self.assertEqual(
            model.display_names, ["ground_1", "ground_24 [unused]"]
        )
        self.assertEqual(
            model.name_from_display("ground_24 [unused]"), "ground_24"
        )
        with self.assertRaisesRegex(ValueError, "unused pointer-table slot"):
            model.require_editable("ground_24")

    def test_unused_area_contract_rejects_unknown_names(self) -> None:
        document = SimpleNamespace(document={"data": {"streams": [
            {"name": "ground_1"},
        ]}})
        with self.assertRaisesRegex(ValueError, "Unknown unused"):
            LevelDocument(document, document, ["ground_24"])

    def test_area_names_map_to_runtime_pointer_bytes(self) -> None:
        self.assertEqual(area_pointer("water_1"), 0x00)
        self.assertEqual(area_pointer("ground_6"), 0x25)
        self.assertEqual(area_pointer("underground_1"), 0x40)
        self.assertEqual(area_pointer("castle_6"), 0x65)
        self.assertEqual(first_world_context("ground_6"), (0, 0))
        self.assertEqual(first_world_context("castle_6"), (7, 3))

    def test_world_context_uses_the_selected_profile_routes(self) -> None:
        routes = ((0x21, 0x25), (0x00,))
        self.assertEqual(first_world_context("ground_6", routes), (0, 1))

    def test_world_context_preserves_a_fifth_course_slot(self) -> None:
        routes = ((0x20, 0x21, 0x22, 0x23, 0x25),)
        self.assertEqual(first_world_context("ground_6", routes), (0, 4))

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

    def test_enemy_preview_applies_the_runtime_vertical_offset(self) -> None:
        self.assertEqual(enemy_preview_y(11, 0x06), 152)
        self.assertEqual(enemy_preview_y(6, 0x15), 64)
        self.assertEqual(enemy_preview_y(0, 0x35), 152)

    def test_enemy_group_preview_reconstructs_members_and_spacing(self) -> None:
        self.assertEqual(enemy_group_preview(0x37), (0x06, 2, 152))
        self.assertEqual(enemy_group_preview(0x3A), (0x06, 3, 88))
        self.assertEqual(enemy_group_preview(0x3B), (0x00, 2, 152))
        self.assertIsNone(enemy_group_preview(0x36))

    def test_firebar_preview_uses_engine_radial_offsets(self) -> None:
        clockwise = firebar_preview_offsets(0x1B)
        counterclockwise = firebar_preview_offsets(0x1D)
        long_firebar = firebar_preview_offsets(0x1F)
        self.assertEqual(len(clockwise), 6)
        self.assertEqual(clockwise[:3], ((0, 0), (6, -4), (13, -9)))
        self.assertEqual(counterclockwise[:3], ((0, 0), (6, 4), (13, 9)))
        self.assertEqual(len(long_firebar), 12)
        self.assertEqual(long_firebar[-1], (73, -49))
        self.assertEqual(firebar_preview_offsets(0x20), ())

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

    def test_scene_accepts_the_ann_ground_metatile(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 1,
            },
            "objects": [],
        }}
        scene = render_level_scene(
            "ground_6",
            area,
            {"data": {"records": []}},
            rendering=resolve_level_rendering({
                "terrain_metatiles": (0x69, 0x6A, 0x52, 0x62),
            }),
        )
        self.assertEqual(scene.metatiles[0][11:13], (0x6A, 0x6A))

    def test_ann_small_object_table_renders_the_water_exit_pipe(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [{
                "column": 4, "row": 5, "page_advance": False,
                "object_control": 0x0A,
            }],
        }}
        rendering = resolve_level_rendering({"small_object_table": "ann"})
        scene = render_level_scene(
            "water_1", area, {"data": {"records": []}}, rendering=rendering,
        )
        self.assertEqual(scene.metatiles[4][5:7], (0x6C, 0x6D))
        self.assertEqual(
            positioned_area_objects(area, "ann")[0]["description"],
            "sideways pipe",
        )

    def test_smb2_small_object_table_uses_its_shifted_pipe_and_blocks(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [
                {"column": 2, "row": 5, "page_advance": False,
                 "object_control": 0x0D},
                {"column": 3, "row": 5, "page_advance": False,
                 "object_control": 0x01},
            ],
        }}
        rendering = resolve_level_rendering({"small_object_table": "smb2"})
        scene = render_level_scene(
            "water_1", area, {"data": {"records": []}}, rendering=rendering,
        )
        self.assertEqual(scene.metatiles[2][5:7], (0x6D, 0x6E))
        self.assertEqual(scene.metatiles[3][5], 0xC2)

    def test_smb2_secondary_ledge_uses_cloud_metatiles_without_a_stem(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 1,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [{
                "column": 2, "row": 5, "page_advance": False,
                "object_control": 0x13,
            }],
        }}
        rendering = resolve_level_rendering({
            "secondary_ledge_metatiles": (0x8A, 0x8B, 0x8C),
            "secondary_ledge_support_metatiles": (),
        })
        scene = render_level_scene(
            "ground_22", area, {"data": {"records": []}}, rendering=rendering,
        )
        self.assertEqual(
            [scene.metatiles[column][5] for column in range(2, 6)],
            [0x8A, 0x8B, 0x8B, 0x8C],
        )
        self.assertEqual(scene.metatiles[4][6], 0)

    def test_springboard_area_object_adds_its_runtime_sprite(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [{
                "column": 5, "row": 9, "page_advance": False,
                "object_control": 0x0F,
            }],
        }}
        rendering = resolve_level_rendering({"small_object_table": "smb2"})
        scene = render_level_scene(
            "ground_22", area, {"data": {"records": []}}, rendering=rendering,
        )
        self.assertEqual(scene.metatiles[5][9:11], (0x68, 0x69))
        self.assertEqual(len(scene.spawned_actors), 1)
        self.assertEqual(scene.spawned_actors[0]["object_or_page"], 0x32)
        self.assertEqual(scene.spawned_actors[0]["preview_y"], 9 * 16)

    def test_smb2_special_objects_use_the_later_engine_metatiles(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [
                {"column": 0, "row": 12, "page_advance": False,
                 "object_control": 0x20},
                {"column": 2, "row": 13, "page_advance": False,
                 "object_control": 0x41},
                {"column": 4, "row": 15, "page_advance": False,
                 "object_control": 0x31},
                {"column": 8, "row": 15, "page_advance": False,
                 "object_control": 0x61},
            ],
        }}
        rendering = resolve_level_rendering({
            "bridge_metatile": 0x64,
            "flagpole_metatiles": (0x21, 0x22, 0x62),
            "staircase_metatile": 0x62,
            "upside_down_pipes": True,
        })
        scene = render_level_scene(
            "ground_22", area, {"data": {"records": []}}, rendering=rendering,
        )
        self.assertEqual(scene.metatiles[0][7], 0x64)
        self.assertEqual(scene.metatiles[2][0:2], (0x21, 0x22))
        self.assertEqual(scene.metatiles[2][10], 0x62)
        self.assertEqual(scene.metatiles[4][10], 0x62)
        self.assertEqual(scene.metatiles[8][1:3], (0x14, 0x10))
        self.assertEqual(scene.metatiles[9][1:3], (0x15, 0x11))

    def test_scene_reconstructs_the_five_column_castle_structure(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [{
                "column": 0, "row": 15, "page_advance": False,
                "object_control": 0x20,
            }],
        }}
        enemies = {"data": {"records": []}}
        scene = render_level_scene("ground_6", area, enemies)
        self.assertEqual([scene.metatiles[x][0] for x in range(5)], [0, 0x45, 0x45, 0x45, 0])
        self.assertEqual([scene.metatiles[x][1] for x in range(5)], [0, 0x46, 0x47, 0x48, 0])

    def test_castle_structure_places_its_page_stop_block(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [{
                "column": 0, "row": 15, "page_advance": True,
                "object_control": 0x26,
            }],
        }}
        scene = render_level_scene(
            "ground_22", area, {"data": {"records": []}},
        )
        self.assertEqual(scene.metatiles[19][10], 0x50)

    def test_scene_reconstructs_intro_pipe_and_balance_rope(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [
                {"column": 0, "row": 13, "page_advance": False, "object_control": 0x40},
                {"column": 5, "row": 15, "page_advance": False, "object_control": 0x13},
            ],
        }}
        scene = render_level_scene("ground_6", area, {"data": {"records": []}})
        self.assertEqual([scene.metatiles[x][9] for x in range(4)], [0x1C, 0x1D, 0x1E, 0x15])
        self.assertEqual([scene.metatiles[x][10] for x in range(4)], [0x1F, 0x20, 0x21, 0x15])
        self.assertEqual(scene.metatiles[5][1:5], (0x40, 0x40, 0x40, 0x40))
        self.assertEqual(scene.metatiles[5][5], 0x44)

    def test_scene_reconstructs_the_left_facing_underground_exit_pipe(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [{
                "column": 4, "row": 15, "page_advance": False,
                "object_control": 0x47,
            }],
        }}
        scene = render_level_scene(
            "underground_1", area, {"data": {"records": []}}
        )
        self.assertEqual(scene.metatiles[6][:6], (0x14,) * 6)
        self.assertEqual(scene.metatiles[7][:6], (0x15,) * 6)
        self.assertEqual(
            [scene.metatiles[column][6] for column in range(4, 8)],
            [0x1C, 0x1D, 0x1E, 0x15],
        )
        self.assertEqual(
            [scene.metatiles[column][7] for column in range(4, 8)],
            [0x1F, 0x20, 0x21, 0x15],
        )

    def test_smb2_exit_pipe_uses_the_later_engine_metatile_table(self) -> None:
        area = {"data": {
            "header": {
                "timer_setting": 1, "entrance_control": 2,
                "foreground_or_color": 0, "area_style": 0,
                "background_scenery": 0, "terrain_control": 0,
            },
            "objects": [{
                "column": 4, "row": 15, "page_advance": False,
                "object_control": 0x47,
            }],
        }}
        rendering = resolve_level_rendering({
            "side_pipe_top_metatiles": (0x19, 0x1A, 0x1B, 0x15),
            "side_pipe_bottom_metatiles": (0x1C, 0x1D, 0x1E, 0x15),
        })
        scene = render_level_scene(
            "underground_1",
            area,
            {"data": {"records": []}},
            rendering=rendering,
        )
        self.assertEqual(
            [scene.metatiles[column][6] for column in range(4, 8)],
            [0x19, 0x1A, 0x1B, 0x15],
        )

    def test_visual_data_resolves_metatile_groups_and_sprite_frames(self) -> None:
        records = [[index] * 4 for index in range(101)]
        palettes = [
            {"name": "ground", "packets": [{"values": list(range(32))}]},
            {"name": "bowser", "packets": [{"values": [0x0F, 0x1A, 0x30, 0x27]}]},
        ]
        frames = [[0xFC] * 8 for _ in range(26)]
        frames[25] = list(range(8))
        frames[23] = list(range(8))
        visuals = LevelVisuals([], records, palettes, frames)
        self.assertEqual(visuals.metatile_record(0x80), (85, 85, 85, 85))
        records[3] = [1, 2, 3, 4]
        self.assertEqual(visuals.display_metatile_record(3), (1, 3, 2, 4))
        self.assertEqual(visuals.player_tiles(), (4, 5, 6, 7))
        self.assertEqual(visuals.player_horizontal_flips(), (False, False, False, True))
        self.assertEqual(
            visuals.enemy_horizontal_flips(0x07),
            (False, True, False, True, False, True),
        )
        self.assertEqual(visuals.enemy_horizontal_flips(0x06), (True,) * 6)
        self.assertEqual(visuals.enemy_tiles(6), (0xFC, 0xFC, 0x70, 0x71, 0x72, 0x73))
        self.assertEqual(visuals.enemy_tiles(5), (0x7D, 0x7C, 0xD1, 0x8C, 0xD3, 0xD2))
        self.assertEqual(
            visuals.enemy_display_tiles(5),
            (0x7C, 0x7D, 0x8C, 0xD1, 0xD2, 0xD3),
        )
        self.assertEqual(visuals.enemy_horizontal_flips(5), (True,) * 6)
        self.assertEqual(visuals.enemy_tiles(0x11), (0xB9, 0xB8, 0xBB, 0xBA, 0xBC, 0xBC))
        self.assertEqual(
            visuals.enemy_horizontal_flips(0x11),
            (True, True, True, True, False, True),
        )
        self.assertEqual(visuals.enemy_tiles(0x15), ())
        self.assertEqual(
            visuals.enemy_tiles(0x32),
            (0xF2, 0xF2, 0xF3, 0xF3, 0xF2, 0xF2),
        )
        self.assertEqual(
            visuals.enemy_horizontal_flips(0x32),
            (False, True, False, True, False, True),
        )
        self.assertEqual(
            visuals.enemy_vertical_flips(0x32),
            (False, False, True, True, True, True),
        )
        self.assertEqual(visuals.enemy_tiles(0x35), (0xCD, 0xCD, 0xCE, 0xCE, 0xCF, 0xCF))
        self.assertEqual(visuals.enemy_palette(0x35), 2)
        self.assertEqual(visuals.special_palette("bowser"), (0x0F, 0x1A, 0x30, 0x27))
        self.assertEqual(
            visuals.bowser_tiles(),
            (
                (0xBF, 0xBE, 0xC1, 0xC0, 0xC2, 0xFC),
                (0xC4, 0xC3, 0xC6, 0xC5, 0xC8, 0xC7),
            ),
        )

    def test_visual_data_accepts_the_ann_metatile_group_layout(self) -> None:
        records = [[index] * 4 for index in range(102)]
        visuals = LevelVisuals(
            [],
            records,
            [],
            [],
            metatile_group_starts=(0, 39, 86, 96),
            metatile_group_sizes=(39, 47, 10, 6),
        )
        self.assertEqual(visuals.metatile_record(0x80), (86, 86, 86, 86))
        self.assertEqual(visuals.metatile_record(0xC0), (96, 96, 96, 96))

    def test_preview_theme_follows_vanilla_background_color(self) -> None:
        header = {"data": {"header": {"foreground_or_color": 0}}}
        self.assertEqual(default_preview_theme("ground_6", header), "Day")
        self.assertEqual(default_preview_theme("castle_1", header), "Night")
        header["data"]["header"]["foreground_or_color"] = 5
        self.assertEqual(default_preview_theme("castle_1", header), "Day")

    def test_player_preview_uses_the_area_entrance_height(self) -> None:
        self.assertEqual(player_entrance_preview_position(2), (2, 10))
        self.assertEqual(player_entrance_preview_position(3), (2, 4))
        self.assertEqual(player_entrance_preview_position(1), (2, 1))


if __name__ == "__main__":
    unittest.main()
