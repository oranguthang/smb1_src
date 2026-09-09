#!/usr/bin/env python3
"""Check project-wide source, documentation, and evidence invariants."""

from __future__ import annotations

import argparse
import ast
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


ALLOWED_EVIDENCE_TAGS = {"OBS", "ASSUME", "WHY?", "UNKNOWN", "BUG?", "UNUSED"}
MATERIAL_EVIDENCE_TAGS = ALLOWED_EVIDENCE_TAGS - {"OBS"}
EVIDENCE_RE = re.compile(r"!\(([A-Z?]+)\)(?:\s+([A-Z]+-\d{3}))?")
REGISTRY_ID_RE = re.compile(r"^###\s+([A-Z]+-\d{3})\b", re.MULTILINE)
MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
CYRILLIC_RE = re.compile(r"[\u0400-\u052f]")
HARDWARE_ADDRESS_RE = re.compile(
    r"\$(?:200[0-7]|400[0-9A-Fa-f]|401[0-7])\b", re.IGNORECASE
)
TEXT_SUFFIXES = {
    ".asm",
    ".cfg",
    ".fm2",
    ".inc",
    ".json",
    ".lua",
    ".md",
    ".py",
    ".txt",
}
TEXT_FILENAMES = {".editorconfig", ".gitattributes", ".gitignore", "Makefile"}
FALLBACK_IGNORED_PARTS = {".git", "__pycache__", "build", "references"}


@dataclass(frozen=True)
class Diagnostic:
    path: Path
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.path.as_posix()}:{self.line}: {self.message}"


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def is_text_path(path: Path) -> bool:
    return path.name in TEXT_FILENAMES or path.suffix.lower() in TEXT_SUFFIXES


def tracked_paths(project_root: Path) -> list[Path]:
    try:
        result = subprocess.run(
            ["git", "ls-files"],
            cwd=project_root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=False,
        )
    except FileNotFoundError:
        result = None
    if result is not None and result.returncode == 0:
        return sorted(
            project_root / relative
            for relative in result.stdout.splitlines()
            if relative and (project_root / relative).is_file()
        )

    return sorted(
        path
        for path in project_root.rglob("*")
        if path.is_file()
        and not FALLBACK_IGNORED_PARTS.intersection(
            path.relative_to(project_root).parts
        )
        and path.relative_to(project_root).parts[:2] != ("assets", "generated")
    )


def lint_text_content(path: Path, text: str) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    if not text.endswith("\n"):
        diagnostics.append(Diagnostic(path, 1, "text file must end with one newline"))
    elif text.endswith("\n\n"):
        diagnostics.append(
            Diagnostic(path, len(text.splitlines()) or 1, "text file has a blank line at EOF")
        )
    for number, line in enumerate(text.splitlines(), start=1):
        if line.endswith((" ", "\t")):
            diagnostics.append(Diagnostic(path, number, "trailing whitespace"))
    return diagnostics


def lint_tracked_text(project_root: Path) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    for path in tracked_paths(project_root):
        relative = path.relative_to(project_root)
        if not is_text_path(relative):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            diagnostics.append(Diagnostic(relative, 1, f"text file is not UTF-8: {exc}"))
            continue
        diagnostics.extend(lint_text_content(relative, text))
    return diagnostics


def lint_public_language(project_root: Path) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    for path in tracked_paths(project_root):
        relative = path.relative_to(project_root)
        if not is_text_path(relative):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for match in CYRILLIC_RE.finditer(text):
            diagnostics.append(
                Diagnostic(
                    relative,
                    line_number(text, match.start()),
                    "public project text must be English and contain no Cyrillic",
                )
            )
    return diagnostics


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
    paths = [
        path
        for path in (
            project_root / "README.md",
            project_root / "CONTRIBUTING.md",
            *sorted((project_root / "docs").rglob("*.md")),
        )
        if path.is_file()
    ]
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


def documentation_paths(project_root: Path) -> list[Path]:
    candidates = [
        project_root / "README.md",
        project_root / "CONTRIBUTING.md",
        *sorted((project_root / "docs").rglob("*.md")),
        project_root / "bin" / "README.md",
        project_root / "movies" / "README.md",
    ]
    return [path for path in candidates if path.is_file()]


def documentation_prefix(path: str) -> str | None:
    stem = Path(path).stem
    parts = stem.split("_")
    if len(parts) < 2:
        return None
    return "_".join(parts[:2])


def lint_documentation_corpus(project_root: Path) -> list[Diagnostic]:
    manifest_path = (
        project_root / "config" / "reconstruction" / "documentation_corpus.json"
    )
    if not manifest_path.is_file():
        return []
    relative_manifest = manifest_path.relative_to(project_root)
    document = json.loads(manifest_path.read_text(encoding="utf-8"))
    diagnostics: list[Diagnostic] = []
    if document.get("schema_version") != 1:
        diagnostics.append(Diagnostic(relative_manifest, 1, "documentation corpus schema differs"))

    for relative in ("docs/adr", "docs/provenance"):
        if (project_root / relative).exists():
            diagnostics.append(
                Diagnostic(
                    Path(relative),
                    1,
                    "deprecated documentation category directory must be removed",
                )
            )

    records = document.get("documents", [])
    declared = [item.get("path") for item in records]
    actual = [path.relative_to(project_root).as_posix() for path in documentation_paths(project_root)]
    if len(declared) != len(set(declared)):
        diagnostics.append(Diagnostic(relative_manifest, 1, "documentation inventory contains duplicate paths"))
    if set(declared) != set(actual):
        missing = sorted(set(actual) - set(declared))
        stale = sorted(set(declared) - set(actual))
        diagnostics.append(
            Diagnostic(
                relative_manifest,
                1,
                f"documentation inventory differs; missing={missing}, stale={stale}",
            )
        )
    for item in records:
        if not item.get("owner") or not item.get("purpose") or item.get("decision") != "retain":
            diagnostics.append(
                Diagnostic(relative_manifest, 1, f"documentation review is incomplete: {item.get('path')}")
            )

    maximum_lines = document.get("maximum_reviewed_lines", 600)
    oversize = {item.get("path"): item for item in document.get("oversize_reviews", [])}
    for path in documentation_paths(project_root):
        relative = path.relative_to(project_root).as_posix()
        count = len(path.read_text(encoding="utf-8").splitlines())
        if count > maximum_lines and not oversize.get(relative, {}).get("reason"):
            diagnostics.append(
                Diagnostic(Path(relative), 1, f"documentation has {count} lines without an oversize review")
            )

    groups: dict[str, list[str]] = {}
    for relative in actual:
        if not relative.startswith("docs/"):
            continue
        prefix = documentation_prefix(relative)
        if prefix is not None:
            groups.setdefault(prefix, []).append(relative)
    exemptions = {
        item.get("prefix"): item.get("reason")
        for item in document.get("prefix_exemptions", [])
    }
    for prefix, paths in sorted(groups.items()):
        if len(paths) > 1 and not exemptions.get(prefix):
            diagnostics.append(
                Diagnostic(relative_manifest, 1, f"repeated documentation prefix lacks review: {prefix} ({paths})")
            )

    for journey in document.get("reader_journeys", []):
        paths = journey.get("paths", [])
        if not journey.get("id") or not paths or any(path not in actual for path in paths):
            diagnostics.append(
                Diagnostic(relative_manifest, 1, f"reader journey is incomplete: {journey.get('id')}")
            )
    for item in document.get("consolidations", []):
        destination = item.get("destination")
        sources = item.get("sources", [])
        if not item.get("reason") or destination not in actual:
            diagnostics.append(Diagnostic(relative_manifest, 1, "documentation consolidation is incomplete"))
        if any((project_root / source).exists() for source in sources):
            diagnostics.append(Diagnostic(relative_manifest, 1, f"consolidated document still exists: {sources}"))
    for item in document.get("configuration_moves", []):
        source = item.get("source", "")
        destination = item.get("destination", "")
        if (
            not item.get("reason")
            or not destination
            or not (project_root / destination).is_file()
        ):
            diagnostics.append(Diagnostic(relative_manifest, 1, "documentation configuration move is incomplete"))
        if source and (project_root / source).exists():
            diagnostics.append(Diagnostic(relative_manifest, 1, f"moved documentation configuration still exists: {source}"))
    return diagnostics


def lint_label_registry_location(project_root: Path) -> list[Diagnostic]:
    canonical = project_root / "config" / "reconstruction" / "label_renames.json"
    diagnostics: list[Diagnostic] = []
    if not canonical.parent.is_dir():
        return diagnostics
    if not canonical.is_file():
        diagnostics.append(
            Diagnostic(Path("config/reconstruction/label_renames.json"), 1, "canonical label registry is missing")
        )
    else:
        try:
            document = json.loads(canonical.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            diagnostics.append(
                Diagnostic(canonical.relative_to(project_root), exc.lineno, "canonical label registry is invalid JSON")
            )
        else:
            if document.get("schema_version") != 1 or set(document.get("registries", {})) != {"smb1", "smb2"}:
                diagnostics.append(
                    Diagnostic(canonical.relative_to(project_root), 1, "canonical label registry schema differs")
                )
    candidates = [
        path
        for root in (project_root / "config", project_root / "docs")
        for path in root.rglob("*.json")
        if "label" in path.name.lower() and "rename" in path.name.lower()
    ]
    extras = [path for path in candidates if path.resolve() != canonical.resolve()]
    for path in extras:
        diagnostics.append(
            Diagnostic(path.relative_to(project_root), 1, "duplicate label registry must be removed")
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
        *lint_tracked_text(project_root),
        *lint_public_language(project_root),
        *lint_python(project_root),
        *lint_markdown_links(project_root),
        *lint_documentation_corpus(project_root),
        *lint_label_registry_location(project_root),
        *lint_evidence(project_root),
        *lint_raw_hardware_operands(project_root),
    ]
    return sorted(diagnostics, key=lambda item: (item.path.as_posix(), item.line, item.message))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "project_root", nargs="?", type=Path,
        default=Path(__file__).resolve().parents[2],
    )
    args = parser.parse_args()
    project_root = args.project_root.resolve()
    diagnostics = lint_project(project_root)
    if diagnostics:
        for diagnostic in diagnostics:
            print(f"[ERROR] {diagnostic}")
        print(f"[FAIL] Found {len(diagnostics)} project invariant error(s)")
        return 1
    print(
        "[OK] Validated tracked text, Python syntax, documentation links, "
        "evidence tags, and hardware operands"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
