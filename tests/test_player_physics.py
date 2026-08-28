from __future__ import annotations

import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

import player_physics  # noqa: E402


PHYSICS_SOURCE = PROJECT_ROOT / "src" / "game" / "player" / "physics.asm"


class PlayerPhysicsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tables = player_physics.load_byte_tables(PHYSICS_SOURCE)

    def test_decodes_reference_vertical_profiles(self) -> None:
        self.assertEqual(
            self.tables["tbl_jump_gravity"],
            (0x20, 0x20, 0x1E, 0x28, 0x28, 0x0D, 0x04),
        )
        self.assertEqual(
            self.tables["tbl_fall_gravity"],
            (0x70, 0x70, 0x60, 0x90, 0x90, 0x0A, 0x09),
        )
        self.assertEqual(
            self.tables["tbl_initial_player_y_speed"],
            (0xFC, 0xFC, 0xFC, 0xFB, 0xFB, 0xFE, 0xFF),
        )

    def test_decodes_pal_vertical_profiles(self) -> None:
        tables = player_physics.load_byte_tables(
            PHYSICS_SOURCE, revision_profile="pal"
        )
        self.assertEqual(
            tables["tbl_jump_gravity"],
            (0x30, 0x30, 0x2D, 0x38, 0x38, 0x0D, 0x04),
        )
        self.assertEqual(
            tables["tbl_fall_gravity"],
            (0xA8, 0xA8, 0x90, 0xD0, 0xD0, 0x0A, 0x09),
        )
        self.assertEqual(
            tables["tbl_initial_player_y_speed"],
            (0xFB, 0xFB, 0xFB, 0xFA, 0xFA, 0xFE, 0xFF),
        )

    def test_decodes_ann_later_engine_table_order(self) -> None:
        tables = player_physics.load_byte_tables(
            PHYSICS_SOURCE, revision_profile="ann"
        )
        self.assertEqual(tables["tbl_horizontal_friction"], (0xE4, 0x98, 0xD0))
        self.assertEqual(
            tables["tbl_initial_player_y_speed"],
            (0xFC, 0xFC, 0xFC, 0xFB, 0xFB, 0xFE, 0xFF),
        )

    def test_selects_ground_jump_profiles_at_exact_thresholds(self) -> None:
        cases = {
            0x00: 0,
            0x08: 0,
            0x09: 1,
            0x0F: 1,
            0x10: 2,
            0x18: 2,
            0x19: 3,
            0x1B: 3,
            0x1C: 4,
            0xFF: 4,
        }
        for speed, expected in cases.items():
            with self.subTest(speed=speed):
                self.assertEqual(
                    player_physics.select_jump_profile_index(speed), expected
                )

    def test_selects_swimming_and_whirlpool_profiles(self) -> None:
        self.assertEqual(
            player_physics.select_jump_profile_index(0, swimming=True), 5
        )
        self.assertEqual(
            player_physics.select_jump_profile_index(
                0, swimming=True, whirlpool=True
            ),
            6,
        )

    def test_selects_pal_ground_jump_profiles_at_exact_thresholds(self) -> None:
        cases = {
            0x09: 0,
            0x0A: 1,
            0x11: 1,
            0x12: 2,
            0x1C: 2,
            0x1D: 3,
            0x21: 3,
            0x22: 4,
        }
        for speed, expected in cases.items():
            with self.subTest(speed=speed):
                self.assertEqual(
                    player_physics.select_jump_profile_index(
                        speed, revision_profile="pal"
                    ),
                    expected,
                )

    def test_released_jump_switches_to_fall_force_after_first_pixel(self) -> None:
        profile = player_physics.jump_profile(self.tables, 0)
        rows = player_physics.trace_jump(
            profile, held_frames=0, frame_count=3
        )
        self.assertEqual(
            [row.applied_gravity for row in rows], [0x20, 0x70, 0x70]
        )

    def test_fast_jump_trace_preserves_signed_rising_speed(self) -> None:
        profile = player_physics.jump_profile(self.tables, 0x1C)
        rows = player_physics.trace_jump(
            profile, held_frames=8, frame_count=5
        )
        self.assertEqual(
            [
                (
                    row.state.absolute_pixel,
                    row.state.signed_speed,
                    row.state.speed_fraction,
                )
                for row in rows
            ],
            [
                (0x017B, -5, 0x28),
                (0x0176, -5, 0x50),
                (0x0171, -5, 0x78),
                (0x016C, -5, 0xA0),
                (0x0168, -5, 0xC8),
            ],
        )


if __name__ == "__main__":
    unittest.main()
