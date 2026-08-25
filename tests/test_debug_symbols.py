from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from debug_symbols import (  # noqa: E402
    choose_unique_addresses,
    normalize_dbg_for_ines,
    parse_record,
    resolve_debugger_config,
)


class DebugSymbolsTests(unittest.TestCase):
    def test_parse_record_preserves_quoted_commas_and_quotes(self) -> None:
        kind, fields = parse_record('file\tid=2,name="src/a,b""c.asm"\n')
        self.assertEqual(kind, "file")
        self.assertEqual(fields, {"id": "2", "name": 'src/a,b"c.asm'})

    def test_normalize_dbg_retargets_prg_offsets_to_ines_rom(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            raw = root / "raw.dbg"
            output = root / "game.dbg"
            prg = root / "game.prg"
            rom = root / "game.nes"
            raw.write_text(
                f'seg\tid=0,name="PRG",oname="{prg}",ooffs=0,size=32762\n'
                f'seg\tid=1,name="VECTORS",oname="{prg}",ooffs=32762,size=6\n',
                encoding="utf-8",
            )
            normalize_dbg_for_ines(raw, output, prg, rom)
            text = output.read_text(encoding="utf-8")
            self.assertIn(f'oname="{rom}",ooffs=16', text)
            self.assertIn(f'oname="{rom}",ooffs=32778', text)

    def test_fceux_alias_selection_prefers_semantic_entry_point(self) -> None:
        selected = choose_unique_addresses(
            [(0x8000, "data_alias"), (0x8000, "loc_shared_entry"), (0x8000, "sub_named")]
        )
        self.assertEqual(selected, [(0x8000, "sub_named")])

    def test_unknown_config_symbol_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            debug = root / "game.dbg"
            config = root / "breakpoints.json"
            debug.write_text('sym\tid=0,name="known",val=32768,type=lab\n', encoding="utf-8")
            config.write_text(json.dumps({"group": [{"symbol": "missing"}]}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Unknown debugger symbol"):
                resolve_debugger_config(debug, config)


if __name__ == "__main__":
    unittest.main()
