from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from smb2_relocation_test import (  # noqa: E402
    expected_main_shift,
    prepare_generated_source,
)


class Smb2RelocationTests(unittest.TestCase):
    def test_fixed_tail_resets_the_expected_shift(self) -> None:
        anchors = [0x6000, 0x7000, 0x8000]
        self.assertEqual(expected_main_shift(0x7fff, anchors, 0xd29f), 2)
        self.assertEqual(expected_main_shift(0xd29f, anchors, 0xd29f), 0)

    def test_generated_candidate_does_not_modify_normal_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "src" / "smb2" / "data").mkdir(parents=True)
            main = root / "src" / "smb2" / "main.asm"
            main.write_text('    .include "system/reset.inc"\n', encoding="utf-8")
            aggregate = root / "src" / "smb2" / "build.asm"
            aggregate.write_text('.include "main.asm"\n', encoding="utf-8")
            padding = root / "src" / "smb2" / "data" / "course_bank.inc"
            padding.write_text("    .res 83, $ff\n", encoding="utf-8")
            manifest = {
                "generated_root": "build/relocation/smb2",
                "main_source": "src/smb2/main.asm",
                "source": "src/smb2/build.asm",
                "regions": [{
                    "id": "main",
                    "insertions": [{
                        "id": "origin",
                        "before": '    .include "system/reset.inc"',
                    }],
                }],
                "padding_override": {
                    "source": "src/smb2/data/course_bank.inc",
                    "include_path": "data/course_bank.inc",
                    "original_statement": "    .res 83, $ff",
                    "replacement_statement": "    .res 82, $ff",
                },
            }
            generated, probes = prepare_generated_source(root, manifest)
            generated_main = generated.parent / "main.asm"
            self.assertIn("relocation_probe_origin", generated_main.read_text())
            self.assertEqual(padding.read_text(), "    .res 83, $ff\n")
            self.assertEqual(len(probes), 1)


if __name__ == "__main__":
    unittest.main()
