from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from validation.source_3_1_audit import (  # noqa: E402
    validate_layout,
    validate_release_history,
    validate_release_objects,
    validate_source_3_1,
)


class Source31AuditTests(unittest.TestCase):
    def test_project_manifest_is_consistent_during_development(self) -> None:
        self.assertEqual(
            validate_source_3_1(
                PROJECT_ROOT,
                PROJECT_ROOT / "config" / "source_reconstruction_3_1.json",
            ),
            [],
        )

    def test_repository_layout_inventory_is_complete(self) -> None:
        self.assertEqual(
            validate_layout(
                PROJECT_ROOT,
                PROJECT_ROOT
                / "config"
                / "reconstruction"
                / "repository_layout.json",
            ),
            [],
        )

    def test_empty_release_commit_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(
                ["git", "config", "user.name", "Test Maintainer"],
                cwd=root,
                check=True,
            )
            subprocess.run(
                ["git", "config", "user.email", "maintainer@example.invalid"],
                cwd=root,
                check=True,
            )
            (root / "baseline.txt").write_text("baseline\n", encoding="utf-8")
            subprocess.run(["git", "add", "baseline.txt"], cwd=root, check=True)
            baseline_env = {
                **os.environ,
                "GIT_AUTHOR_DATE": "2026-01-01T00:00:00+00:00",
                "GIT_COMMITTER_DATE": "2026-01-01T00:00:00+00:00",
            }
            subprocess.run(
                ["git", "commit", "-q", "-m", "Create baseline"],
                cwd=root,
                check=True,
                env=baseline_env,
            )
            predecessor = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=root,
                check=True,
                capture_output=True,
                text=True,
                encoding="utf-8",
            ).stdout.strip()
            empty_env = {
                **os.environ,
                "GIT_AUTHOR_DATE": "2026-01-01T00:00:01+00:00",
                "GIT_COMMITTER_DATE": "2026-01-01T00:00:01+00:00",
            }
            subprocess.run(
                [
                    "git",
                    "commit",
                    "--allow-empty",
                    "-q",
                    "-m",
                    "Exercise empty history validation",
                    "-m",
                    "Create a synthetic empty release commit for the validator fixture.",
                    "-m",
                    "The project history policy must reject this otherwise valid message.",
                    "-m",
                    "Co-Authored-By: Codex <noreply@openai.com>",
                ],
                cwd=root,
                check=True,
                env=empty_env,
            )
            errors = validate_release_history(
                root,
                predecessor,
                {
                    "allowed_identities": [
                        {
                            "name": "Test Maintainer",
                            "email": "maintainer@example.invalid",
                        }
                    ],
                    "required_coauthor": "Co-Authored-By: Codex <noreply@openai.com>",
                },
            )
            self.assertTrue(any("release commit is empty" in error for error in errors))

    def test_intermediate_cyrillic_blob_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(
                ["git", "config", "user.name", "Test Maintainer"],
                cwd=root,
                check=True,
            )
            subprocess.run(
                ["git", "config", "user.email", "maintainer@example.invalid"],
                cwd=root,
                check=True,
            )
            (root / "baseline.txt").write_text("baseline\n", encoding="utf-8")
            subprocess.run(["git", "add", "baseline.txt"], cwd=root, check=True)
            subprocess.run(
                ["git", "commit", "-q", "-m", "Create baseline"],
                cwd=root,
                check=True,
            )
            predecessor = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=root,
                check=True,
                capture_output=True,
                text=True,
                encoding="utf-8",
            ).stdout.strip()
            forbidden_text = "".join(chr(value) for value in (0x0422, 0x0435, 0x0441, 0x0442))
            (root / "temporary.txt").write_text(forbidden_text, encoding="utf-8")
            subprocess.run(["git", "add", "temporary.txt"], cwd=root, check=True)
            subprocess.run(
                ["git", "commit", "-q", "-m", "Add temporary evidence"],
                cwd=root,
                check=True,
            )
            (root / "temporary.txt").unlink()
            subprocess.run(["git", "add", "-u"], cwd=root, check=True)
            subprocess.run(
                ["git", "commit", "-q", "-m", "Remove temporary evidence"],
                cwd=root,
                check=True,
            )
            errors = validate_release_objects(root, predecessor)
            self.assertTrue(
                any("release range introduces a Cyrillic blob" in error for error in errors)
            )


if __name__ == "__main__":
    unittest.main()
