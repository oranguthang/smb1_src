#!/usr/bin/env python3
"""Assemble and link a standalone source range with bundled cc65 tools"""

from __future__ import annotations

import argparse
from pathlib import Path

from build_native import resolve_tool, rooted, run_tool


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--object", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--labels", required=True)
    parser.add_argument("--map", required=True)
    args = parser.parse_args()
    project_root = Path(__file__).resolve().parent.parent
    source = rooted(project_root, args.source)
    config = rooted(project_root, args.config)
    object_path = rooted(project_root, args.object)
    output = rooted(project_root, args.output)
    labels = rooted(project_root, args.labels)
    map_path = rooted(project_root, args.map)
    for path in (object_path, output, labels, map_path):
        path.parent.mkdir(parents=True, exist_ok=True)
    run_tool(
        resolve_tool("ca65", project_root),
        [
            str(source),
            "-g",
            "-I",
            str(source.parent),
            "-I",
            str(project_root / "src"),
            "-o",
            str(object_path),
        ],
        project_root,
    )
    run_tool(
        resolve_tool("ld65", project_root),
        [
            "-C",
            str(config),
            str(object_path),
            "-o",
            str(output),
            "-Ln",
            str(labels),
            "--mapfile",
            str(map_path),
        ],
        output.parent,
    )
    print(f"[OK] Built standalone range: {output} ({output.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
