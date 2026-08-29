from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from audit_unreachable_code import find_word_occurrences, parse_debug_symbols  # noqa: E402


class UnreachableCodeAuditTests(unittest.TestCase):
    def test_debug_reference_count_is_decoded(self) -> None:
        text = "\n".join(
            [
                'sym\tid=1,name="unused_entry",def=2,val=0xE392,type=lab',
                'sym\tid=2,name="called_entry",def=3,ref=4+5,val=0xE400,type=lab',
            ]
        )
        symbols = parse_debug_symbols(text)
        self.assertEqual(symbols["unused_entry"], {"address": 0xE392, "references": 0})
        self.assertEqual(symbols["called_entry"], {"address": 0xE400, "references": 2})

    def test_raw_little_endian_addresses_are_reported(self) -> None:
        data = bytes.fromhex("0092e31192e3")
        self.assertEqual(find_word_occurrences(data, 0xE392), [0x8001, 0x8004])


if __name__ == "__main__":
    unittest.main()
