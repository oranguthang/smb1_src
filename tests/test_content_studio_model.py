from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from content_studio_model import (  # noqa: E402
    ArtifactDocument,
    ChrDocument,
    decode_chr,
    encode_chr,
    smb_tile_text,
)


class ContentStudioModelTests(unittest.TestCase):
    def test_chr_round_trip_is_byte_identical(self) -> None:
        data = bytes((index * 37) & 0xFF for index in range(8192))
        self.assertEqual(encode_chr(decode_chr(data)), data)

    def test_chr_edit_undo_and_atomic_save(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "smb.chr"
            model = ChrDocument(bytes(8192), path)
            model.begin_stroke(256)
            model.paint(256, 0, 0, 3)
            model.end_stroke()
            self.assertTrue(model.changed(256))
            self.assertTrue(model.undo())
            self.assertFalse(model.changed(256))
            model.paint(256, 0, 0, 2)
            model.save()
            self.assertEqual(path.stat().st_size, 8192)

    def test_artifact_scalar_edit_validates_and_saves(self) -> None:
        entry = {
            "id": "records",
            "codec": "fixed_records",
            "record_size": 2,
            "record_name": "record",
        }
        document = {
            "schema_version": 1,
            "artifact_id": "records",
            "codec": "fixed_records",
            "capacity_bytes": 2,
            "data": {"records": [[1, 2]]},
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "records.json"
            model = ArtifactDocument(document, entry, path)
            model._remember()
            model.document["data"]["records"][0][1] = 3
            self.assertEqual(model.validate(), bytes([1, 3]))
            model.save()
            self.assertEqual(json.loads(path.read_text(encoding="utf-8"))["data"]["records"][0], [1, 3])

    def test_smb_tile_text_exposes_known_glyphs_and_unknown_tiles(self) -> None:
        self.assertEqual(smb_tile_text([0x16, 0x0A, 0x1B, 0x12, 0x18, 0x2B]), "MARIO!")
        self.assertEqual(smb_tile_text([0xFF]), "<FF>")


if __name__ == "__main__":
    unittest.main()
