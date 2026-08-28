#!/usr/bin/env python3
"""Run independent Make targets and summarize every failure at the end."""

from __future__ import annotations

import argparse
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


DIAGNOSTIC_PATTERN = re.compile(
    r"(?:\[ERROR\]|\[FAIL\]|\bfatal\b|\berror\b|\*\*\*)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class MatrixStep:
    arguments: tuple[str, ...]

    @property
    def label(self) -> str:
        return "make " + " ".join(self.arguments)


@dataclass(frozen=True)
class MatrixResult:
    step: MatrixStep
    returncode: int
    output: str


def parse_steps(values: Sequence[str]) -> list[MatrixStep]:
    steps: list[MatrixStep] = []
    for value in values:
        arguments = tuple(shlex.split(value))
        if not arguments:
            raise ValueError("matrix steps must not be empty")
        steps.append(MatrixStep(arguments))
    if not steps:
        raise ValueError("at least one matrix step is required")
    return steps


def run_matrix(
    steps: Sequence[MatrixStep],
    project_dir: Path,
    make_program: str,
) -> list[MatrixResult]:
    results: list[MatrixResult] = []
    for index, step in enumerate(steps, start=1):
        command = [make_program, *step.arguments]
        print(f"\n[{index}/{len(steps)}] {step.label}", flush=True)
        try:
            completed = subprocess.run(
                command,
                cwd=project_dir,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                errors="replace",
            )
            output = completed.stdout or ""
            returncode = completed.returncode
        except OSError as exc:
            output = f"[ERROR] Could not run {step.label}: {exc}\n"
            returncode = 127
        if output:
            print(output, end="" if output.endswith("\n") else "\n")
        results.append(MatrixResult(step, returncode, output))
    return results


def failure_excerpt(output: str, tail_lines: int = 12) -> str:
    lines = output.splitlines()
    if not lines:
        return "(no output captured)"
    selected = {
        index
        for index, line in enumerate(lines)
        if DIAGNOSTIC_PATTERN.search(line)
    }
    selected.update(range(max(0, len(lines) - tail_lines), len(lines)))
    return "\n".join(lines[index] for index in sorted(selected))


def print_summary(results: Sequence[MatrixResult], title: str) -> None:
    print(f"\n{title} summary")
    for result in results:
        status = "PASS" if result.returncode == 0 else f"FAIL ({result.returncode})"
        print(f"[{status}] {result.step.label}")

    failures = [result for result in results if result.returncode != 0]
    if not failures:
        print("\n[OK] Every command completed successfully.")
        return

    print("\nFailure details")
    for result in failures:
        print(f"\n--- {result.step.label} (exit {result.returncode}) ---")
        print(failure_excerpt(result.output))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-dir", required=True, type=Path)
    parser.add_argument("--make", default="make", dest="make_program")
    parser.add_argument("--title", required=True)
    parser.add_argument("--step", action="append", default=[])
    args = parser.parse_args()
    try:
        steps = parse_steps(args.step)
    except ValueError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2
    results = run_matrix(steps, args.project_dir, args.make_program)
    print_summary(results, args.title)
    return 1 if any(result.returncode != 0 for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
