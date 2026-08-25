#!/usr/bin/env python3
"""Check or normalize the project's ca65 assembly style."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


MNEMONICS = frozenset(
    """
    ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD CLI CLV
    CMP CPX CPY DEC DEX DEY EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP
    ORA PHA PHP PLA PLP ROL ROR RTI RTS SBC SEC SED SEI STA STX STY TAX
    TAY TSX TXA TXS TYA
    """.split()
)

DATA_DIRECTIVES = frozenset(
    {
        ".addr",
        ".asciiz",
        ".byte",
        ".dbyt",
        ".faraddr",
        ".incbin",
        ".literal",
        ".res",
        ".tag",
        ".word",
    }
)

BLOCK_OPENERS = frozenset(
    {
        ".enum",
        ".macro",
        ".proc",
        ".repeat",
        ".scope",
        ".struct",
        ".union",
    }
)
BLOCK_CLOSERS = frozenset(
    {
        ".endenum",
        ".endmacro",
        ".endproc",
        ".endrepeat",
        ".endscope",
        ".endstruct",
        ".endunion",
    }
)
BLOCK_MIDDLES = frozenset({".else", ".elseif"})

DIRECTIVE_RE = re.compile(r"^\.[A-Za-z][A-Za-z0-9]*")
LABEL_RE = re.compile(r"^(?P<label>[A-Za-z_@.?][A-Za-z0-9_@.?]*:)(?P<tail>.*)$")
TOKEN_RE = re.compile(r"^[A-Za-z][A-Za-z0-9]*")
ASSIGNMENT_RE = re.compile(r"^[A-Za-z_@.?][A-Za-z0-9_@.?]*\s*=")


@dataclass(frozen=True)
class Issue:
    path: Path
    line: int
    code: str
    message: str

    def render(self) -> str:
        return f"{self.path.as_posix()}:{self.line}: [{self.code}] {self.message}"


def is_if_opener(directive: str) -> bool:
    return directive.startswith(".if")


def is_block_opener(directive: str) -> bool:
    return directive in BLOCK_OPENERS or is_if_opener(directive)


def is_block_closer(directive: str) -> bool:
    return directive in BLOCK_CLOSERS or directive == ".endif"


def split_comment(line: str) -> tuple[str, str | None]:
    """Split at the first semicolon outside a quoted string."""

    quote: str | None = None
    escaped = False
    for index, character in enumerate(line):
        if escaped:
            escaped = False
            continue
        if character == "\\" and quote is not None:
            escaped = True
            continue
        if quote is not None:
            if character == quote:
                quote = None
            continue
        if character in {'"', "'"}:
            quote = character
        elif character == ";":
            return line[:index], line[index + 1 :]
    return line, None


def source_files(paths: Iterable[Path]) -> list[Path]:
    files: set[Path] = set()
    for path in paths:
        if path.is_dir():
            files.update(path.rglob("*.asm"))
            files.update(path.rglob("*.inc"))
        elif path.suffix.lower() in {".asm", ".inc"}:
            files.add(path)
    return sorted(files, key=lambda item: item.as_posix().lower())


def expected_statement_indent(depth: int) -> int:
    return max(depth, 1) * 4


def expected_directive_indent(directive: str, depth: int) -> int:
    if is_block_closer(directive) or directive in BLOCK_MIDDLES:
        return max(depth - 1, 0) * 4
    if is_block_opener(directive):
        return depth * 4
    if directive in DATA_DIRECTIVES:
        return expected_statement_indent(depth)
    return depth * 4


def next_depth(directive: str, depth: int) -> int:
    if is_block_closer(directive):
        return max(depth - 1, 0)
    if is_block_opener(directive):
        return depth + 1
    return depth


def comment_issues(
    path: Path, line_number: int, before: str, comment: str | None
) -> list[Issue]:
    if comment is None:
        return []

    issues: list[Issue] = []
    if not comment:
        issues.append(Issue(path, line_number, "comment-space", "empty comment"))
    elif not comment.startswith(" ") or comment.startswith("  "):
        issues.append(
            Issue(
                path,
                line_number,
                "comment-space",
                "use exactly one space after ';'",
            )
        )

    content = comment.strip()
    if content.endswith("."):
        issues.append(
            Issue(
                path,
                line_number,
                "comment-period",
                "remove the period at the end of the comment",
            )
        )
    if any(ord(character) > 0x7F and character.isalpha() for character in content):
        issues.append(
            Issue(
                path,
                line_number,
                "comment-language",
                "comments must be written in English; rewrite this comment manually",
            )
        )

    if before.strip():
        gap = len(before) - len(before.rstrip(" "))
        if gap != 2:
            issues.append(
                Issue(
                    path,
                    line_number,
                    "inline-comment-gap",
                    "use exactly two spaces before an inline comment",
                )
            )
    return issues


def lint_file(path: Path) -> list[Issue]:
    issues: list[Issue] = []
    try:
        payload = path.read_bytes()
        text = payload.decode("utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return [Issue(path, 1, "read-error", str(exc))]

    if b"\r" in payload:
        issues.append(Issue(path, 1, "line-ending", "use LF line endings"))
    if not payload.endswith(b"\n"):
        issues.append(Issue(path, 1, "final-newline", "file must end with one LF"))
    elif payload.endswith(b"\n\n"):
        issues.append(
            Issue(path, len(text.splitlines()) or 1, "final-newline", "file has a blank line at EOF")
        )

    source_line = 1
    source_column = 0
    for character in text:
        if character == "\n":
            source_line += 1
            source_column = 0
            continue
        source_column += 1
        if character in {"\r", "\t"}:
            continue
        if not " " <= character <= "~":
            issues.append(
                Issue(
                    path,
                    source_line,
                    "ascii-only",
                    f"only printable ASCII and LF are allowed; found U+{ord(character):04X} at column {source_column}",
                )
            )

    lines = text.splitlines()
    if lines and not lines[0].strip():
        issues.append(
            Issue(
                path,
                1,
                "file-start",
                "remove blank or whitespace-only lines at the start of the file",
            )
        )
    depth = 0
    previous_blank = False
    for line_number, line in enumerate(lines, start=1):
        if "\t" in line:
            issues.append(Issue(path, line_number, "tab", "tabs are not allowed"))
        if line.rstrip(" \t") != line:
            issues.append(
                Issue(path, line_number, "trailing-whitespace", "remove trailing whitespace")
            )

        if not line.strip():
            if previous_blank:
                issues.append(
                    Issue(path, line_number, "blank-lines", "keep at most one consecutive blank line")
                )
            previous_blank = True
            continue
        previous_blank = False

        before, comment = split_comment(line)
        issues.extend(comment_issues(path, line_number, before, comment))
        if not before.strip():
            leading = len(before) - len(before.lstrip(" "))
            if leading % 4:
                issues.append(
                    Issue(path, line_number, "comment-indent", "indent comments in multiples of four spaces")
                )
            continue

        leading = len(before) - len(before.lstrip(" "))
        statement = before.strip()

        label_match = LABEL_RE.match(statement)
        if label_match:
            if leading:
                issues.append(Issue(path, line_number, "label-indent", "labels must start at column zero"))
            if label_match.group("tail").strip():
                issues.append(
                    Issue(path, line_number, "label-line", "put the statement after a label on its own line")
                )
            continue

        directive_match = DIRECTIVE_RE.match(statement)
        if directive_match:
            directive = directive_match.group(0)
            normalized = directive.lower()
            if directive != normalized:
                issues.append(
                    Issue(path, line_number, "directive-case", "write ca65 directives in lowercase")
                )
            expected = expected_directive_indent(normalized, depth)
            if leading != expected:
                issues.append(
                    Issue(
                        path,
                        line_number,
                        "directive-indent",
                        f"expected {expected} leading spaces, found {leading}",
                    )
                )
            rest = statement[len(directive) :]
            if rest and (not rest.startswith(" ") or rest.startswith("  ")):
                issues.append(
                    Issue(path, line_number, "operand-gap", "use one space before directive operands")
                )
            depth = next_depth(normalized, depth)
            continue

        token_match = TOKEN_RE.match(statement)
        if token_match and token_match.group(0).upper() in MNEMONICS:
            mnemonic = token_match.group(0)
            if mnemonic != mnemonic.upper():
                issues.append(
                    Issue(path, line_number, "mnemonic-case", "write 6502 mnemonics in uppercase")
                )
            expected = expected_statement_indent(depth)
            if leading != expected:
                issues.append(
                    Issue(
                        path,
                        line_number,
                        "instruction-indent",
                        f"expected {expected} leading spaces, found {leading}",
                    )
                )
            rest = statement[len(mnemonic) :]
            if rest and (not rest.startswith(" ") or rest.startswith("  ")):
                issues.append(
                    Issue(path, line_number, "operand-gap", "use one space before instruction operands")
                )
            continue

        if ASSIGNMENT_RE.match(statement):
            if leading:
                issues.append(
                    Issue(path, line_number, "assignment-indent", "symbol assignments must start at column zero")
                )
            continue

        expected = expected_statement_indent(depth)
        if leading != expected:
            issues.append(
                Issue(
                    path,
                    line_number,
                    "statement-indent",
                    f"expected {expected} leading spaces for a macro or statement, found {leading}",
                )
            )

    if depth:
        issues.append(Issue(path, len(lines) or 1, "block-depth", f"{depth} assembly block(s) not closed"))
    return issues


def compose_line(code: str, comment: str | None) -> str:
    if comment is None:
        return code
    content = comment.strip().rstrip(".")
    if not content:
        return code
    if code:
        return f"{code}  ; {content}"
    return f"; {content}"


def normalize_statement(statement: str, depth: int) -> tuple[str, int]:
    label_match = LABEL_RE.match(statement)
    if label_match and not label_match.group("tail").strip():
        return label_match.group("label"), depth

    directive_match = DIRECTIVE_RE.match(statement)
    if directive_match:
        directive = directive_match.group(0).lower()
        rest = statement[len(directive_match.group(0)) :].strip()
        indent = expected_directive_indent(directive, depth)
        normalized = directive if not rest else f"{directive} {rest}"
        return " " * indent + normalized, next_depth(directive, depth)

    token_match = TOKEN_RE.match(statement)
    if token_match and token_match.group(0).upper() in MNEMONICS:
        mnemonic = token_match.group(0).upper()
        rest = statement[len(token_match.group(0)) :].strip()
        indent = expected_statement_indent(depth)
        normalized = mnemonic if not rest else f"{mnemonic} {rest}"
        return " " * indent + normalized, depth

    if ASSIGNMENT_RE.match(statement):
        return statement, depth

    return " " * expected_statement_indent(depth) + statement, depth


def format_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    logical_lines: list[tuple[str, str | None]] = []
    for raw_line in original.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        expanded = raw_line.expandtabs(4).rstrip()
        before, comment = split_comment(expanded)
        statement = before.strip()
        if not statement:
            logical_lines.append(("", comment))
            continue

        label_match = LABEL_RE.match(statement)
        if label_match and label_match.group("tail").strip():
            logical_lines.append((label_match.group("label"), None))
            logical_lines.append((label_match.group("tail").strip(), comment))
        else:
            logical_lines.append((statement, comment))

    output: list[str] = []
    depth = 0
    for statement, comment in logical_lines:
        if not statement:
            line = compose_line("", comment)
        else:
            code, depth = normalize_statement(statement, depth)
            line = compose_line(code, comment)

        if not line:
            if not output or not output[-1]:
                continue
            output.append("")
        else:
            output.append(line)

    while output and not output[-1]:
        output.pop()
    normalized_text = "\n".join(output) + "\n"
    if normalized_text == original:
        return False
    path.write_text(normalized_text, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, default=[Path("src")])
    parser.add_argument("--fix", action="store_true", help="normalize files before checking them")
    args = parser.parse_args()

    files = source_files(args.paths)
    if not files:
        print("[ERROR] No .asm or .inc source files found.", file=sys.stderr)
        return 1

    changed = 0
    if args.fix:
        for path in files:
            try:
                changed += int(format_file(path))
            except (OSError, UnicodeDecodeError) as exc:
                print(f"[ERROR] Cannot format {path}: {exc}", file=sys.stderr)
                return 1

    issues = [issue for path in files for issue in lint_file(path)]
    if issues:
        for issue in issues:
            print(issue.render(), file=sys.stderr)
        print(f"[ERROR] Assembly style check failed with {len(issues)} issue(s).", file=sys.stderr)
        return 1

    action = f"Formatted {changed} and validated" if args.fix else "Validated"
    print(f"[OK] {action} {len(files)} assembly source files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
