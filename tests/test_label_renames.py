from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PROJECT_ROOT / "docs" / "provenance" / "label_renames.json"
LABEL_RE = re.compile(
    r"^(?:bra|handler|loc|off|sub|tbl|unused|vec)_"
    r"[a-z0-9]+(?:_[a-z0-9]+)*$"
)
SOURCE_LABEL_RE = re.compile(
    r"^((?:bra|handler|loc|off|sub|tbl|unused|vec)_"
    r"[a-z0-9]+(?:_[a-z0-9]+)*):$"
)


class LabelRenameManifestTests(unittest.TestCase):
    def test_manifest_matches_current_source_labels(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        renames = manifest["renames"]
        additions = manifest["project_additions"]

        self.assertEqual(manifest["schema_version"], 2)
        self.assertEqual(
            manifest["rename_columns"],
            ["original", "current", "current_path"],
        )
        self.assertEqual(
            manifest["addition_columns"],
            ["current", "current_path", "introduced_in_commit", "reason"],
        )
        self.assertEqual(manifest["counts"]["original_labels"], len(renames))
        self.assertEqual(manifest["counts"]["direct_renames"], len(renames))
        self.assertEqual(manifest["counts"]["project_additions"], len(additions))
        self.assertEqual(len({item[0] for item in renames}), len(renames))

        mapped_labels = [(item[1], item[2]) for item in renames]
        mapped_labels.extend((item[0], item[1]) for item in additions)
        self.assertEqual(len({item[0] for item in mapped_labels}), len(mapped_labels))
        self.assertEqual(manifest["counts"]["current_labels"], len(mapped_labels))

        source_labels: dict[str, set[str]] = {}
        for source_path in sorted((PROJECT_ROOT / "src").rglob("*.asm")):
            relative_path = source_path.relative_to(PROJECT_ROOT).as_posix()
            labels = {
                match.group(1)
                for line in source_path.read_text(encoding="utf-8").splitlines()
                if (match := SOURCE_LABEL_RE.fullmatch(line))
            }
            source_labels[relative_path] = labels

        for current, relative_path in mapped_labels:
            self.assertRegex(current, LABEL_RE)
            self.assertIn(relative_path, source_labels)
            self.assertIn(current, source_labels[relative_path])

        active_labels = {
            (label, relative_path)
            for relative_path, labels in source_labels.items()
            for label in labels
        }
        self.assertEqual(set(mapped_labels), active_labels)


if __name__ == "__main__":
    unittest.main()
