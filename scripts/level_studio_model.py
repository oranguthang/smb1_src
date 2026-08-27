"""Semantic model for all vanilla SMB1 area and enemy streams."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from content_studio_model import ArtifactDocument


AREA_TYPES = ("water", "ground", "underground", "castle")

WORLD_AREA_POINTERS = (
    (0x25, 0x29, 0xC0, 0x26, 0x60),
    (0x28, 0x29, 0x01, 0x27, 0x62),
    (0x24, 0x35, 0x20, 0x63),
    (0x22, 0x29, 0x41, 0x2C, 0x61),
    (0x2A, 0x31, 0x26, 0x62),
    (0x2E, 0x23, 0x2D, 0x60),
    (0x33, 0x29, 0x01, 0x27, 0x64),
    (0x30, 0x32, 0x21, 0x65),
)

METATILE_GROUP_STARTS = (0, 39, 85, 95)
METATILE_GROUP_SIZES = (39, 46, 10, 6)

BACKGROUND_SCENERY_OFFSETS = (0x00, 0x30, 0x60)
BACKGROUND_SCENERY_PATTERNS = (
    0x93, 0x00, 0x00, 0x11, 0x12, 0x12, 0x13, 0x00,
    0x00, 0x51, 0x52, 0x53, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x02, 0x02, 0x03, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x91, 0x92, 0x93, 0x00,
    0x00, 0x00, 0x00, 0x51, 0x52, 0x53, 0x41, 0x42,
    0x43, 0x00, 0x00, 0x00, 0x00, 0x00, 0x91, 0x92,
    0x97, 0x87, 0x88, 0x89, 0x99, 0x00, 0x00, 0x00,
    0x11, 0x12, 0x13, 0xA4, 0xA5, 0xA5, 0xA5, 0xA6,
    0x97, 0x98, 0x99, 0x01, 0x02, 0x03, 0x00, 0xA4,
    0xA5, 0xA6, 0x00, 0x11, 0x12, 0x12, 0x12, 0x13,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x02, 0x03,
    0x00, 0xA4, 0xA5, 0xA5, 0xA6, 0x00, 0x00, 0x00,
    0x11, 0x12, 0x12, 0x13, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x9C, 0x00, 0x8B, 0xAA, 0xAA,
    0xAA, 0xAA, 0x11, 0x12, 0x13, 0x8B, 0x00, 0x9C,
    0x9C, 0x00, 0x00, 0x01, 0x02, 0x03, 0x11, 0x12,
    0x12, 0x13, 0x00, 0x00, 0x00, 0x00, 0xAA, 0xAA,
    0x9C, 0xAA, 0x00, 0x8B, 0x00, 0x01, 0x02, 0x03,
)
BACKGROUND_SCENERY_METATILES = (
    0x80, 0x83, 0x00, 0x81, 0x84, 0x00, 0x82, 0x85, 0x00,
    0x02, 0x00, 0x00, 0x03, 0x00, 0x00, 0x04, 0x00, 0x00,
    0x00, 0x05, 0x06, 0x07, 0x06, 0x0A, 0x00, 0x08, 0x09,
    0x4D, 0x00, 0x00, 0x0D, 0x0F, 0x4E, 0x0E, 0x4E, 0x4E,
)
FOREGROUND_SCENERY_OFFSETS = (0x00, 0x0D, 0x1A)
FOREGROUND_SCENERY_METATILES = (
    0x86, 0x87, 0x87, 0x87, 0x87, 0x87, 0x87,
    0x87, 0x87, 0x87, 0x87, 0x69, 0x69,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x45, 0x47,
    0x47, 0x47, 0x47, 0x47, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x86, 0x87,
)
TERRAIN_METATILES = (0x69, 0x54, 0x52, 0x62)
TERRAIN_RENDER_MASKS = (
    (0x00, 0x00), (0x00, 0x18), (0x01, 0x18), (0x07, 0x18),
    (0x0F, 0x18), (0xFF, 0x18), (0x01, 0x1F), (0x07, 0x1F),
    (0x0F, 0x1F), (0x81, 0x1F), (0x01, 0x00), (0x8F, 0x1F),
    (0xF1, 0x1F), (0xF9, 0x18), (0xF1, 0x18), (0xFF, 0x1F),
)
BACKGROUND_COLORS = (0x22, 0x22, 0x0F, 0x0F, 0x0F, 0x22, 0x0F, 0x0F)
BRICK_METATILES = (0x22, 0x51, 0x52, 0x52, 0x88)
SOLID_METATILES = (0x69, 0x61, 0x61, 0x62)
COIN_METATILES = (0xC3, 0xC2, 0xC2, 0xC2)
BLOCK_METATILES = (
    0xC1, 0xC0, 0x5F, 0x60, 0x55, 0x56, 0x57,
    0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E,
)

ENEMY_GRAPHICS_TILES = (
    0xFC, 0xFC, 0xAA, 0xAB, 0xAC, 0xAD,
    0xFC, 0xFC, 0xAE, 0xAF, 0xB0, 0xB1,
    0xFC, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9,
    0xFC, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4,
    0x69, 0xA5, 0x6A, 0xA7, 0xA8, 0xA9,
    0x6B, 0xA0, 0x6C, 0xA2, 0xA3, 0xA4,
    0xFC, 0xFC, 0x96, 0x97, 0x98, 0x99,
    0xFC, 0xFC, 0x9A, 0x9B, 0x9C, 0x9D,
    0xFC, 0xFC, 0x8F, 0x8E, 0x8E, 0x8F,
    0xFC, 0xFC, 0x95, 0x94, 0x94, 0x95,
    0xFC, 0xFC, 0xDC, 0xDC, 0xDF, 0xDF,
    0xDC, 0xDC, 0xDD, 0xDD, 0xDE, 0xDE,
    0xFC, 0xFC, 0xB2, 0xB3, 0xB4, 0xB5,
    0xFC, 0xFC, 0xB6, 0xB3, 0xB7, 0xB5,
    0xFC, 0xFC, 0x70, 0x71, 0x72, 0x73,
)
ENEMY_GRAPHICS_OFFSETS = (
    0x0C, 0x0C, 0x00, 0x0C, 0x0C, 0xA8, 0x54, 0x3C,
    0xEA, 0x18, 0x48, 0x48, 0xCC, 0xC0, 0x18, 0x18,
    0x18, 0x90, 0x24, 0xFF, 0x48, 0x9C, 0xD2, 0xD8,
    0xF0, 0xF6, 0xFC,
)
ENEMY_PALETTE_ROWS = (
    1, 2, 3, 2, 1, 1, 3, 3, 3, 1, 1, 2, 2, 1,
    1, 2, 1, 1, 2, 3, 2, 2, 1, 1, 2, 2, 2,
)

STATIC_OBJECTS = (
    "question block (power-up)", "question block (coin)", "hidden block (coin)",
    "hidden block (1-up)", "brick (power-up)", "brick (vine)", "brick (star)",
    "brick (coins)", "brick (1-up)", "sideways pipe", "used block", "springboard",
    "reverse L pipe", "flagpole", "Bowser bridge", "nothing",
)

EXTENDED_OBJECTS = (
    "platform", "row of bricks", "row of blocks", "row of coins",
    "column of bricks", "column of blocks", "pipe",
)

ROW_C_OBJECTS = (
    "hole", "pulley rope", "bridge row 7", "bridge row 8",
    "bridge row 10", "water/lava hole", "question row 3", "question row 7",
)

ROW_D_OBJECTS = (
    "reverse L pipe", "flagpole", "Bowser axe", "axe rope", "Bowser bridge",
    "warp scroll stop", "scroll stop", "scroll stop", "Cheep-Cheep generator",
    "Bullet Bill generator", "stop generator", "area loop",
)

ENEMY_NAMES = {
    0x00: "green Koopa", 0x01: "red Koopa", 0x02: "Buzzy Beetle",
    0x03: "red Koopa", 0x04: "green Koopa", 0x05: "Hammer Bro",
    0x06: "Goomba", 0x07: "Blooper", 0x08: "Bullet Bill",
    0x09: "green Paratroopa", 0x0A: "green Cheep-Cheep", 0x0B: "red Cheep-Cheep",
    0x0C: "Podoboo", 0x0D: "Piranha Plant", 0x0E: "jumping Paratroopa",
    0x0F: "red Paratroopa", 0x10: "flying Paratroopa", 0x11: "Lakitu",
    0x12: "Spiny", 0x14: "flying Cheep-Cheep generator", 0x15: "Bowser fire generator",
    0x17: "Bullet Bill generator", 0x1B: "fast clockwise firebar",
    0x1C: "slow clockwise firebar", 0x1D: "fast counterclockwise firebar",
    0x1E: "slow counterclockwise firebar", 0x1F: "long firebar",
    0x24: "balance lift", 0x25: "vertical lift", 0x26: "lift up",
    0x27: "small lift up", 0x28: "horizontal lift", 0x29: "falling lift",
    0x2A: "surfing lift", 0x2B: "lift down", 0x2C: "small lift down",
    0x2D: "Bowser", 0x34: "warp-zone marker", 0x35: "Toad",
}


@dataclass(frozen=True)
class LevelScene:
    """A complete editor preview in the game's 16-pixel metatile grid."""

    metatiles: tuple[tuple[int, ...], ...]
    enemies: tuple[dict[str, Any], ...]
    width: int


class LevelVisuals:
    """CHR, palette, and metatile data used by the Level Studio preview."""

    def __init__(
        self,
        tiles: list[list[list[int]]],
        metatiles: list[list[int]],
        palette_blocks: list[dict[str, Any]],
        player_frames: list[list[int]],
    ) -> None:
        self.tiles = tiles
        self.metatiles = metatiles
        self.palette_blocks = palette_blocks
        self.player_frames = player_frames

    def palette(self, area_type: str) -> tuple[int, ...]:
        block = next(item for item in self.palette_blocks if item["name"] == area_type)
        return tuple(int(value) for value in block["packets"][0]["values"])

    def metatile_record(self, value: int) -> tuple[int, int, int, int]:
        group = (value >> 6) & 3
        if value & 0x3F >= METATILE_GROUP_SIZES[group]:
            return (0x24, 0x24, 0x24, 0x24)
        index = METATILE_GROUP_STARTS[group] + (value & 0x3F)
        if not 0 <= index < len(self.metatiles):
            return (0x24, 0x24, 0x24, 0x24)
        return tuple(int(tile) for tile in self.metatiles[index])

    def display_metatile_record(self, value: int) -> tuple[int, int, int, int]:
        """Convert the engine's TL, BL, TR, BR storage into display row order."""
        top_left, bottom_left, top_right, bottom_right = self.metatile_record(value)
        return top_left, top_right, bottom_left, bottom_right

    def player_tiles(self) -> tuple[int, ...]:
        frame = 23 if len(self.player_frames) > 23 else 0
        return tuple(int(tile) for tile in self.player_frames[frame][4:])

    @staticmethod
    def player_horizontal_flips() -> tuple[bool, ...]:
        """Return the OAM horizontal flips for the small standing frame."""
        return False, False, False, True

    def enemy_tiles(self, identifier: int) -> tuple[int, ...]:
        if not 0 <= identifier < len(ENEMY_GRAPHICS_OFFSETS):
            return ()
        offset = ENEMY_GRAPHICS_OFFSETS[identifier]
        if offset == 0xFF or offset + 6 > len(ENEMY_GRAPHICS_TILES):
            return ()
        return ENEMY_GRAPHICS_TILES[offset:offset + 6]

    @staticmethod
    def enemy_palette(identifier: int) -> int:
        if not 0 <= identifier < len(ENEMY_PALETTE_ROWS):
            return 1
        return ENEMY_PALETTE_ROWS[identifier] & 3


def area_name(area_type: int, area_index: int) -> str:
    return f"{AREA_TYPES[area_type]}_{area_index + 1}"


def area_pointer(name: str) -> int:
    area_type_name, separator, index_text = name.rpartition("_")
    if not separator or area_type_name not in AREA_TYPES:
        raise ValueError(f"Unsupported area name: {name}")
    area_index = int(index_text) - 1
    if not 0 <= area_index <= 31:
        raise ValueError(f"Area index is outside the SMB pointer range: {name}")
    return (AREA_TYPES.index(area_type_name) << 5) | area_index


def first_world_context(name: str) -> tuple[int, int]:
    pointer = area_pointer(name)
    for world, route in enumerate(WORLD_AREA_POINTERS):
        for slot, candidate in enumerate(route):
            if candidate & 0x7F == pointer:
                return world, min(slot, 3)
    return 0, 0


def default_preview_theme(name: str, area_stream: dict[str, Any]) -> str:
    """Return the vanilla day/night background choice for an area header."""
    area_type = AREA_TYPES.index(name.rpartition("_")[0])
    color_control = int(area_stream["data"]["header"]["foreground_or_color"])
    color_index = color_control if color_control >= 4 else area_type
    return "Day" if BACKGROUND_COLORS[color_index] == 0x22 else "Night"


def describe_area_object(row: int, control: int) -> str:
    if row <= 0x0B:
        subcommand = (control >> 4) & 0x07
        value = control & 0x0F
        if subcommand == 0:
            return STATIC_OBJECTS[value]
        return f"{EXTENDED_OBJECTS[subcommand - 1]} x{value + 1}"
    if row == 0x0C:
        return f"{ROW_C_OBJECTS[(control >> 4) & 0x07]} x{(control & 0x0F) + 1}"
    if row == 0x0D:
        if not control & 0x40:
            return f"set page {control & 0x1F}"
        value = control & 0x3F
        return ROW_D_OBJECTS[value] if value < len(ROW_D_OBJECTS) else f"special ${value:02X}"
    if row == 0x0E:
        return "background modifier" if control & 0x40 else "area-style modifier"
    return f"special object ${control:02X}"


def positioned_area_objects(stream: dict[str, Any]) -> list[dict[str, Any]]:
    page = 0
    result = []
    for index, item in enumerate(stream["data"]["objects"]):
        control = int(item["object_control"])
        if item["page_advance"]:
            page += 1
        if int(item["row"]) == 0x0D and not control & 0x40:
            page = control & 0x1F
        result.append({
            **item,
            "index": index,
            "page": page,
            "x": page * 16 + int(item["column"]),
            "description": describe_area_object(int(item["row"]), control),
        })
    return result


def positioned_enemy_objects(stream: dict[str, Any]) -> list[dict[str, Any]]:
    page = 0
    result = []
    for index, item in enumerate(stream["data"]["records"]):
        if item["page_advance"]:
            page += 1
        if item["kind"] == "page":
            page = int(item["object_or_page"] & 0x1F)
            description = f"set page {page}"
        elif item["kind"] == "entrance":
            destination = int(item["object_or_page"])
            description = (
                f"entrance to {area_name((destination >> 5) & 3, destination & 0x1F)}, "
                f"page {item['destination_page']}, world gate {item['destination_world'] + 1}"
            )
        else:
            identifier = int(item["object_or_page"])
            description = ENEMY_NAMES.get(identifier, f"enemy ${identifier:02X}")
        result.append({
            **item,
            "index": index,
            "page": page,
            "x": page * 16 + int(item["column"]),
            "description": description,
        })
    return result


def object_width(item: dict[str, Any]) -> int:
    """Return the number of metatile columns occupied by a terrain record."""
    row = int(item["row"])
    control = int(item["object_control"])
    if row <= 0x0C:
        identifier = (control >> 4) & 7
        if row == 0x0C or identifier in {1, 2, 3, 4}:
            return (control & 0x0F) + 1
        if identifier == 7:
            return 2
    if row == 0x0D and control & 0x40:
        return 13 if (control & 0x3F) == 4 else 1
    if row == 0x0F:
        identifier = (control >> 4) & 7
        if identifier == 2:
            return 5
        if identifier == 4:
            return 4
        return (control & 0x0F) + 1
    return 1


def render_level_scene(
    name: str,
    area_stream: dict[str, Any],
    enemy_stream: dict[str, Any],
    world: int = 0,
) -> LevelScene:
    """Reconstruct scenery, terrain, and common objects from vanilla parser data."""
    objects = positioned_area_objects(area_stream)
    enemies = positioned_enemy_objects(enemy_stream)
    max_column = max(
        [32]
        + [int(item["x"]) + object_width(item) for item in objects]
        + [int(item["x"]) + 2 for item in enemies],
    )
    width = max_column + 2
    header = area_stream["data"]["header"]
    area_type = AREA_TYPES.index(name.rpartition("_")[0])
    foreground = int(header["foreground_or_color"])
    foreground = foreground if foreground < 4 else 0
    background = int(header["background_scenery"])
    terrain = int(header["terrain_control"])
    area_style = int(header["area_style"])
    cloud = area_style == 3
    grid: list[list[int]] = []
    modifiers: dict[int, list[dict[str, Any]]] = {}
    for item in objects:
        if int(item["row"]) == 0x0E:
            modifiers.setdefault(int(item["x"]), []).append(item)

    for column in range(width):
        values = _base_column(column, area_type, world, foreground, background, terrain, cloud)
        grid.append(values)
        for modifier in modifiers.get(column, ()):
            control = int(modifier["object_control"])
            if control & 0x40:
                value = control & 7
                foreground = value if value < 4 else 0
            else:
                terrain = control & 0x0F
                background = (control >> 4) & 3

    for item in objects:
        _render_area_object(grid, item, area_type, cloud, 0 if cloud else area_style)
    return LevelScene(
        metatiles=tuple(tuple(column) for column in grid),
        enemies=tuple(item for item in enemies if item["kind"] == "enemy"),
        width=width,
    )


def _base_column(
    column: int,
    area_type: int,
    world: int,
    foreground: int,
    background: int,
    terrain: int,
    cloud: bool,
) -> list[int]:
    values = [0] * 13
    if background:
        pattern_index = (
            BACKGROUND_SCENERY_OFFSETS[background - 1]
            + ((column // 16) % 3) * 16
            + column % 16
        )
        pattern = BACKGROUND_SCENERY_PATTERNS[pattern_index]
        if pattern:
            row = pattern >> 4
            offset = ((pattern & 0x0F) - 1) * 3
            for index in range(3):
                if row + index >= 11:
                    break
                values[row + index] = BACKGROUND_SCENERY_METATILES[offset + index]
    if foreground:
        offset = FOREGROUND_SCENERY_OFFSETS[foreground - 1]
        for row in range(13):
            value = FOREGROUND_SCENERY_METATILES[offset + row]
            if value:
                values[row] = value
    terrain_value = 0x62 if area_type == 0 and world == 7 else TERRAIN_METATILES[area_type]
    if cloud:
        terrain_value = 0x88
    masks = TERRAIN_RENDER_MASKS[terrain]
    for row in range(13):
        byte, bit = (masks[0], row) if row < 8 else (masks[1], row - 8)
        if cloud and row >= 8:
            byte &= 0x08
        if byte & (1 << bit):
            values[row] = 0x54 if area_type == 2 and row >= 11 else terrain_value
    return values


def _write(grid: list[list[int]], column: int, row: int, value: int) -> None:
    if 0 <= column < len(grid) and 0 <= row < 13:
        grid[column][row] = value


def _fill_down(grid: list[list[int]], column: int, row: int, height: int, value: int) -> None:
    for offset in range(height + 1):
        _write(grid, column, row + offset, value)


def _render_area_object(
    grid: list[list[int]],
    item: dict[str, Any],
    area_type: int,
    cloud: bool,
    area_style: int,
) -> None:
    column = int(item["x"])
    row = int(item["row"])
    control = int(item["object_control"])
    value = control & 0x0F
    identifier = (control >> 4) & 7
    if row <= 0x0B:
        if identifier == 0:
            _render_small_object(grid, column, row, value, area_type)
        elif identifier == 1:
            _render_area_style_object(grid, column, row, value, area_style)
        elif identifier in {2, 3, 4}:
            if identifier == 2:
                metatile = BRICK_METATILES[4 if cloud else area_type]
            elif identifier == 3:
                metatile = SOLID_METATILES[area_type]
            else:
                metatile = COIN_METATILES[area_type]
            for offset in range(value + 1):
                _write(grid, column + offset, row, metatile)
        elif identifier in {5, 6}:
            metatile = BRICK_METATILES[area_type] if identifier == 5 else SOLID_METATILES[area_type]
            _fill_down(grid, column, row, value, metatile)
        else:
            _render_vertical_pipe(grid, column, row, value)
    elif row == 0x0C:
        _render_row_c_object(grid, column, identifier, value, area_type)
    elif row == 0x0D and control & 0x40:
        _render_row_d_object(grid, column, control & 0x3F)
    elif row == 0x0F:
        _render_row_f_object(grid, column, identifier, value)


def _render_small_object(
    grid: list[list[int]], column: int, row: int, identifier: int, area_type: int,
) -> None:
    if identifier <= 3:
        metatile = BLOCK_METATILES[identifier]
    elif identifier <= 8:
        metatile = BLOCK_METATILES[identifier + (0 if area_type == 1 else 5)]
    elif identifier == 9:
        _write(grid, column, row, 0x6B)
        _write(grid, column, row + 1, 0x6C)
        return
    elif identifier == 10:
        metatile = 0xC4
    elif identifier == 11:
        _write(grid, column, row, 0x67)
        _write(grid, column, row + 1, 0x68)
        return
    else:
        return
    _write(grid, column, row, metatile)


def _render_area_style_object(
    grid: list[list[int]], column: int, row: int, length: int, style: int,
) -> None:
    if style == 1:
        for offset in range(length + 1):
            tile = 0x19 if offset == 0 else 0x1B if offset == length else 0x1A
            _write(grid, column + offset, row, tile)
        center = column + length // 2
        _write(grid, center, row + 1, 0x4F)
        _fill_down(grid, center, row + 2, 12, 0x50)
        return
    if style == 2:
        _write(grid, column, row, 0x64)
        if length:
            _write(grid, column, row + 1, 0x65)
        if length > 1:
            _fill_down(grid, column, row + 2, length - 2, 0x66)
        return
    for offset in range(length + 1):
        tile = 0x16 if offset == 0 else 0x18 if offset == length else 0x17
        _write(grid, column + offset, row, tile)
        if 0 < offset < length:
            _fill_down(grid, column + offset, row + 1, 12, 0x4C)


def _render_vertical_pipe(grid: list[list[int]], column: int, row: int, height: int) -> None:
    _write(grid, column, row, 0x12)
    _write(grid, column + 1, row, 0x13)
    for offset in range(1, (height & 7) + 1):
        _write(grid, column, row + offset, 0x14)
        _write(grid, column + 1, row + offset, 0x15)


def _render_row_c_object(
    grid: list[list[int]], column: int, identifier: int, length: int, area_type: int,
) -> None:
    count = length + 1
    if identifier == 0:
        hole = (0x87, 0x00, 0x00, 0x00)[area_type]
        for x in range(column, column + count):
            for row in range(8, 13):
                _write(grid, x, row, hole)
    elif identifier == 1:
        for offset in range(count):
            _write(grid, column + offset, 0, 0x42 if offset == 0 else 0x43 if offset == count - 1 else 0x41)
    elif identifier in {2, 3, 4}:
        row = (6, 7, 9)[identifier - 2]
        for x in range(column, column + count):
            _write(grid, x, row, 0x0B)
            _fill_down(grid, x, row + 1, 12, 0x63)
    elif identifier == 5:
        for x in range(column, column + count):
            _write(grid, x, 10, 0x86)
            _fill_down(grid, x, 11, 1, 0x87)
    elif identifier in {6, 7}:
        row = 3 if identifier == 6 else 7
        for x in range(column, column + count):
            _write(grid, x, row, 0xC0)


def _render_row_d_object(grid: list[list[int]], column: int, identifier: int) -> None:
    if identifier == 1:
        _write(grid, column, 0, 0x24)
        for row in range(1, 10):
            _write(grid, column, row, 0x25)
        _write(grid, column, 10, 0x61)
    elif identifier in {2, 3, 4}:
        row, tile = ((6, 0xC5), (7, 0x0C), (8, 0x89))[identifier - 2]
        count = 13 if identifier == 4 else 1
        for offset in range(count):
            _write(grid, column + offset, row, tile)


def _render_row_f_object(
    grid: list[list[int]], column: int, identifier: int, length: int,
) -> None:
    if identifier == 0:
        for x in range(column, column + length + 1):
            _fill_down(grid, x, 0, 12, 0x40)
    elif identifier == 1:
        for x in range(column, column + length + 1):
            _fill_down(grid, x, 1, 12, 0x40 if x in {column, column + length} else 0x44)
    elif identifier == 3:
        heights = (7, 7, 6, 5, 4, 3, 2, 1, 0)
        rows = (3, 3, 4, 5, 6, 7, 8, 9, 10)
        for offset in range(min(length + 1, len(rows))):
            index = 8 - offset
            _fill_down(grid, column + offset, rows[index], heights[index], 0x61)
    elif identifier == 4:
        for offset in range(4):
            _write(grid, column + offset, 8, (0x15, 0x15, 0x1D, 0x1C)[offset])
            _write(grid, column + offset, 9, (0x15, 0x15, 0x20, 0x1F)[offset])


class LevelDocument:
    def __init__(self, area_document: ArtifactDocument, enemy_document: ArtifactDocument) -> None:
        self.area_document = area_document
        self.enemy_document = enemy_document

    @property
    def names(self) -> list[str]:
        return [stream["name"] for stream in self.area_document.document["data"]["streams"]]

    def stream(self, document: ArtifactDocument, name: str) -> dict[str, Any]:
        return next(item for item in document.document["data"]["streams"] if item["name"] == name)

    def area(self, name: str) -> dict[str, Any]:
        return self.stream(self.area_document, name)

    def enemies(self, name: str) -> dict[str, Any]:
        return self.stream(self.enemy_document, name)

    def remember(self, document: ArtifactDocument) -> None:
        document._remember()

    def add_area_object(self, name: str) -> int:
        stream = self.area(name)
        self.remember(self.area_document)
        stream["data"]["objects"].append({
            "column": 0, "row": 0, "page_advance": True, "object_control": 1,
        })
        return len(stream["data"]["objects"]) - 1

    def add_enemy(self, name: str) -> int:
        stream = self.enemies(name)
        self.remember(self.enemy_document)
        stream["data"]["records"].append({
            "kind": "enemy", "column": 0, "row": 8, "page_advance": True,
            "hard_mode": False, "object_or_page": 6,
        })
        return len(stream["data"]["records"]) - 1

    def delete(self, name: str, kind: str, index: int) -> None:
        document = self.area_document if kind == "object" else self.enemy_document
        stream = self.area(name) if kind == "object" else self.enemies(name)
        key = "objects" if kind == "object" else "records"
        self.remember(document)
        del stream["data"][key][index]
