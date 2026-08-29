from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from relocation_test import (  # noqa: E402
    insert_probe,
    prepare_generated_source,
    verify_absorbed_bytes,
)


class RelocationTestTests(unittest.TestCase):
    def test_generated_sources_keep_probes_and_overrides_out_of_src(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src" / "rendering").mkdir(parents=True)
            (root / "src" / "audio").mkdir(parents=True)
            (root / "src" / "main.asm").write_text(
                '.include "first.asm"\n.include "audio.asm"\n',
                encoding="utf-8",
            )
            (root / "src" / "rendering" / "positioning.asm").write_text(
                "    .byte $ff, $ff, $ff, $ff, $ff, $ff\n",
                encoding="utf-8",
            )
            (root / "src" / "audio" / "music_streams.asm").write_text(
                "con_music_victory_size = $038\n\ntbl_music_note_periods:\n",
                encoding="utf-8",
            )
            manifest = {
                "source": "src/main.asm",
                "generated_root": "build/relocation",
                "game_padding_override": {
                    "source": "src/rendering/positioning.asm",
                    "include_path": "rendering/positioning.asm",
                    "original_statement": "    .byte $ff, $ff, $ff, $ff, $ff, $ff",
                    "replacement_statement": "    .assert * = $f2d0, error, \"budget\"",
                },
                "music_padding_override": {
                    "original_statement": "con_music_victory_size = $038",
                    "replacement_statement": "con_music_victory_size = $035",
                },
                "regions": [
                    {
                        "id": "game_and_rendering",
                        "insertions": [{"id": "game", "before": '.include "first.asm"'}],
                    },
                    {
                        "id": "audio",
                        "insertions": [{"id": "audio", "before": '.include "audio.asm"'}],
                    },
                ],
            }
            main_path, probes = prepare_generated_source(root, manifest)
            generated = main_path.read_text(encoding="utf-8")
            self.assertIn("relocation_probe_game:", generated)
            self.assertIn('.segment "AUDIO"', generated)
            self.assertEqual(len(probes), 2)
            original = root / "src" / "audio" / "music_streams.asm"
            self.assertIn("$038", original.read_text(encoding="utf-8"))
            override = root / "build" / "relocation" / "generated" / "audio" / "music_streams.asm"
            self.assertIn("$035", override.read_text(encoding="utf-8"))

    def test_duplicate_anchor_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "expected one duplicate"):
            insert_probe(
                "anchor\nanchor\n",
                {"id": "duplicate", "before": "anchor"},
            )

    def test_absorbed_ranges_require_exact_original_bytes(self) -> None:
        manifest = {
            "cpu_base": "0x8000",
            "regions": [{
                "id": "padding",
                "absorbed_range": {"start": "0x8001", "end": "0x8003"},
                "absorbed_bytes": "ffffff",
            }],
        }
        verify_absorbed_bytes(manifest, bytes.fromhex("00ffffff"))
        with self.assertRaisesRegex(ValueError, "absorbed bytes differ"):
            verify_absorbed_bytes(manifest, bytes.fromhex("00ff00ff"))


if __name__ == "__main__":
    unittest.main()
