#!/usr/bin/env python3
"""Check project-wide source, documentation, and evidence invariants."""

from __future__ import annotations

import argparse
import ast
import re
from dataclasses import dataclass
from pathlib import Path


ALLOWED_EVIDENCE_TAGS = {"OBS", "ASSUME", "WHY?", "UNKNOWN", "BUG?", "UNUSED"}
MATERIAL_EVIDENCE_TAGS = ALLOWED_EVIDENCE_TAGS - {"OBS"}
EVIDENCE_RE = re.compile(r"!\(([A-Z?]+)\)(?:\s+([A-Z]+-\d{3}))?")
REGISTRY_ID_RE = re.compile(r"^###\s+([A-Z]+-\d{3})\b", re.MULTILINE)
MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
HARDWARE_ADDRESS_RE = re.compile(
    r"\$(?:200[0-7]|400[0-9A-Fa-f]|401[0-7])\b", re.IGNORECASE
)


@dataclass(frozen=True)
class Diagnostic:
    path: Path
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.path.as_posix()}:{self.line}: {self.message}"


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def lint_python(project_root: Path) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    paths = sorted((project_root / "scripts").rglob("*.py")) + sorted(
        (project_root / "tests").rglob("*.py")
    )
    for path in paths:
        relative = path.relative_to(project_root)
        try:
            ast.parse(path.read_text(encoding="utf-8"), filename=str(relative))
        except SyntaxError as exc:
            diagnostics.append(
                Diagnostic(relative, exc.lineno or 1, f"invalid Python syntax: {exc.msg}")
            )
    return diagnostics


def normalize_link_target(raw_target: str) -> str:
    target = raw_target.strip()
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    return target.split("#", 1)[0]


def lint_markdown_links(project_root: Path) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    paths = [project_root / "README.md", *sorted((project_root / "docs").rglob("*.md"))]
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for match in MARKDOWN_LINK_RE.finditer(text):
            target = normalize_link_target(match.group(1))
            if not target or "://" in target or target.startswith(("mailto:", "#")):
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                diagnostics.append(
                    Diagnostic(
                        path.relative_to(project_root),
                        line_number(text, match.start()),
                        f"broken local Markdown link: {match.group(1)}",
                    )
                )
    return diagnostics


def evidence_paths(project_root: Path) -> list[Path]:
    return sorted((project_root / "src").rglob("*.asm")) + sorted(
        (project_root / "src").rglob("*.inc")
    )


def lint_evidence(project_root: Path) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    registry_path = project_root / "docs" / "unknowns.md"
    registry_text = registry_path.read_text(encoding="utf-8")
    registry_ids = set(REGISTRY_ID_RE.findall(registry_text))
    referenced_ids: set[str] = set()
    for path in evidence_paths(project_root):
        text = path.read_text(encoding="utf-8")
        for match in EVIDENCE_RE.finditer(text):
            tag, evidence_id = match.groups()
            relative = path.relative_to(project_root)
            current_line = line_number(text, match.start())
            if tag not in ALLOWED_EVIDENCE_TAGS:
                diagnostics.append(Diagnostic(relative, current_line, f"unknown evidence tag: !({tag})"))
                continue
            if tag in MATERIAL_EVIDENCE_TAGS and evidence_id is None:
                diagnostics.append(
                    Diagnostic(relative, current_line, f"!({tag}) requires a registry ID")
                )
            if evidence_id is not None:
                referenced_ids.add(evidence_id)
                if evidence_id not in registry_ids:
                    diagnostics.append(
                        Diagnostic(relative, current_line, f"evidence ID is absent from docs/unknowns.md: {evidence_id}")
                    )
    for evidence_id in sorted(registry_ids - referenced_ids):
        match = re.search(rf"^###\s+{re.escape(evidence_id)}\b", registry_text, re.MULTILINE)
        diagnostics.append(
            Diagnostic(
                registry_path.relative_to(project_root),
                line_number(registry_text, match.start()) if match else 1,
                f"registry ID has no source evidence tag: {evidence_id}",
            )
        )
    return diagnostics


def lint_raw_hardware_operands(project_root: Path) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    for path in evidence_paths(project_root):
        if path.name == "hardware.inc":
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split(";", 1)[0]
            match = HARDWARE_ADDRESS_RE.search(code)
            if match:
                diagnostics.append(
                    Diagnostic(
                        path.relative_to(project_root),
                        number,
                        f"raw PPU/APU/I/O operand must use hardware.inc symbol: {match.group(0)}",
                    )
                )
    return diagnostics


def lint_project(project_root: Path) -> list[Diagnostic]:
    diagnostics = [
        *lint_python(project_root),
        *lint_markdown_links(project_root),
        *lint_evidence(project_root),
        *lint_raw_hardware_operands(project_root),
    ]
    return sorted(diagnostics, key=lambda item: (item.path.as_posix(), item.line, item.message))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "project_root", nargs="?", type=Path,
        default=Path(__file__).resolve().parent.parent,
    )
    args = parser.parse_args()
    project_root = args.project_root.resolve()
    diagnostics = lint_project(project_root)
    if diagnostics:
        for diagnostic in diagnostics:
            print(f"[ERROR] {diagnostic}")
        print(f"[FAIL] Found {len(diagnostics)} project invariant error(s)")
        return 1
    print("[OK] Validated Python syntax, documentation links, evidence tags, and hardware operands")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
