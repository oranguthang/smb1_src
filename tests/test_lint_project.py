from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

import lint_project  # noqa: E402


class LintProjectTests(unittest.TestCase):
    def make_project(self) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        for directory in ("docs", "src", "scripts", "tests"):
            (root / directory).mkdir()
        (root / "README.md").write_text("# Test\n", encoding="utf-8")
        (root / "docs" / "unknowns.md").write_text(
            "# Unknowns\n\n### CODE-001 Test\n", encoding="utf-8"
        )
        return root

    def test_accepts_registered_evidence_and_symbolic_hardware(self) -> None:
        root = self.make_project()
        (root / "src" / "main.asm").write_text(
            "; !(UNKNOWN) CODE-001 - test\n    STA PPU_DATA\n", encoding="utf-8"
        )
        self.assertEqual(lint_project.lint_project(root), [])

    def test_rejects_unregistered_evidence_id(self) -> None:
        root = self.make_project()
        (root / "src" / "main.asm").write_text(
            "; !(WHY?) CODE-999 - test\n", encoding="utf-8"
        )
        messages = [item.message for item in lint_project.lint_project(root)]
        self.assertIn("evidence ID is absent from docs/unknowns.md: CODE-999", messages)

    def test_rejects_raw_hardware_operand(self) -> None:
        root = self.make_project()
        (root / "src" / "main.asm").write_text(
            "; !(UNUSED) CODE-001 - test\n    STA $2007\n", encoding="utf-8"
        )
        messages = [item.message for item in lint_project.lint_project(root)]
        self.assertIn(
            "raw PPU/APU/I/O operand must use hardware.inc symbol: $2007", messages
        )

    def test_rejects_broken_local_markdown_link(self) -> None:
        root = self.make_project()
        (root / "src" / "main.asm").write_text(
            "; !(UNUSED) CODE-001 - test\n", encoding="utf-8"
        )
        (root / "README.md").write_text("[missing](docs/missing.md)\n", encoding="utf-8")
        messages = [item.message for item in lint_project.lint_project(root)]
        self.assertIn("broken local Markdown link: docs/missing.md", messages)


if __name__ == "__main__":
    unittest.main()
