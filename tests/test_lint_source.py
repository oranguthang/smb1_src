from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

import lint_source  # noqa: E402


class LintSourceTests(unittest.TestCase):
    def make_project(self, source: str) -> Path:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root / "src").mkdir()
        (root / "src" / "main.asm").write_text(source, encoding="utf-8")
        return root

    def messages(self, source: str) -> list[str]:
        return [
            diagnostic.message
            for diagnostic in lint_source.lint_project(self.make_project(source))
        ]

    def test_accepts_matching_subroutine_and_caller(self) -> None:
        messages = self.messages(
            "    JSR sub_update_player\n"
            "    RTS\n"
            "sub_update_player:\n"
            "    RTS\n"
        )
        self.assertEqual(messages, [])

    def test_accepts_jsr_target_defined_by_symbol_assignment(self) -> None:
        messages = self.messages(
            "sub_platform_dispatch = $c000\n"
            "    JSR sub_platform_dispatch\n"
            "    RTS\n"
        )
        self.assertEqual(messages, [])

    def test_rejects_legacy_jsr_target(self) -> None:
        messages = self.messages("    JSR UpdatePlayer\nUpdatePlayer:\n    RTS\n")
        self.assertIn(
            "direct JSR target must use sub_ prefix: UpdatePlayer", messages
        )

    def test_rejects_orphan_subroutine_label(self) -> None:
        messages = self.messages("sub_update_player:\n    RTS\n")
        self.assertIn(
            "sub_ label has no direct JSR caller: sub_update_player", messages
        )

    def test_rejects_unknown_lowercase_prefix(self) -> None:
        messages = self.messages("helper_update_player:\n    RTS\n")
        self.assertIn(
            "lowercase symbol uses unsupported prefix: helper_update_player",
            messages,
        )

    def test_rejects_legacy_label_case(self) -> None:
        messages = self.messages("LegacyLabel:\n    RTS\n")
        self.assertIn(
            "label must use a role prefix and lowercase snake_case: LegacyLabel",
            messages,
        )

    def test_rejects_malformed_snake_case_label(self) -> None:
        messages = self.messages("loc_update__player:\n    RTS\n")
        self.assertIn(
            "label must use a role prefix and lowercase snake_case: "
            "loc_update__player",
            messages,
        )

    def test_allows_constant_case_outside_colon_labels(self) -> None:
        self.assertEqual(self.messages("HARDWARE_MASK = $01\n"), [])

    def test_rejects_address_derived_name(self) -> None:
        messages = self.messages("loc_C123:\n    RTS\n")
        self.assertIn(
            "active symbol embeds an address-like segment: loc_C123", messages
        )

    def test_accepts_hex_like_words_without_digits(self) -> None:
        messages = self.messages("bra_face_player:\n    RTS\n")
        self.assertEqual(messages, [])

    def test_rejects_inline_label_provenance(self) -> None:
        messages = self.messages("sub_example:  ; was: sub_C000\n    RTS\n")
        self.assertIn(
            "inline label provenance is forbidden; update "
            "docs/provenance/label_renames.json",
            messages,
        )

    def test_rejects_any_content_after_label_colon(self) -> None:
        for suffix in (" ", "  ; explanation", " LDA #$01"):
            with self.subTest(suffix=suffix):
                messages = self.messages(f"sub_example:{suffix}\n    RTS\n")
                self.assertIn("label line must end immediately after ':'", messages)


if __name__ == "__main__":
    unittest.main()
