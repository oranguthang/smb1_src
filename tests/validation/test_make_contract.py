from __future__ import annotations

import sys
import subprocess
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from validation.make_contract import combined_makefile_text, make_targets  # noqa: E402


class MakeContractTests(unittest.TestCase):
    def test_collects_root_and_fragment_targets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "mk").mkdir()
            (root / "Makefile").write_text("root-target:\n", encoding="utf-8")
            (root / "mk" / "runtime.mk").write_text(
                "runtime-target:\n", encoding="utf-8"
            )
            self.assertEqual(
                make_targets(root), {"root-target", "runtime-target"}
            )

    def test_public_help_lists_the_release_and_profile_commands(self) -> None:
        project_root = Path(__file__).resolve().parents[2]
        result = subprocess.run(
            ["make", "help"],
            cwd=project_root,
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertIn("release-check", result.stdout)
        self.assertIn("verify-revisions", result.stdout)
        self.assertIn("source-3-check", result.stdout)

    def test_ann_supplemental_build_prepares_private_inputs(self) -> None:
        project_root = Path(__file__).resolve().parents[2]
        make_text = combined_makefile_text(project_root)
        self.assertIn(
            "build-ann-supplemental-courses: prepare-ann-supplemental-assets",
            make_text,
        )
        self.assertIn("prepare-ann-supplemental-assets:", make_text)
        self.assertIn("--profile ann_fds", make_text)


if __name__ == "__main__":
    unittest.main()
