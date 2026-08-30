from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from compare_assembly_sources import matching_blocks, parse_listing  # noqa: E402


class CompareAssemblySourcesTests(unittest.TestCase):
    def test_listing_parser_keeps_only_emitted_instructions(self) -> None:
        listing = """ca65 V2.19
000000r 2                       LDA #$01
006000  2  A9 01            LDA #$01  ; emitted
006002  2  8D 00 20         STA PPU_CTRL
006005  2  01 02 03 04      .byte 1, 2, 3, 4
006009  2  60               RTS
"""
        instructions = parse_listing(listing)
        self.assertEqual(
            [(item.mnemonic, item.opcode) for item in instructions],
            [("LDA", 0xA9), ("STA", 0x8D), ("RTS", 0x60)],
        )
        self.assertEqual(instructions[0].token(True), "A9:01")

    def test_common_substrings_are_extended_to_maximal_blocks(self) -> None:
        left = list("0123456789")
        right = list("xx234567yy")
        blocks = matching_blocks(left, right, 3)
        self.assertIn((2, 2, 6), [(item.left, item.right, item.size) for item in blocks])

    def test_short_sequences_do_not_become_candidates(self) -> None:
        self.assertEqual(matching_blocks(list("123"), list("123"), 4), [])


if __name__ == "__main__":
    unittest.main()
