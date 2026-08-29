#!/usr/bin/env python3
"""Shared loading, validation, rendering, and launch helpers for SMB1 studios."""

from __future__ import annotations

import json
import subprocess
import tkinter as tk
from pathlib import Path
from tkinter import messagebox
from typing import Any

from content_profiles import load_profiles, require_supported
from content_studio import (
    load_profile_chr,
    load_named_payloads,
    load_configuration,
    merge_labels,
    parse_named_paths,
    resolve_profile_selection,
)
from content_studio_model import ArtifactDocument


NES_RGB = (
    "#626262", "#001fb2", "#2404c8", "#5200b2", "#730076", "#800024", "#730b00", "#522800",
    "#244400", "#005700", "#005c00", "#005324", "#003c76", "#000000", "#000000", "#000000",
    "#ababab", "#0d57ff", "#4b30ff", "#8a13ff", "#bc08d6", "#d21269", "#c72e00", "#9d5400",
    "#607b00", "#209800", "#00a300", "#009942", "#007db4", "#000000", "#000000", "#000000",
    "#ffffff", "#53aeff", "#9085ff", "#d365ff", "#ff57ff", "#ff5dcf", "#ff7757", "#fa9e00",
    "#bdc700", "#7ae700", "#43f611", "#26ef7e", "#2cd5f6", "#4e4e4e", "#000000", "#000000",
    "#ffffff", "#b6e1ff", "#ced1ff", "#e9c3ff", "#ffbcff", "#ffbdf4", "#ffc6c3", "#ffd59a",
    "#e9e681", "#cef481", "#b6fb9a", "#a9fac3", "#a9f0f4", "#b8b8b8", "#000000", "#000000",
)


def load_documents(
    formats: Path,
    studios: Path,
    labels_path: Path,
    profiles_path: Path,
    prg_path: Path,
    chr_path: Path,
    payload_arguments: list[str] | None,
    payload_label_arguments: list[str] | None,
    workspace: Path,
    studio_id: str,
    profile_id: str = "ju",
) -> tuple[dict[str, ArtifactDocument], dict[str, int]]:
    entries, profiles = load_configuration(formats, studios)
    authoring_profile = require_supported(load_profiles(profiles_path), profile_id)
    payload_paths = parse_named_paths(payload_arguments)
    payload_label_paths = parse_named_paths(payload_label_arguments)
    if set(payload_label_paths) - set(payload_paths):
        raise ValueError("payload labels require a matching content payload")
    labels = merge_labels(labels_path, payload_label_paths)
    payloads = {
        "prg": prg_path.read_bytes(),
        "chr": load_profile_chr(chr_path, authoring_profile),
    }
    payloads.update(load_named_payloads(payload_paths, authoring_profile))
    selection = [
        (studio_id, entries[artifact_id])
        for artifact_id in profiles[studio_id]["artifacts"]
    ]
    resolved_entries = {
        entry["id"]: entry
        for _studio, entry in resolve_profile_selection(
            selection,
            authoring_profile,
            labels,
            payloads,
        )
    }
    documents = {}
    for artifact_id in profiles[studio_id]["artifacts"]:
        entry = resolved_entries[artifact_id]
        path = workspace / studio_id / f"{artifact_id}.json"
        document = ArtifactDocument.load(path, entry)
        if document.document.get("profile") != profile_id:
            raise ValueError(
                f"{artifact_id}: workspace profile must remain {profile_id!r}"
            )
        documents[artifact_id] = document
    return documents, labels


def save_documents(documents: dict[str, ArtifactDocument]) -> None:
    for document in documents.values():
        document.save()


def validate_documents(documents: dict[str, ArtifactDocument]) -> tuple[int, int]:
    used = capacity = 0
    for document in documents.values():
        encoded = document.validate()
        used += len(encoded)
        capacity += int(document.document["capacity_bytes"])
    return used, capacity


def run_make(
    project_root: Path,
    target: str,
    profile_id: str = "ju",
    studio: str | None = None,
) -> None:
    command = ["make", target]
    command.append(f"CONTENT_PROFILE={profile_id}")
    if studio:
        command.append(f"STUDIO={studio}")
    subprocess.Popen(command, cwd=project_root)


def guard(title: str, action: Any) -> None:
    try:
        action()
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        messagebox.showerror(title, str(error))


def tile_pixels(tiles: list[list[list[int]]], tile: int) -> list[list[int]]:
    if not 0 <= tile < len(tiles):
        return [[0] * 8 for _ in range(8)]
    return tiles[tile]


def draw_tile(
    canvas: tk.Canvas,
    tiles: list[list[list[int]]],
    tile: int,
    x: int,
    y: int,
    scale: int,
    palette: list[int],
) -> None:
    for row, values in enumerate(tile_pixels(tiles, tile)):
        for column, value in enumerate(values):
            canvas.create_rectangle(
                x + column * scale,
                y + row * scale,
                x + (column + 1) * scale,
                y + (row + 1) * scale,
                fill=NES_RGB[palette[value] & 0x3F],
                outline="",
            )


def dirty(documents: dict[str, ArtifactDocument]) -> bool:
    return any(document.dirty for document in documents.values())


def change_document(document: ArtifactDocument, action: Any) -> None:
    """Apply one undoable edit and roll it back if canonical validation fails."""
    document._remember()
    try:
        action()
        document.validate()
    except (ValueError, KeyError, TypeError):
        document.undo()
        raise
