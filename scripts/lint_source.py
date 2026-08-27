#!/usr/bin/env python3
"""Check semantic assembly-source invariants."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


ASM_LINE_LIMIT = 700
APPROVED_SYMBOL_PREFIXES = {
    "bra",
    "con",
    "handler",
    "loc",
    "off",
    "ram",
    "sub",
    "tbl",
    "unused",
    "vec",
    "zp",
}
LABEL_PREFIXES = {"bra", "handler", "loc", "off", "sub", "tbl", "unused", "vec"}

DEFINITION_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*(?::|=)")
STRICT_LABEL_RE = re.compile(
    rf"^(?:{'|'.join(sorted(LABEL_PREFIXES))})_[a-z0-9]+(?:_[a-z0-9]+)*$"
)
ADDRESS_NAME_RE = re.compile(
    r"(?:^|_)(?=[0-9A-Fa-f]{4,6}(?:_|$))"
    r"(?=[0-9A-Fa-f]*[0-9])[0-9A-Fa-f]{4,6}(?=_|$)"
)
JSR_RE = re.compile(r"^\s*JSR\s+([A-Za-z_][A-Za-z0-9_]*)\b")
SUB_LABEL_RE = re.compile(r"^(sub_[A-Za-z0-9_]+):")
PHYSICAL_LABEL_RE = re.compile(
    r"^\s*[A-Za-z_@.?][A-Za-z0-9_@.?]*:(.*)$"
)


@dataclass(frozen=True)
class Diagnostic:
    path: Path
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.path.as_posix()}:{self.line}: {self.message}"


def assembly_paths(project_root: Path) -> list[Path]:
    source_root = project_root / "src"
    return sorted(
        (
            path
            for path in source_root.rglob("*")
            if path.is_file() and path.suffix.lower() in {".asm", ".inc"}
        ),
        key=lambda path: path.as_posix(),
    )


def source_code(line: str) -> str:
    return line.split(";", 1)[0].rstrip()


def lint_project(project_root: Path) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    sub_labels: dict[str, tuple[Path, int]] = {}
    all_labels: dict[str, tuple[Path, int]] = {}
    all_symbols: set[str] = set()
    jsr_targets: dict[str, list[tuple[Path, int]]] = {}

    for absolute_path in assembly_paths(project_root):
        relative_path = absolute_path.relative_to(project_root)
        text = absolute_path.read_text(encoding="utf-8")
        lines = text.splitlines()

        if absolute_path.suffix.lower() == ".asm" and len(lines) > ASM_LINE_LIMIT:
            diagnostics.append(
                Diagnostic(
                    relative_path,
                    1,
                    f"ASM module has {len(lines)} lines; limit is {ASM_LINE_LIMIT}",
                )
            )

        for line_number, line in enumerate(lines, start=1):
            physical_label = PHYSICAL_LABEL_RE.match(line)
            if physical_label is not None and physical_label.group(1):
                diagnostics.append(
                    Diagnostic(
                        relative_path,
                        line_number,
                        "label line must end immediately after ':'",
                    )
                )
            if re.search(r";\s*was:", line, re.IGNORECASE):
                diagnostics.append(
                    Diagnostic(
                        relative_path,
                        line_number,
                        "inline label provenance is forbidden; update "
                        "docs/provenance/label_renames.json",
                    )
                )

            code = source_code(line)
            if not code:
                continue

            definition = DEFINITION_RE.match(code)
            if definition is not None:
                symbol = definition.group(1)
                all_symbols.add(symbol)
                if code.endswith(":"):
                    previous = all_labels.get(symbol)
                    if previous is not None:
                        previous_path, previous_line = previous
                        diagnostics.append(
                            Diagnostic(
                                relative_path,
                                line_number,
                                f"duplicate label {symbol}; first at "
                                f"{previous_path.as_posix()}:{previous_line}",
                            )
                        )
                    else:
                        all_labels[symbol] = (relative_path, line_number)

                    if STRICT_LABEL_RE.fullmatch(symbol) is None:
                        diagnostics.append(
                            Diagnostic(
                                relative_path,
                                line_number,
                                "label must use a role prefix and lowercase "
                                f"snake_case: {symbol}",
                            )
                        )

                if symbol[0].islower():
                    prefix = symbol.split("_", 1)[0]
                    if prefix not in APPROVED_SYMBOL_PREFIXES:
                        diagnostics.append(
                            Diagnostic(
                                relative_path,
                                line_number,
                                f"lowercase symbol uses unsupported prefix: {symbol}",
                            )
                        )

                if ADDRESS_NAME_RE.search(symbol) is not None:
                    diagnostics.append(
                        Diagnostic(
                            relative_path,
                            line_number,
                            f"active symbol embeds an address-like segment: {symbol}",
                        )
                    )

            sub_label = SUB_LABEL_RE.match(code)
            if sub_label is not None:
                name = sub_label.group(1)
                sub_labels[name] = (relative_path, line_number)

            jsr = JSR_RE.match(code)
            if jsr is not None:
                target = jsr.group(1)
                jsr_targets.setdefault(target, []).append(
                    (relative_path, line_number)
                )
                if not target.startswith("sub_"):
                    diagnostics.append(
                        Diagnostic(
                            relative_path,
                            line_number,
                            f"direct JSR target must use sub_ prefix: {target}",
                        )
                    )

    for target, callers in sorted(jsr_targets.items()):
        if target not in all_symbols:
            path, line_number = callers[0]
            diagnostics.append(
                Diagnostic(path, line_number, f"undefined JSR target: {target}")
            )

    for name, (path, line_number) in sorted(sub_labels.items()):
        if name not in jsr_targets:
            diagnostics.append(
                Diagnostic(
                    path,
                    line_number,
                    f"sub_ label has no direct JSR caller: {name}",
                )
            )

    return sorted(
        diagnostics,
        key=lambda item: (item.path.as_posix(), item.line, item.message),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "project_root",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
    )
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    diagnostics = lint_project(project_root)
    if diagnostics:
        for diagnostic in diagnostics:
            print(f"[ERROR] {diagnostic}")
        print(f"[FAIL] Found {len(diagnostics)} semantic source error(s).")
        return 1

    asm_count = sum(
        path.suffix.lower() == ".asm" for path in assembly_paths(project_root)
    )
    print(f"[OK] Validated semantic invariants in {asm_count} ASM modules.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
