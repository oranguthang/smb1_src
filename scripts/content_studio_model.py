#!/usr/bin/env python3
"""Testable document and CHR models shared by the Tk content studios."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

from content_studio import atomic_write_bytes, atomic_write_json, encode_workspace_document


CHR_SIZE = 8192
TILE_COUNT = 512
TILE_SIZE = 16


def decode_chr(data: bytes) -> list[list[list[int]]]:
    if len(data) != CHR_SIZE:
        raise ValueError(f"CHR must be exactly {CHR_SIZE} bytes, got {len(data)}")
    tiles = []
    for tile_index in range(TILE_COUNT):
        offset = tile_index * TILE_SIZE
        pixels = []
        for row in range(8):
            low = data[offset + row]
            high = data[offset + 8 + row]
            pixels.append([
                ((low >> (7 - column)) & 1)
                | (((high >> (7 - column)) & 1) << 1)
                for column in range(8)
            ])
        tiles.append(pixels)
    return tiles


def encode_chr(tiles: list[list[list[int]]]) -> bytes:
    if len(tiles) != TILE_COUNT:
        raise ValueError(f"CHR requires exactly {TILE_COUNT} tiles")
    output = bytearray()
    for tile_index, tile in enumerate(tiles):
        if len(tile) != 8 or any(len(row) != 8 for row in tile):
            raise ValueError(f"CHR tile {tile_index} must be 8x8 pixels")
        if any(pixel not in range(4) for row in tile for pixel in row):
            raise ValueError(f"CHR tile {tile_index} uses a pixel outside 2bpp range 0..3")
        for plane in (0, 1):
            for row in tile:
                byte = 0
                for pixel in row:
                    byte = (byte << 1) | ((pixel >> plane) & 1)
                output.append(byte)
    return bytes(output)


class ArtifactDocument:
    def __init__(self, document: dict[str, Any], entry: dict[str, Any], path: Path) -> None:
        self.document = copy.deepcopy(document)
        self.entry = entry
        self.path = path
        self.original = copy.deepcopy(document)
        self.saved = copy.deepcopy(document)
        self.undo_stack: list[dict[str, Any]] = []
        self.validate()

    @classmethod
    def load(cls, path: Path, entry: dict[str, Any]) -> ArtifactDocument:
        return cls(json.loads(path.read_text(encoding="utf-8")), entry, path)

    @property
    def dirty(self) -> bool:
        return self.document != self.saved

    def _remember(self) -> None:
        self.undo_stack.append(copy.deepcopy(self.document))

    def undo(self) -> bool:
        if not self.undo_stack:
            return False
        self.document = self.undo_stack.pop()
        return True

    def restore_original(self) -> None:
        if self.document != self.original:
            self._remember()
            self.document = copy.deepcopy(self.original)

    def validate(self) -> bytes:
        return encode_workspace_document(
            self.document, self.entry, int(self.document["capacity_bytes"])
        )

    def save(self) -> Path:
        self.validate()
        atomic_write_json(self.path, self.document)
        self.saved = copy.deepcopy(self.document)
        return self.path


class ChrDocument:
    def __init__(self, data: bytes, path: Path) -> None:
        self.tiles = decode_chr(data)
        self.original = copy.deepcopy(self.tiles)
        self.saved = copy.deepcopy(self.tiles)
        self.path = path
        self.undo_stack: list[tuple[int, list[list[int]]]] = []
        self.stroke_tile: int | None = None

    @property
    def dirty(self) -> bool:
        return self.tiles != self.saved

    def changed(self, tile: int) -> bool:
        return self.tiles[tile] != self.original[tile]

    def begin_stroke(self, tile: int) -> None:
        if not 0 <= tile < TILE_COUNT:
            raise ValueError("CHR stroke tile is outside the tile bank")
        self.stroke_tile = tile
        self.undo_stack.append((tile, copy.deepcopy(self.tiles[tile])))

    def end_stroke(self) -> None:
        if self.stroke_tile is not None and self.undo_stack[-1][1] == self.tiles[self.stroke_tile]:
            self.undo_stack.pop()
        self.stroke_tile = None

    def paint(self, tile: int, row: int, column: int, color: int) -> bool:
        if not 0 <= tile < TILE_COUNT or not 0 <= row < 8 or not 0 <= column < 8:
            raise ValueError("CHR paint coordinate is outside the tile bank")
        if color not in range(4):
            raise ValueError("CHR pixel color must be in 0..3")
        if self.tiles[tile][row][column] == color:
            return False
        if self.stroke_tile != tile:
            self.undo_stack.append((tile, copy.deepcopy(self.tiles[tile])))
        self.tiles[tile][row][column] = color
        return True

    def undo(self) -> bool:
        if not self.undo_stack:
            return False
        tile, pixels = self.undo_stack.pop()
        self.tiles[tile] = pixels
        return True

    def restore_tile(self, tile: int) -> None:
        if self.changed(tile):
            self.undo_stack.append((tile, copy.deepcopy(self.tiles[tile])))
            self.tiles[tile] = copy.deepcopy(self.original[tile])

    def save(self) -> Path:
        atomic_write_bytes(self.path, encode_chr(self.tiles))
        self.saved = copy.deepcopy(self.tiles)
        return self.path


def smb_tile_text(values: list[int]) -> str:
    characters = []
    punctuation = {0x24: " ", 0x28: "-", 0x2B: "!", 0x29: "x"}
    for value in values:
        if 0 <= value <= 9:
            characters.append(str(value))
        elif 0x0A <= value <= 0x23:
            characters.append(chr(ord("A") + value - 0x0A))
        else:
            characters.append(punctuation.get(value, f"<{value:02X}>"))
    return "".join(characters)
