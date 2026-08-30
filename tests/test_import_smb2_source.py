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
    exported_symbols,
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


if __name__ == "__main__":
    unittest.main()
