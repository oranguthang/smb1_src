from __future__ import annotations

import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from import_smb2_source import (  # noqa: E402
    Listing,
    SymbolKey,
    build_renames,
    collapse_main_unused_padding,
    exported_symbols,
    promote_common_gameplay,
    promote_common_hard_course_runtime,
    snake_case,
    transform_line,
)


class ImportSmb2SourceTests(unittest.TestCase):
    def test_snake_case_preserves_acronym_boundaries(self) -> None:
        self.assertEqual(snake_case("FDSFreqLookupTbl"), "fds_freq_lookup_tbl")
        self.assertEqual(snake_case("MoveUpsideDownPiranhaP"), "move_upside_down_piranha_p")

    def test_inline_jsr_classifies_the_target_as_a_subroutine(self) -> None:
        target = SymbolKey("main", "Target", "label")
        caller = SymbolKey("main", "Caller", "label")
        listing = Listing(
            "main",
            Path("sm2main.asm"),
            ["Caller: jsr Target", "Target: rts"],
            {"Caller": caller, "Target": target},
            {},
            set(),
            set(),
        )
        listings = {"main": listing}
        renames = build_renames(listings, exported_symbols(listings))
        self.assertEqual(renames[target], "sub_smb2_main_target")

    def test_reuses_reviewed_smb1_semantics_without_reusing_its_role(self) -> None:
        target = SymbolKey("main", "WBootCheck", "label")
        listing = Listing(
            "main",
            Path("sm2main.asm"),
            ["WBootCheck: rts"],
            {"WBootCheck": target},
            {},
            set(),
            set(),
        )
        listings = {"main": listing}
        renames = build_renames(
            listings,
            exported_symbols(listings),
            {"WBootCheck": "check_warm_boot_state"},
        )
        self.assertEqual(renames[target], "loc_smb2_main_check_warm_boot_state")

    def test_hardware_assignments_move_to_owned_hardware_module(self) -> None:
        key = SymbolKey("main", "PPU_CTRL", "assignment")
        listing = Listing(
            "main",
            Path("sm2main.asm"),
            ["PPU_CTRL = $2000"],
            {},
            {"PPU_CTRL": key},
            set(),
            set(),
        )
        self.assertEqual(transform_line(listing, listing.lines[0], {}, {}), "")

    def test_shared_gameplay_labels_converge_across_payloads(self) -> None:
        listings = {}
        for payload in ("data2", "data4"):
            key = SymbolKey(payload, "UpsideDownPipe_High", "label")
            listings[payload] = Listing(
                payload,
                Path(f"sm2{payload}.asm"),
                ["UpsideDownPipe_High: rts"],
                {"UpsideDownPipe_High": key},
                {},
                set(),
                set(),
            )
        renames = build_renames(listings, exported_symbols(listings))
        self.assertEqual(
            {renames[next(iter(listing.labels.values()))] for listing in listings.values()},
            {"handler_late_fds_upside_down_pipe_high"},
        )

    def test_gameplay_promotion_replaces_the_complete_runtime(self) -> None:
        lines = [
            "before:",
            "    NOP",
            "handler_late_fds_upside_down_pipe_high:",
            "    LDA #$01",
            "bra_late_fds_exit_upside_down_piranha_movement: RTS",
            "after:",
            "    RTS",
        ]
        promoted = promote_common_gameplay(lines)
        self.assertEqual(
            promoted,
            [
                "before:",
                "    NOP",
                '.include "../shared_gameplay_interface.inc"',
                '.include "../../../common/gameplay/upside_down_pipe.asm"',
                "after:",
                "    RTS",
            ],
        )

    def test_hard_course_promotion_keeps_revision_owned_tables(self) -> None:
        lines = [
            "revision_table:",
            "    .byte $01",
            "handler_late_fds_get_hard_course_descriptor: RTS",
            "handler_late_fds_load_hard_course_streams: RTS",
            "revision_checkpoint_table:",
            "    .byte $02",
            "sub_late_fds_initialize_hard_course_checkpoints: RTS",
            "revision_tail:",
            "    .byte $03",
        ]
        promoted = promote_common_hard_course_runtime(lines)
        self.assertEqual(
            promoted,
            [
                "revision_table:",
                "    .byte $01",
                '.include "shared_interface.inc"',
                '.include "../../../common/game/hard_course_loader.asm"',
                "revision_checkpoint_table:",
                "    .byte $02",
                '.include "../../../common/game/hard_course_checkpoints.asm"',
                "revision_tail:",
                "    .byte $03",
            ],
        )

    def test_main_padding_is_expressed_as_capacity(self) -> None:
        lines = [
            "; a bunch of unused space",
            *["    .byte " + ", ".join(["$ff"] * 16) for _ in range(5)],
            "    .byte $ff, $ff, $ff",
            "next_label:",
        ]
        self.assertEqual(
            collapse_main_unused_padding(lines),
            [
                "; a bunch of unused space",
                "    .res 83, $ff",
                "next_label:",
            ],
        )


if __name__ == "__main__":
    unittest.main()
