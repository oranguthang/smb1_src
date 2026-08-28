from __future__ import annotations

import io
import subprocess
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from run_make_matrix import (  # noqa: E402
    MatrixStep,
    failure_excerpt,
    parse_steps,
    print_summary,
    run_matrix,
)


class MakeMatrixTests(unittest.TestCase):
    def test_steps_preserve_make_variable_assignments(self) -> None:
        self.assertEqual(
            parse_steps(["verify-revision PROFILE=pal"]),
            [MatrixStep(("verify-revision", "PROFILE=pal"))],
        )

    def test_matrix_continues_after_failure_and_reports_each_result(self) -> None:
        completed = [
            subprocess.CompletedProcess([], 2, "[ERROR] first failed\n"),
            subprocess.CompletedProcess([], 0, "second passed\n"),
        ]
        steps = [MatrixStep(("first",)), MatrixStep(("second",))]
        output = io.StringIO()
        with patch("run_make_matrix.subprocess.run", side_effect=completed) as run:
            with redirect_stdout(output):
                results = run_matrix(steps, Path("project"), "make")
                print_summary(results, "Test matrix")
        self.assertEqual([result.returncode for result in results], [2, 0])
        self.assertEqual(run.call_count, 2)
        self.assertIn("[FAIL (2)] make first", output.getvalue())
        self.assertIn("[PASS] make second", output.getvalue())
        self.assertIn("[ERROR] first failed", output.getvalue())

    def test_failure_excerpt_keeps_diagnostics_and_log_tail(self) -> None:
        lines = ["[ERROR] early failure", *(f"line {index}" for index in range(20))]
        excerpt = failure_excerpt("\n".join(lines), tail_lines=2)
        self.assertEqual(excerpt.splitlines(), ["[ERROR] early failure", "line 18", "line 19"])


if __name__ == "__main__":
    unittest.main()
