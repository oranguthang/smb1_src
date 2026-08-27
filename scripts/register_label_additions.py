#!/usr/bin/env python3
"""Register newly introduced assembly labels in the provenance manifest."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


LABEL_RE = re.compile(
    r"^((?:bra|handler|loc|off|sub|tbl|unused|vec)_"
    r"[a-z0-9]+(?:_[a-z0-9]+)*):$"
)
COUNTS_RE = re.compile(r'^  "counts": \{.*\},$', re.MULTILINE)
ADDITIONS_END = "\n  ]\n}\n"


def active_labels(project_root: Path) -> list[tuple[str, str]]:
    labels: list[tuple[str, str]] = []
    for path in sorted((project_root / "src").rglob("*")):
        if not path.is_file() or path.suffix.lower() not in {".asm", ".inc"}:
            continue
        relative_path = path.relative_to(project_root).as_posix()
        for line in path.read_text(encoding="utf-8").splitlines():
            match = LABEL_RE.fullmatch(line)
            if match is not None:
                labels.append((match.group(1), relative_path))
    return labels


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--commit", required=True)
    parser.add_argument("--reason", required=True)
    args = parser.parse_args()

    if re.fullmatch(r"[0-9a-f]{40}", args.commit) is None:
        parser.error("--commit must be a full lowercase Git object ID")

    project_root = args.project_root.resolve()
    manifest_path = project_root / "docs" / "provenance" / "label_renames.json"
    text = manifest_path.read_text(encoding="utf-8")
    manifest = json.loads(text)

    mapped = {(item[1], item[2]) for item in manifest["renames"]}
    mapped.update((item[0], item[1]) for item in manifest["project_additions"])
    missing = [item for item in active_labels(project_root) if item not in mapped]
    if not missing:
        print("[OK] No unregistered assembly labels found.")
        return 0

    additions = [
        [name, path, args.commit, args.reason]
        for name, path in missing
    ]
    addition_lines = [
        "    " + json.dumps(item, ensure_ascii=True, separators=(",", ":"))
        for item in additions
    ]
    existing_additions = manifest["project_additions"]
    separator = ",\n" if existing_additions else "\n"
    replacement = separator + ",\n".join(addition_lines) + ADDITIONS_END
    if not text.endswith(ADDITIONS_END):
        raise SystemExit("[ERROR] Unexpected label manifest ending")
    text = text[: -len(ADDITIONS_END)] + replacement

    current_count = len(manifest["renames"]) + len(existing_additions) + len(additions)
    counts = (
        '  "counts": {"original_labels": '
        f'{len(manifest["renames"])}, "current_labels": {current_count}, '
        f'"direct_renames": {len(manifest["renames"])}, '
        f'"project_additions": {len(existing_additions) + len(additions)}}},'
    )
    text, replacements = COUNTS_RE.subn(counts, text, count=1)
    if replacements != 1:
        raise SystemExit("[ERROR] Could not update label manifest counts")
    manifest_path.write_text(text, encoding="utf-8", newline="\n")
    print(f"[OK] Registered {len(additions)} assembly labels.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
