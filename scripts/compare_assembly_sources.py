#!/usr/bin/env python3
"""Find shared instruction runs in assembled ca65 source profiles."""

from __future__ import annotations

import argparse
import difflib
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from asm_style import LABEL_RE, MNEMONICS, split_comment


LISTING_LINE_RE = re.compile(
    r"^(?P<address>[0-9A-F]{6})\s+(?P<depth>\d+)\s+(?P<body>.*)$"
)
LISTING_BYTES_RE = re.compile(
    r"^(?P<bytes>(?:(?:[0-9A-F]{2}|rr)\s+)+?)\s{2,}(?P<source>\S.*)$"
)
MAX_REPORTED_BLOCKS = 40


@dataclass(frozen=True)
class Instruction:
    address: int
    opcode: int
    encoded: tuple[str, ...]
    mnemonic: str
    statement: str
    listing_line: int

    def token(self, preserve_immediates: bool) -> str:
        if preserve_immediates and self.statement.lstrip().startswith("#"):
            immediate = self.encoded[1] if len(self.encoded) > 1 else "??"
            return f"{self.opcode:02X}:{immediate}"
        return f"{self.opcode:02X}"


@dataclass(frozen=True)
class MatchBlock:
    left: int
    right: int
    size: int


def parse_listing(text: str) -> list[Instruction]:
    """Read only instructions that ca65 actually emitted into a payload."""

    instructions: list[Instruction] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        match = LISTING_LINE_RE.match(line)
        if match is None:
            continue
        body = LISTING_BYTES_RE.match(match.group("body"))
        if body is None:
            continue
        encoded = tuple(body.group("bytes").split())
        if not encoded or not re.fullmatch(r"[0-9A-F]{2}", encoded[0]):
            continue
        source, _comment = split_comment(body.group("source"))
        statement = source.strip()
        label = LABEL_RE.match(statement)
        if label is not None:
            statement = label.group("tail").strip()
        if not statement:
            continue
        parts = statement.split(None, 1)
        mnemonic = parts[0].upper()
        if mnemonic not in MNEMONICS:
            continue
        operand = parts[1].strip() if len(parts) > 1 else ""
        instructions.append(Instruction(
            address=int(match.group("address"), 16),
            opcode=int(encoded[0], 16),
            encoded=encoded,
            mnemonic=mnemonic,
            statement=operand,
            listing_line=line_number,
        ))
    return instructions


def matching_blocks(
    left_tokens: list[str],
    right_tokens: list[str],
    minimum: int,
) -> list[MatchBlock]:
    """Return maximal exact common substrings of at least minimum tokens."""

    if minimum <= 0:
        raise ValueError("minimum match length must be positive")
    if len(left_tokens) < minimum or len(right_tokens) < minimum:
        return []

    matcher = difflib.SequenceMatcher(
        None,
        left_tokens,
        right_tokens,
        autojunk=False,
    )
    return [
        MatchBlock(block.a, block.b, block.size)
        for block in matcher.get_matching_blocks()
        if block.size >= minimum
    ]


def covered_indexes(blocks: Iterable[MatchBlock], side: str) -> set[int]:
    result: set[int] = set()
    for block in blocks:
        start = block.left if side == "left" else block.right
        result.update(range(start, start + block.size))
    return result


def uncovered_ranges(length: int, covered: set[int]) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    start: int | None = None
    for index in range(length + 1):
        is_uncovered = index < length and index not in covered
        if is_uncovered and start is None:
            start = index
        elif not is_uncovered and start is not None:
            ranges.append((start, index - start))
            start = None
    return ranges


def location(instruction: Instruction) -> dict[str, Any]:
    return {
        "address": f"0x{instruction.address:04x}",
        "listing_line": instruction.listing_line,
        "instruction": " ".join(
            part for part in (instruction.mnemonic, instruction.statement) if part
        ),
    }


def analyze_mode(
    left: list[Instruction],
    right: list[Instruction],
    minimum: int,
    preserve_immediates: bool,
) -> dict[str, Any]:
    left_tokens = [item.token(preserve_immediates) for item in left]
    right_tokens = [item.token(preserve_immediates) for item in right]
    blocks = matching_blocks(left_tokens, right_tokens, minimum)
    left_covered = covered_indexes(blocks, "left")
    right_covered = covered_indexes(blocks, "right")
    left_uncovered = uncovered_ranges(len(left), left_covered)
    right_uncovered = uncovered_ranges(len(right), right_covered)
    reported_blocks = sorted(
        blocks,
        key=lambda block: (-block.size, block.left, block.right),
    )[:MAX_REPORTED_BLOCKS]

    def render_uncovered(
        instructions: list[Instruction], ranges: list[tuple[int, int]]
    ) -> list[dict[str, Any]]:
        return [
            {
                "instructions": size,
                "start": location(instructions[start]),
                "end": location(instructions[start + size - 1]),
            }
            for start, size in sorted(ranges, key=lambda item: (-item[1], item[0]))[
                :MAX_REPORTED_BLOCKS
            ]
        ]

    return {
        "minimum_instructions": minimum,
        "matched_blocks": len(blocks),
        "left_covered_instructions": len(left_covered),
        "right_covered_instructions": len(right_covered),
        "left_coverage_percent": round(100.0 * len(left_covered) / len(left), 2),
        "right_coverage_percent": round(100.0 * len(right_covered) / len(right), 2),
        "left_unmatched_ranges": render_uncovered(left, left_uncovered),
        "right_unmatched_ranges": render_uncovered(right, right_uncovered),
        "blocks": [
            {
                "instructions": block.size,
                "left_start": location(left[block.left]),
                "left_end": location(left[block.left + block.size - 1]),
                "right_start": location(right[block.right]),
                "right_end": location(right[block.right + block.size - 1]),
            }
            for block in reported_blocks
        ],
    }


def assemble_listing(
    project_root: Path,
    assembler: Path,
    work_dir: Path,
    specification: dict[str, Any],
) -> tuple[Path, list[Instruction]]:
    identifier = specification["id"]
    source = project_root / specification["source"]
    listing = work_dir / f"{identifier}.lst"
    object_path = work_dir / f"{identifier}.o"
    command = [str(assembler), str(source), "-g", "-o", str(object_path), "-l", str(listing)]
    for include_dir in specification["include_dirs"]:
        command.extend(("-I", str(project_root / include_dir)))
    completed = subprocess.run(
        command,
        cwd=project_root,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        output = "\n".join(part for part in (completed.stdout, completed.stderr) if part)
        raise RuntimeError(f"ca65 failed for {identifier}:\n{output}")
    instructions = parse_listing(listing.read_text(encoding="utf-8"))
    if not instructions:
        raise ValueError(f"ca65 listing contains no emitted instructions: {identifier}")
    return listing, instructions


def analyze(
    project_root: Path,
    assembler: Path,
    manifest: dict[str, Any],
    work_dir: Path,
) -> dict[str, Any]:
    if manifest.get("schema_version") != 1:
        raise ValueError("later-engine source-overlap manifest must use schema 1")
    minimum = int(manifest["minimum_instructions"])
    work_dir.mkdir(parents=True, exist_ok=True)
    programs: dict[str, list[Instruction]] = {}
    program_results = []
    for specification in manifest["programs"]:
        listing, instructions = assemble_listing(
            project_root, assembler, work_dir, specification
        )
        identifier = specification["id"]
        if identifier in programs:
            raise ValueError(f"duplicate source-overlap program: {identifier}")
        programs[identifier] = instructions
        program_results.append({
            "id": identifier,
            "source": specification["source"],
            "instructions": len(instructions),
            "listing": listing.relative_to(project_root).as_posix(),
        })

    comparisons = []
    for specification in manifest["comparisons"]:
        left = programs[specification["ann"]]
        right = programs[specification["smb2"]]
        comparisons.append({
            "id": specification["id"],
            "ann": specification["ann"],
            "smb2": specification["smb2"],
            "ann_instructions": len(left),
            "smb2_instructions": len(right),
            "opcode_shape": analyze_mode(left, right, minimum, False),
            "opcode_and_immediates": analyze_mode(left, right, minimum, True),
        })
    return {
        "schema_version": 1,
        "normalization": {
            "opcode_shape": "6502 opcode and addressing mode; all operands ignored",
            "opcode_and_immediates": "opcode shape with immediate constants retained",
            "comments_labels_and_formatting": "ignored",
            "inactive_conditionals": "excluded by ca65 listings",
        },
        "programs": program_results,
        "comparisons": comparisons,
    }


def print_summary(report: dict[str, Any]) -> None:
    print("Later-engine source overlap")
    for comparison in report["comparisons"]:
        shape = comparison["opcode_shape"]
        constants = comparison["opcode_and_immediates"]
        print(
            f"[OK] {comparison['id']}: "
            f"shape {shape['left_coverage_percent']:.2f}% ANN / "
            f"{shape['right_coverage_percent']:.2f}% SMB2; "
            f"constants {constants['left_coverage_percent']:.2f}% ANN / "
            f"{constants['right_coverage_percent']:.2f}% SMB2; "
            f"longest {shape['blocks'][0]['instructions'] if shape['blocks'] else 0} instructions"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_root = Path(__file__).resolve().parent.parent
    parser.add_argument("--project-root", type=Path, default=default_root)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=default_root / "config" / "later_engine_source_overlap.json",
    )
    parser.add_argument(
        "--assembler",
        type=Path,
        default=default_root / "bin" / "ca65.exe",
    )
    parser.add_argument(
        "--work-dir",
        type=Path,
        default=default_root / "build" / "evidence" / "later_engine_source_overlap",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=default_root / "build" / "evidence" / "later_engine_source_overlap.json",
    )
    args = parser.parse_args()
    project_root = args.project_root.resolve()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    try:
        report = analyze(
            project_root,
            args.assembler.resolve(),
            manifest,
            args.work_dir.resolve(),
        )
    except (KeyError, OSError, RuntimeError, ValueError) as exc:
        print(f"[ERROR] {exc}")
        return 1
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print_summary(report)
    print(f"[OK] Detailed report: {args.output.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
