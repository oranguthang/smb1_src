#!/usr/bin/env python3
"""Remove the selected generated build directory safely."""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--path", required=True)
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    target = Path(args.path).resolve()
    try:
        relative = target.relative_to(project_root)
    except ValueError:
        fail(f"refusing to clean outside project root: {target}")
    if not relative.parts or relative.parts[0] != "build":
        fail(f"refusing to clean non-build path: {target}")
    if len(relative.parts) < 2:
        fail("refusing to remove the entire build root")
    if target.is_dir():
        shutil.rmtree(target)
        print(f"[OK] Removed build directory: {target}")
    else:
        print(f"[OK] Build directory is already absent: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
