from __future__ import annotations

import json
import re
import subprocess
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PROJECT_ROOT / "docs" / "provenance" / "label_renames.json"
IMPORT_COMMIT = "052aa23781fe028d8d7d2627638a87326107c015"
LABEL_RE = re.compile(
    r"^(?:bra|handler|loc|off|sub|tbl|unused|vec)_"
    r"[a-z0-9]+(?:_[a-z0-9]+)*$"
)
SOURCE_LABEL_RE = re.compile(
    r"^((?:bra|handler|loc|off|sub|tbl|unused|vec)_"
    r"[a-z0-9]+(?:_[a-z0-9]+)*):$"
)
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
IMPORTED_LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")


class LabelRenameManifestTests(unittest.TestCase):
    def test_manifest_roots_match_imported_source_labels(self) -> None:
        try:
            result = subprocess.run(
                ["git", "show", f"{IMPORT_COMMIT}:src/smbdis.asm"],
                cwd=PROJECT_ROOT,
                capture_output=True,
                text=True,
                encoding="utf-8",
                check=False,
            )
        except FileNotFoundError:
            self.skipTest("Git is unavailable; cannot inspect the import commit")
        if result.returncode != 0:
            self.skipTest("Import commit is unavailable in this Git checkout")

        imported_labels = [
            match.group(1)
            for line in result.stdout.splitlines()
            if (match := IMPORTED_LABEL_RE.match(line))
        ]
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        mapped_roots = [item[0] for item in manifest["renames"]]

        self.assertEqual(len(imported_labels), len(set(imported_labels)))
        self.assertEqual(mapped_roots, imported_labels)

    def test_manifest_matches_current_source_labels(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        renames = manifest["renames"]
        additions = manifest["project_additions"]

        self.assertEqual(manifest["schema_version"], 2)
        self.assertEqual(
            manifest["source"],
            {
                "author": "doppelganger",
                "url": "https://gist.github.com/1wErt3r/4048722",
                "repository_import_commit": IMPORT_COMMIT,
                "repository_import_path": "src/smbdis.asm",
                "label_policy": (
                    "Colon labels in the imported source, including labels "
                    "sharing a line with their first statement."
                ),
            },
        )
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
        source_paths = sorted(
            path
            for path in (PROJECT_ROOT / "src").rglob("*")
            if path.is_file() and path.suffix.lower() in {".asm", ".inc"}
        )
        for source_path in source_paths:
            relative_path = source_path.relative_to(PROJECT_ROOT).as_posix()
            lines = source_path.read_text(encoding="utf-8").splitlines()
            self.assertFalse(
                any("; was:" in line.lower() for line in lines),
                f"inline label provenance remains in {relative_path}",
            )
            labels = {
                match.group(1)
                for line in lines
                if (match := SOURCE_LABEL_RE.fullmatch(line))
            }
            source_labels[relative_path] = labels

        for current, relative_path in mapped_labels:
            self.assertRegex(current, LABEL_RE)
            self.assertIn(relative_path, source_labels)
            self.assertIn(current, source_labels[relative_path])

        for _, _, introduced_in_commit, reason in additions:
            self.assertRegex(introduced_in_commit, COMMIT_RE)
            self.assertTrue(reason.strip())

        active_labels = {
            (label, relative_path)
            for relative_path, labels in source_labels.items()
            for label in labels
        }
        self.assertEqual(set(mapped_labels), active_labels)


if __name__ == "__main__":
    unittest.main()
