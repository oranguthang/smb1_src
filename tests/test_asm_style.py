from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.asm_style import format_file, lint_file


class AssemblyStyleTests(unittest.TestCase):
    def test_nested_source_passes(self) -> None:
        source = """\
.if ENABLE_DEMO
handler_demo_entry:
    LDA #$01  ; Select demo mode
    .repeat 2
        NOP
    .endrepeat
.endif
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "valid.asm")
            path.write_text(source, encoding="utf-8", newline="\n")
            self.assertEqual(lint_file(path), [])

    def test_common_violations_are_reported(self) -> None:
        source = ";Bad heading\nBad: lda #$00 ;bad comment\n\n\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "invalid.asm")
            path.write_text(source, encoding="utf-8", newline="\n")
            codes = {issue.code for issue in lint_file(path)}

        self.assertTrue(
            {
                "blank-lines",
                "comment-space",
                "final-newline",
                "inline-comment-gap",
                "label-line",
            }.issubset(codes)
        )

    def test_non_ascii_text_is_reported(self) -> None:
        source = "; Привет\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "unicode.asm")
            path.write_text(source, encoding="utf-8", newline="\n")
            issues = lint_file(path)

        self.assertTrue(any(issue.code == "ascii-only" for issue in issues))
        self.assertTrue(any(issue.code == "comment-language" for issue in issues))
        self.assertTrue(any("U+041F" in issue.message for issue in issues))

    def test_leading_blank_line_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "leading-blank.asm")
            path.write_text("\n; Header\n", encoding="utf-8", newline="\n")
            codes = {issue.code for issue in lint_file(path)}

        self.assertIn("file-start", codes)

    def test_terminal_comment_period_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "period.asm")
            path.write_text("; First sentence. Second sentence.\n", encoding="utf-8", newline="\n")
            codes = {issue.code for issue in lint_file(path)}

        self.assertIn("comment-period", codes)

    def test_indented_standalone_comment_is_reported_and_fixed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "comment.asm")
            path.write_text(
                "label:\n    ; Describe the following data\n    .byte $00\n",
                encoding="utf-8",
                newline="\n",
            )

            self.assertIn(
                "comment-indent",
                {issue.code for issue in lint_file(path)},
            )
            self.assertTrue(format_file(path))
            self.assertEqual(
                path.read_text(encoding="utf-8"),
                "label:\n; Describe the following data\n    .byte $00\n",
            )
            self.assertEqual(lint_file(path), [])

    def test_formatter_is_idempotent(self) -> None:
        source = "\n;Header.\nsub_start: lda #$00 ;first sentence. second sentence.\n\n\n"
        expected = "; Header\nsub_start:\n    LDA #$00  ; first sentence. second sentence\n"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "format.asm")
            path.write_text(source, encoding="utf-8", newline="\n")
            self.assertTrue(format_file(path))
            self.assertEqual(path.read_text(encoding="utf-8"), expected)
            self.assertEqual(lint_file(path), [])
            self.assertFalse(format_file(path))

    def test_label_comment_moves_to_preceding_line(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sample.asm"
            path.write_text(
                "sub_example:  ; Explain the entry\n    RTS\n",
                encoding="utf-8",
            )

            self.assertIn("label-line", {issue.code for issue in lint_file(path)})
            self.assertTrue(format_file(path))
            self.assertEqual(
                path.read_text(encoding="utf-8"),
                "; Explain the entry\nsub_example:\n    RTS\n",
            )
            self.assertEqual(lint_file(path), [])


if __name__ == "__main__":
    unittest.main()
