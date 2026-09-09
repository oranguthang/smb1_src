"""Read the public Make interface across the root file and mk fragments."""

from __future__ import annotations

import re
from pathlib import Path


TARGET_RE = re.compile(r"^([A-Za-z0-9_.-]+)\s*:", re.MULTILINE)


def makefile_paths(project_root: Path) -> list[Path]:
    """Return Makefiles in deterministic public-interface order."""
    root = project_root / "Makefile"
    fragments = sorted((project_root / "mk").glob("*.mk"))
    return [root, *fragments]


def combined_makefile_text(project_root: Path) -> str:
    """Return all project-owned Make source as one audit surface."""
    return "\n".join(
        path.read_text(encoding="utf-8") for path in makefile_paths(project_root)
    )


def make_targets(project_root: Path) -> set[str]:
    """Return every explicitly declared target in the public Make interface."""
    return set(TARGET_RE.findall(combined_makefile_text(project_root)))
