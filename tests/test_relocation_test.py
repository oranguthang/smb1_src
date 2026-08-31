from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from relocation_test import (  # noqa: E402
    insert_probe,
    prepare_generated_source,
    rebase_incbin_paths,
    replace_fds_payloads,
    resolve_payload_interface,
    verify_absorbed_bytes,
    write_payload_interface,
)
from platform_profiles import FdsFileRecord  # noqa: E402


class RelocationTestTests(unittest.TestCase):
    def test_relative_incbin_path_is_rebased_for_generated_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "src" / "platform" / "data.asm"
            destination = root / "build" / "generated" / "platform" / "data.asm"
            source.parent.mkdir(parents=True)
            destination.parent.mkdir(parents=True)
            asset = root / "assets" / "private.bin"
            asset.parent.mkdir(parents=True)
            asset.write_bytes(b"private")

            generated = rebase_incbin_paths(
                '    .incbin "../../assets/private.bin"\n',
                source,
                destination,
            )

            binary_path = generated.split('"')[1]
            self.assertEqual((destination.parent / binary_path).resolve(), asset)

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

    def test_payload_interface_resolves_semantic_labels_and_addends(self) -> None:
        contract = {
            "guard": "TEST_INTERFACE_INC",
            "exports": [
                {"name": "handler_entry", "label": "handler_entry"},
                {"name": "off_vector_high", "label": "off_vector", "addend": 1},
            ],
        }
        exports = resolve_payload_interface(
            contract,
            {"handler_entry": 0x8123, "off_vector": 0x80FE},
        )
        self.assertEqual(exports, {"handler_entry": 0x8123, "off_vector_high": 0x80FF})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "main_interface.inc"
            write_payload_interface(path, contract, exports)
            self.assertEqual(
                path.read_text(encoding="utf-8"),
                "; Generated from relocated NSMMAIN debug labels\n\n"
                ".ifndef TEST_INTERFACE_INC\n"
                "TEST_INTERFACE_INC = 1\n\n"
                "handler_entry = $8123\n"
                "off_vector_high = $80ff\n\n"
                ".endif\n",
            )

    def test_fds_composition_replaces_each_declared_payload(self) -> None:
        reference = bytes(range(32))
        profile = {
            "verified_payloads": [
                {
                    "name": "MAIN",
                    "size": 4,
                    "records": [
                        {"file_id": 1, "load_address": 0x6000, "size": 4, "file_type": 0}
                    ],
                },
                {
                    "name": "OVERLAY",
                    "size": 3,
                    "records": [
                        {"file_id": 2, "load_address": 0xC000, "size": 3, "file_type": 0}
                    ],
                },
            ],
        }
        records = [
            FdsFileRecord(0, 1, b"MAIN    ", 0x6000, 4, 0, 0, 4),
            FdsFileRecord(1, 2, b"OVERLAY ", 0xC000, 3, 0, 8, 12),
        ]
        import relocation_test

        original_parser = relocation_test.parse_fds_side
        try:
            relocation_test.parse_fds_side = lambda _image: records
            candidate = replace_fds_payloads(
                reference,
                profile,
                {"MAIN": b"main", "OVERLAY": b"new"},
            )
        finally:
            relocation_test.parse_fds_side = original_parser
        self.assertEqual(candidate[4:8], b"main")
        self.assertEqual(candidate[12:15], b"new")
        self.assertEqual(candidate[:4], reference[:4])
        self.assertEqual(candidate[8:12], reference[8:12])


if __name__ == "__main__":
    unittest.main()
