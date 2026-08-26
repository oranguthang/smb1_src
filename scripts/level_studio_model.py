"""Semantic model for all vanilla SMB1 area and enemy streams."""

from __future__ import annotations

from typing import Any

from content_studio_model import ArtifactDocument


AREA_TYPES = ("water", "ground", "underground", "castle")

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


def area_name(area_type: int, area_index: int) -> str:
    return f"{AREA_TYPES[area_type]}_{area_index + 1}"


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
        if control & 0x40:
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
        if int(item["row"]) == 0x0D and control & 0x40:
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
