#!/usr/bin/env python3
"""Visual editor for every original SMB1 area, object, enemy, and entrance stream."""

from __future__ import annotations

import argparse
import os
import subprocess
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

from content_studio_model import ChrDocument
from embedded_fceux import EmbeddedFceux
from level_studio_model import (
    NONVISUAL_ENEMY_IDS,
    LevelDocument,
    LevelVisuals,
    area_pointer,
    default_preview_theme,
    enemy_group_preview,
    enemy_preview_y,
    firebar_preview_offsets,
    first_world_context,
    object_width,
    player_entrance_preview_position,
    positioned_area_objects,
    positioned_enemy_objects,
    render_level_scene,
)
from studio_common import NES_RGB, dirty, guard, load_documents, run_make, save_documents


CELL = 32
ROWS = 13
PIXEL_SCALE = CELL // 16
DAY_BACKGROUND_RGB = "#5D96FF"


class LevelStudio(tk.Tk):
    def __init__(
        self,
        model: LevelDocument,
        documents: dict,
        visuals: LevelVisuals,
        project_root: Path,
    ) -> None:
        super().__init__()
        self.model = model
        self.documents = documents
        self.visuals = visuals
        self.project_root = project_root
        initial_area = "ground_6" if "ground_6" in model.names else model.names[0]
        self.area_name = tk.StringVar(value=initial_area)
        self.preview_theme = tk.StringVar(
            value=default_preview_theme(initial_area, model.area(initial_area)),
        )
        self.selection: tuple[str, int] | None = None
        self.status = tk.StringVar()
        self.syncing_controls = False
        self.place_mario_mode = False
        self.metatile_images: dict[tuple[str, str, int], tk.PhotoImage] = {}
        initial_entrance = int(
            model.area(initial_area)["data"]["header"]["entrance_control"],
        )
        self.mario_column, self.mario_row = player_entrance_preview_position(
            initial_entrance,
        )
        default_world, default_level = first_world_context(self.area_name.get())
        self.playtest_world = tk.IntVar(value=default_world + 1)
        self.playtest_level = tk.IntVar(value=default_level + 1)
        self.field_vars = {
            name: tk.StringVar() for name in
            ("column", "row", "object_control", "page_advance", "hard_mode", "kind",
             "entrance_world", "entrance_page")
        }
        self.title("SMB1 Level Studio")
        self.geometry("1320x790")
        self.minsize(980, 620)
        self.protocol("WM_DELETE_WINDOW", self.close)
        self.build_ui()
        self.emulator = EmbeddedFceux(self.emulator_host, self.set_playtest_status)
        self.refresh()

    def build_ui(self) -> None:
        toolbar = ttk.Frame(self, padding=7)
        toolbar.pack(fill="x")
        ttk.Label(toolbar, text="Area").pack(side="left")
        area_box = ttk.Combobox(
            toolbar, textvariable=self.area_name, values=self.model.names,
            state="readonly", width=22,
        )
        area_box.pack(side="left", padx=5)
        self.area_name.trace_add("write", self.select_area_from_control)
        ttk.Label(toolbar, text="Lighting").pack(side="left", padx=(5, 2))
        theme_box = ttk.Combobox(
            toolbar,
            textvariable=self.preview_theme,
            values=("Day", "Night"),
            state="readonly",
            width=7,
        )
        theme_box.pack(side="left", padx=(0, 5))
        self.preview_theme.trace_add("write", self.change_theme_from_control)
        for text, command in (
            ("Add object", self.add_object), ("Add enemy", self.add_enemy),
            ("Delete selected", self.delete_selected), ("Undo", self.undo),
            ("Save", self.save), ("Build ROM", lambda: run_make(self.project_root, "build-content")),
            ("Place Mario", self.arm_mario_placement),
            ("Play", self.playtest), ("Stop", self.stop_playtest),
        ):
            ttk.Button(toolbar, text=text, command=command).pack(side="left", padx=2)
        ttk.Label(toolbar, text="World").pack(side="left", padx=(10, 2))
        ttk.Spinbox(
            toolbar, from_=1, to=8, textvariable=self.playtest_world, width=3,
            command=self.refresh,
        ).pack(side="left")
        ttk.Label(toolbar, text="Course").pack(side="left", padx=(6, 2))
        ttk.Spinbox(
            toolbar, from_=1, to=4, textvariable=self.playtest_level, width=3,
            command=self.refresh,
        ).pack(side="left")

        header = ttk.LabelFrame(self, text="Area header", padding=6)
        header.pack(fill="x", padx=7)
        self.header_vars = {}
        header_fields = (
            ("timer_setting", "Timer", 0, 3), ("entrance_control", "Entrance Y", 0, 7),
            ("foreground_or_color", "Foreground/color", 0, 7), ("area_style", "Platform style", 0, 3),
            ("background_scenery", "Scenery", 0, 3), ("terrain_control", "Terrain", 0, 15),
        )
        for column, (name, label, low, high) in enumerate(header_fields):
            variable = tk.IntVar()
            self.header_vars[name] = variable
            ttk.Label(header, text=label).grid(row=0, column=column * 2, padx=(3, 1))
            spin = ttk.Spinbox(
                header,
                from_=low,
                to=high,
                textvariable=variable,
                width=4,
                command=self.apply_header,
            )
            spin.grid(row=0, column=column * 2 + 1, padx=(0, 8))
            spin.bind("<Return>", lambda _event: self.apply_header())
            spin.bind("<FocusOut>", lambda _event: self.apply_header())

        body = ttk.Panedwindow(self, orient="horizontal")
        body.pack(fill="both", expand=True, padx=7, pady=7)
        view = ttk.Frame(body)
        side = ttk.Frame(body, padding=(7, 0))
        body.add(view, weight=5)
        body.add(side, weight=2)
        self.view_notebook = ttk.Notebook(view)
        self.view_notebook.pack(fill="both", expand=True)
        map_view = ttk.Frame(self.view_notebook)
        playtest_view = ttk.Frame(self.view_notebook)
        self.view_notebook.add(map_view, text="Level map")
        self.view_notebook.add(playtest_view, text="Playtest")
        self.canvas = tk.Canvas(map_view, bg="#101820", height=ROWS * CELL + 40)
        x_scroll = ttk.Scrollbar(map_view, orient="horizontal", command=self.canvas.xview)
        self.canvas.configure(xscrollcommand=x_scroll.set)
        self.canvas.pack(fill="both", expand=True)
        x_scroll.pack(fill="x")
        self.canvas.bind("<Button-1>", self.canvas_click)
        self.canvas.bind("<Button-3>", self.place_mario)
        self.emulator_host = tk.Frame(playtest_view, bg="black", width=768, height=720)
        self.emulator_host.pack(fill="both", expand=True)
        self.emulator_host.pack_propagate(False)

        self.notebook = ttk.Notebook(side)
        self.notebook.pack(fill="both", expand=True)
        self.object_tree = self.make_tree(self.notebook, "Objects")
        self.enemy_tree = self.make_tree(self.notebook, "Enemies and entrances")
        self.object_tree.bind("<<TreeviewSelect>>", lambda _event: self.tree_select("object"))
        self.enemy_tree.bind("<<TreeviewSelect>>", lambda _event: self.tree_select("enemy"))

        editor = ttk.LabelFrame(side, text="Selected record", padding=6)
        editor.pack(fill="x", pady=(7, 0))
        for row, name in enumerate(("kind", "column", "row", "object_control",
                                    "entrance_world", "entrance_page")):
            ttk.Label(editor, text=name.replace("_", " ").title()).grid(row=row, column=0, sticky="w")
            if name == "kind":
                ttk.Combobox(editor, textvariable=self.field_vars[name],
                             values=("object", "enemy", "entrance", "page"),
                             state="readonly", width=14).grid(row=row, column=1, sticky="ew")
            else:
                ttk.Entry(editor, textvariable=self.field_vars[name], width=16).grid(row=row, column=1, sticky="ew")
        ttk.Checkbutton(editor, text="Advance page", variable=self.field_vars["page_advance"],
                        onvalue="true", offvalue="false").grid(row=6, column=0, columnspan=2, sticky="w")
        ttk.Checkbutton(editor, text="Hard mode only", variable=self.field_vars["hard_mode"],
                        onvalue="true", offvalue="false").grid(row=7, column=0, columnspan=2, sticky="w")
        ttk.Button(editor, text="Apply record", command=lambda: guard("Level Studio", self.apply_record)).grid(
            row=8, column=0, columnspan=2, sticky="ew", pady=(5, 0)
        )
        ttk.Label(
            editor,
            text="Values accept decimal or $hex. The map is reconstructed from the game's CHR, palettes, metatiles, scenery tables, and object streams.",
            wraplength=330,
        ).grid(row=9, column=0, columnspan=2, sticky="w", pady=(7, 0))
        ttk.Label(self, textvariable=self.status, anchor="w", padding=7).pack(fill="x")

    @staticmethod
    def make_tree(parent: ttk.Notebook, title: str) -> ttk.Treeview:
        frame = ttk.Frame(parent)
        parent.add(frame, text=title)
        tree = ttk.Treeview(frame, columns=("x", "y", "description"), show="headings")
        for name, heading, width in (("x", "X", 42), ("y", "Y", 42), ("description", "Record", 250)):
            tree.heading(name, text=heading)
            tree.column(name, width=width, stretch=name == "description")
        tree.pack(fill="both", expand=True)
        return tree

    def select_area_from_control(self, *_args: str) -> None:
        if not self.syncing_controls:
            self.select_area()

    def change_theme_from_control(self, *_args: str) -> None:
        if not self.syncing_controls:
            self.change_theme()

    def select_area(self) -> None:
        self.selection = None
        self.syncing_controls = True
        try:
            self.preview_theme.set(default_preview_theme(
                self.area_name.get(), self.model.area(self.area_name.get()),
            ))
            default_world, default_level = first_world_context(self.area_name.get())
            self.playtest_world.set(default_world + 1)
            self.playtest_level.set(default_level + 1)
        finally:
            self.syncing_controls = False
        self.reset_mario_to_entrance()
        self.refresh()

    def change_theme(self) -> None:
        self.metatile_images.clear()
        self.refresh()

    def refresh(self) -> None:
        name = self.area_name.get()
        area = self.model.area(name)
        objects = positioned_area_objects(area)
        enemies = positioned_enemy_objects(self.model.enemies(name))
        for key, variable in self.header_vars.items():
            variable.set(area["data"]["header"][key])
        self.object_tree.delete(*self.object_tree.get_children())
        for item in objects:
            self.object_tree.insert("", "end", iid=str(item["index"]), values=(item["x"], item["row"], item["description"]))
        self.enemy_tree.delete(*self.enemy_tree.get_children())
        for item in enemies:
            self.enemy_tree.insert("", "end", iid=str(item["index"]), values=(item["x"], item["row"], item["description"]))
        self.draw_canvas(objects, enemies)
        used_objects = 3 + len(area["data"]["objects"]) * 2
        enemy_stream = self.model.enemies(name)
        used_enemies = 1 + sum(3 if item["kind"] == "entrance" else 2 for item in enemy_stream["data"]["records"])
        self.status.set(
            f"{name}: objects {used_objects}/{area['capacity_bytes']} bytes, "
            f"enemies {used_enemies}/{enemy_stream['capacity_bytes']} bytes | "
            f"{'unsaved edits' if dirty(self.documents) else 'saved'}"
        )
        self.title("SMB1 Level Studio" + (" *" if dirty(self.documents) else ""))

    def draw_canvas(self, objects: list[dict], enemies: list[dict]) -> None:
        self.canvas.delete("all")
        name = self.area_name.get()
        scene = render_level_scene(
            name,
            self.model.area(name),
            self.model.enemies(name),
            int(self.playtest_world.get()) - 1,
        )
        width = scene.width * CELL
        area_type = name.rpartition("_")[0]
        for column, values in enumerate(scene.metatiles):
            for row, metatile in enumerate(values):
                self.canvas.create_image(
                    column * CELL,
                    row * CELL,
                    image=self.metatile_image(area_type, metatile),
                    anchor="nw",
                )
        for page in range((scene.width + 15) // 16):
            x = page * 16 * CELL
            self.canvas.create_line(x, 0, x, 13 * CELL, fill="#ffffff", dash=(3, 7))
            self.canvas.create_rectangle(x + 3, 3, x + 62, 22, fill="#101820", outline="#8ea4b7")
            self.canvas.create_text(x + 8, 6, text=f"Page {page}", fill="#ffffff", anchor="nw")
        for item in objects:
            x, y = int(item["x"]) * CELL, min(int(item["row"]), 12) * CELL
            selected = self.selection == ("object", int(item["index"]))
            extent = object_width(item) * CELL
            self.canvas.create_rectangle(
                x + 1, y + 1, x + extent - 1, y + CELL - 1,
                outline="#ffe066" if selected else "#67c7ff",
                width=3 if selected else 1,
                dash=() if selected else (2, 3),
                tags=(f"object:{item['index']}",),
            )
            self.draw_badge(x + 2, y + 2, str(item["index"]), "#12628c", f"object:{item['index']}")
        for item in scene.enemies:
            x = int(item["x"]) * CELL
            selected = self.selection == ("enemy", int(item["index"]))
            identifier = int(item["object_or_page"])
            tag = f"enemy:{item['index']}"
            y, actor_width, actor_height = self.draw_enemy_preview(
                item, x, identifier, tag, area_type,
            )
            if selected:
                self.canvas.create_rectangle(
                    x, y, x + actor_width, y + actor_height,
                    outline="#ffe066", width=3,
                    tags=(tag,),
                )
            self.draw_badge(x, y, str(item["index"]), "#9d2c20", tag)
        mario_x = self.mario_column * CELL
        mario_y = self.mario_row * CELL
        self.draw_sprite(
            self.visuals.player_tiles(),
            0,
            mario_x,
            mario_y,
            "mario-start",
            horizontal_flips=self.visuals.player_horizontal_flips(),
        )
        self.canvas.configure(scrollregion=(0, 0, width, 13 * CELL + 1))

    def metatile_image(self, area_type: str, value: int) -> tk.PhotoImage:
        key = (area_type, self.preview_theme.get(), value)
        if key in self.metatile_images:
            return self.metatile_images[key]
        palette_values = self.visuals.palette(area_type)
        background_color = DAY_BACKGROUND_RGB if self.preview_theme.get() == "Day" else "#000000"
        palette_group = (value >> 6) & 3
        palette = palette_values[palette_group * 4:palette_group * 4 + 4]
        record = self.visuals.display_metatile_record(value)
        rows: list[list[str]] = []
        for metatile_row in range(2):
            for pixel_row in range(8):
                colors = []
                for metatile_column in range(2):
                    tile = record[metatile_row * 2 + metatile_column]
                    colors.extend(
                        background_color if pixel == 0 else NES_RGB[palette[pixel] & 0x3F]
                        for pixel in self.visuals.tiles[0x100 + tile][pixel_row]
                    )
                rows.append(colors)
        base = tk.PhotoImage(width=16, height=16)
        base.put("{" + "} {".join(" ".join(row) for row in rows) + "}")
        image = base.zoom(PIXEL_SCALE, PIXEL_SCALE)
        self.metatile_images[key] = image
        return image

    def draw_sprite(
        self,
        tiles: tuple[int, ...],
        palette_row: int,
        x: int,
        y: int,
        tag: str,
        horizontal_flips: tuple[bool, ...] = (),
        columns: int = 2,
        palette_override: tuple[int, ...] = (),
    ) -> None:
        if palette_override:
            colors = palette_override
        else:
            palette = self.visuals.palette(self.area_name.get().rpartition("_")[0])
            colors = palette[16 + palette_row * 4:20 + palette_row * 4]
        for index, tile in enumerate(tiles):
            if tile == 0xFC or not 0 <= tile < len(self.visuals.tiles):
                continue
            tile_x = x + (index % columns) * 8 * PIXEL_SCALE
            tile_y = y + (index // columns) * 8 * PIXEL_SCALE
            for pixel_row, values in enumerate(self.visuals.tiles[tile]):
                for pixel_column, pixel in enumerate(values):
                    if pixel == 0:
                        continue
                    flip_horizontally = (
                        index < len(horizontal_flips) and horizontal_flips[index]
                    )
                    display_column = 7 - pixel_column if flip_horizontally else pixel_column
                    left = tile_x + display_column * PIXEL_SCALE
                    top = tile_y + pixel_row * PIXEL_SCALE
                    self.canvas.create_rectangle(
                        left, top, left + PIXEL_SCALE, top + PIXEL_SCALE,
                        fill=NES_RGB[colors[pixel] & 0x3F], outline="", tags=(tag,),
                    )

    def draw_enemy_preview(
        self,
        item: dict,
        x: int,
        identifier: int,
        tag: str,
        area_type: str,
    ) -> tuple[int, int, int]:
        group = enemy_group_preview(identifier)
        if group is not None:
            member, count, viewport_y = group
            y = viewport_y * PIXEL_SCALE
            for member_index in range(count):
                self.draw_sprite(
                    self.visuals.enemy_display_tiles(member),
                    self.visuals.enemy_palette(member),
                    x + member_index * 24 * PIXEL_SCALE,
                    y,
                    tag,
                    horizontal_flips=self.visuals.enemy_horizontal_flips(member),
                )
            width = (count - 1) * 24 * PIXEL_SCALE + CELL
            return y, width, CELL * 3 // 2

        y = enemy_preview_y(int(item["row"]), identifier) * PIXEL_SCALE
        if identifier == 0x2D:
            front, rear = self.visuals.bowser_tiles()
            flips = (True,) * 6
            palette = self.visuals.special_palette("bowser")
            self.draw_sprite(
                self.visuals.facing_left_tiles(front),
                1,
                x,
                y,
                tag,
                horizontal_flips=flips,
                palette_override=palette,
            )
            self.draw_sprite(
                self.visuals.facing_left_tiles(rear),
                1,
                x + CELL,
                y + CELL // 2,
                tag,
                horizontal_flips=flips,
                palette_override=palette,
            )
            return y, CELL * 2, CELL * 2
        if 0x1B <= identifier <= 0x1F:
            return self.draw_firebar(identifier, x, y, tag)
        if 0x24 <= identifier <= 0x2C:
            width = self.draw_platform(identifier, x, y, tag, area_type)
            return y, width, CELL

        tiles = self.visuals.enemy_display_tiles(identifier)
        if tiles:
            self.draw_sprite(
                tiles,
                self.visuals.enemy_palette(identifier),
                x,
                y,
                tag,
                horizontal_flips=self.visuals.enemy_horizontal_flips(identifier),
            )
            return y, CELL, CELL * 3 // 2

        marker_size = CELL // 2
        marker_x = x + CELL // 4
        marker_y = y + CELL // 4
        self.canvas.create_rectangle(
            marker_x,
            marker_y,
            marker_x + marker_size,
            marker_y + marker_size,
            outline="#ffc0b8",
            dash=(3, 2) if identifier in NONVISUAL_ENEMY_IDS else (),
            tags=(tag,),
        )
        return y, CELL, CELL

    def draw_firebar(self, identifier: int, x: int, y: int, tag: str) -> tuple[int, int, int]:
        offsets = firebar_preview_offsets(identifier)
        origin_x = x + 4 * PIXEL_SCALE
        origin_y = y + 4 * PIXEL_SCALE
        for segment, (offset_x, offset_y) in enumerate(offsets):
            self.draw_sprite(
                (0x64 + segment % 2,),
                2,
                origin_x + offset_x * PIXEL_SCALE,
                origin_y + offset_y * PIXEL_SCALE,
                tag,
                columns=1,
            )
        minimum_y = min(offset_y for _, offset_y in offsets)
        maximum_x = max(offset_x for offset_x, _ in offsets)
        maximum_y = max(offset_y for _, offset_y in offsets)
        top = origin_y + minimum_y * PIXEL_SCALE
        width = (maximum_x + 12) * PIXEL_SCALE
        height = (maximum_y - minimum_y + 8) * PIXEL_SCALE
        return top, width, height

    def draw_platform(
        self,
        identifier: int,
        x: int,
        y: int,
        tag: str,
        area_type: str,
    ) -> int:
        small = identifier in {0x2B, 0x2C}
        tile_count = 3 if small else 4 if area_type == "castle" else 6
        header = self.model.area(self.area_name.get())["data"]["header"]
        tile = 0x75 if header["area_style"] == 3 else 0x5B
        if identifier in {0x26, 0x27, 0x2B, 0x2C}:
            x_offset = 12
        else:
            x_offset = 8 if identifier == 0x24 else 0
        y_offset = -2 if identifier == 0x24 else 0
        self.draw_sprite(
            (tile,) * tile_count,
            2,
            x + x_offset * PIXEL_SCALE,
            y + y_offset * PIXEL_SCALE,
            tag,
            columns=tile_count,
        )
        return x_offset * PIXEL_SCALE + tile_count * 8 * PIXEL_SCALE

    def draw_badge(self, x: int, y: int, text: str, color: str, tag: str) -> None:
        width = 8 + len(text) * 7
        self.canvas.create_rectangle(x, y, x + width, y + 16, fill=color, outline="white", tags=(tag,))
        self.canvas.create_text(x + width / 2, y + 8, text=text, fill="white", tags=(tag,))

    def canvas_click(self, event: tk.Event) -> None:
        if self.place_mario_mode:
            self.place_mario(event)
            return
        items = self.canvas.find_overlapping(self.canvas.canvasx(event.x), event.y, self.canvas.canvasx(event.x), event.y)
        for canvas_item in reversed(items):
            for tag in self.canvas.gettags(canvas_item):
                if ":" in tag:
                    kind, index = tag.split(":", 1)
                    self.set_selection(kind, int(index))
                    return

    def arm_mario_placement(self) -> None:
        self.place_mario_mode = True
        self.status.set("Click the map to place Mario; right-click also places him directly")
        self.canvas.configure(cursor="crosshair")

    def reset_mario_to_entrance(self) -> None:
        header = self.model.area(self.area_name.get())["data"]["header"]
        self.mario_column, self.mario_row = player_entrance_preview_position(
            int(header["entrance_control"]),
        )

    def place_mario(self, event: tk.Event) -> None:
        self.mario_column = max(0, int(self.canvas.canvasx(event.x)) // CELL)
        self.mario_row = max(
            1,
            min(ROWS - 1, int(self.canvas.canvasy(event.y)) // CELL),
        )
        self.place_mario_mode = False
        self.canvas.configure(cursor="")
        self.refresh()

    def playtest(self) -> None:
        guard("Level Studio", self._playtest)

    def _playtest(self) -> None:
        save_documents(self.documents)
        result = subprocess.run(
            ["make", "build-content"],
            cwd=self.project_root,
            check=False,
        )
        if result.returncode:
            raise OSError(f"Content build failed with exit code {result.returncode}")
        executable = Path(os.environ.get(
            "FCEUX_EXE",
            self.project_root / "../fceux_automation/vc/x64/Release/fceux64.exe",
        ))
        rom = self.project_root / "build/content/smb.nes"
        lua = self.project_root / "scripts/workflow/level_point_playtest.lua"
        page = self.mario_column // 16
        environment = {
            "SMB1_PLAYTEST_AREA": str(area_pointer(self.area_name.get())),
            "SMB1_PLAYTEST_WORLD": str(int(self.playtest_world.get()) - 1),
            "SMB1_PLAYTEST_LEVEL": str(int(self.playtest_level.get()) - 1),
            "SMB1_PLAYTEST_PAGE": str(page),
            "SMB1_PLAYTEST_X": str((self.mario_column % 16) * 16),
            "SMB1_PLAYTEST_Y": str(max(32, min(239, (self.mario_row + 1) * 16))),
            "SMB1_PLAYTEST_THEME": self.preview_theme.get().lower(),
        }
        self.view_notebook.select(1)
        self.emulator.start(executable, rom, lua, environment)

    def stop_playtest(self) -> None:
        self.emulator.stop()
        self.view_notebook.select(0)
        self.status.set("Playtest stopped")

    def set_playtest_status(self, message: str) -> None:
        self.status.set(message)

    def tree_select(self, kind: str) -> None:
        tree = self.object_tree if kind == "object" else self.enemy_tree
        if tree.selection():
            self.set_selection(kind, int(tree.selection()[0]))

    def set_selection(self, kind: str, index: int) -> None:
        self.selection = (kind, index)
        stream = self.model.area(self.area_name.get()) if kind == "object" else self.model.enemies(self.area_name.get())
        key = "objects" if kind == "object" else "records"
        item = stream["data"][key][index]
        self.field_vars["kind"].set(kind if kind == "object" else item["kind"])
        for field in ("column", "row", "page_advance"):
            self.field_vars[field].set(str(item[field]).lower())
        self.field_vars["object_control"].set(f"${int(item['object_control' if kind == 'object' else 'object_or_page']):02X}")
        self.field_vars["hard_mode"].set(str(item.get("hard_mode", False)).lower())
        self.field_vars["entrance_world"].set(str(int(item.get("destination_world", 0)) + 1))
        self.field_vars["entrance_page"].set(str(item.get("destination_page", 0)))
        tree = self.object_tree if kind == "object" else self.enemy_tree
        tree.selection_set(str(index))
        self.notebook.select(0 if kind == "object" else 1)
        self.refresh()

    @staticmethod
    def number(text: str) -> int:
        text = text.strip()
        return int(text[1:], 16) if text.startswith("$") else int(text, 0)

    def apply_header(self) -> None:
        area = self.model.area(self.area_name.get())
        replacement = {name: int(variable.get()) for name, variable in self.header_vars.items()}
        if replacement != area["data"]["header"]:
            entrance_changed = (
                replacement["entrance_control"]
                != area["data"]["header"]["entrance_control"]
            )
            self.model.remember(self.model.area_document)
            area["data"]["header"] = replacement
            if entrance_changed:
                self.reset_mario_to_entrance()
            guard("Level Studio", self.refresh)

    def apply_record(self) -> None:
        if self.selection is None:
            return
        kind, index = self.selection
        document = self.model.area_document if kind == "object" else self.model.enemy_document
        stream = self.model.area(self.area_name.get()) if kind == "object" else self.model.enemies(self.area_name.get())
        key = "objects" if kind == "object" else "records"
        item = stream["data"][key][index]
        self.model.remember(document)
        try:
            item["column"] = self.number(self.field_vars["column"].get()) & 0x0F
            item["row"] = self.number(self.field_vars["row"].get()) & 0x0F
            item["page_advance"] = self.field_vars["page_advance"].get() == "true"
            control = self.number(self.field_vars["object_control"].get())
            if kind == "object":
                item["object_control"] = control & 0x7F
            else:
                selected_kind = self.field_vars["kind"].get()
                if selected_kind not in {"enemy", "entrance", "page"}:
                    raise ValueError("Enemy-stream records must be enemy, entrance, or page")
                item["kind"] = selected_kind
                if selected_kind == "entrance":
                    item["row"] = 0x0E
                    item["destination_world"] = self.number(self.field_vars["entrance_world"].get()) - 1
                    item["destination_page"] = self.number(self.field_vars["entrance_page"].get())
                    if not 0 <= item["destination_world"] <= 7 or not 0 <= item["destination_page"] <= 31:
                        raise ValueError("Entrance world must be 1..8 and page must be 0..31")
                elif selected_kind == "page":
                    item["row"] = 0x0F
                item["object_or_page"] = control & 0x3F
                item["hard_mode"] = self.field_vars["hard_mode"].get() == "true"
            document.validate()
        except (ValueError, KeyError, TypeError):
            document.undo()
            raise
        self.refresh()

    def add_object(self) -> None:
        guard("Level Studio", lambda: self._after_add("object", self.model.add_area_object(self.area_name.get())))

    def add_enemy(self) -> None:
        guard("Level Studio", lambda: self._after_add("enemy", self.model.add_enemy(self.area_name.get())))

    def _after_add(self, kind: str, index: int) -> None:
        document = self.model.area_document if kind == "object" else self.model.enemy_document
        try:
            document.validate()
        except (ValueError, KeyError, TypeError):
            document.undo()
            raise
        self.set_selection(kind, index)

    def delete_selected(self) -> None:
        if self.selection is None:
            return
        kind, index = self.selection
        self.model.delete(self.area_name.get(), kind, index)
        document = self.model.area_document if kind == "object" else self.model.enemy_document
        try:
            document.validate()
        except ValueError as error:
            document.undo()
            messagebox.showerror("Level Studio", str(error))
        self.selection = None
        self.refresh()

    def undo(self) -> None:
        if self.selection and self.selection[0] == "object":
            self.model.area_document.undo()
        elif self.selection:
            self.model.enemy_document.undo()
        elif not self.model.area_document.undo():
            self.model.enemy_document.undo()
        self.selection = None
        self.refresh()

    def save(self) -> None:
        guard("Level Studio", lambda: (save_documents(self.documents), self.refresh()))

    def close(self) -> None:
        if dirty(self.documents) and not messagebox.askyesno("Unsaved edits", "Discard unsaved level edits?"):
            return
        self.emulator.stop()
        self.destroy()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--formats", required=True, type=Path)
    parser.add_argument("--studios", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--smoke-ui", action="store_true")
    parser.add_argument(
        "--smoke-playtest", nargs="?", const="Day", choices=("Day", "Night"),
    )
    args = parser.parse_args()
    documents, _labels = load_documents(args.formats, args.studios, args.labels, args.workspace, "level")
    graphics_documents, _labels = load_documents(
        args.formats, args.studios, args.labels, args.workspace, "graphics",
    )
    chr_document = ChrDocument(
        (args.workspace / "graphics" / "smb.chr").read_bytes(),
        args.workspace / "graphics" / "smb.chr",
    )
    visuals = LevelVisuals(
        chr_document.tiles,
        graphics_documents["all_metatiles"].document["data"]["metatiles"],
        graphics_documents["area_palette_packets"].document["data"]["blocks"],
        graphics_documents["player_animation_tiles"].document["data"]["frames"],
    )
    model = LevelDocument(documents["area_object_streams"], documents["enemy_object_streams"])
    for name in model.names:
        positioned_area_objects(model.area(name))
        positioned_enemy_objects(model.enemies(name))
    if args.check:
        for document in documents.values():
            document.validate()
        print(f"[OK] Level Studio: {len(model.names)} areas are editable")
        return 0
    application = LevelStudio(model, documents, visuals, args.project_root)
    if args.smoke_ui:
        application.update_idletasks()
        application.destroy()
        print("[OK] Level Studio widgets constructed")
    elif args.smoke_playtest is not None:
        outcome = {"embedded": False}
        expected_background = "22" if args.smoke_playtest == "Day" else "0f"
        result_path = args.project_root.resolve() / "build" / "level_playtest_smoke.txt"
        result_path.parent.mkdir(parents=True, exist_ok=True)
        result_path.write_text("pending\n", encoding="utf-8")
        os.environ["SMB1_PLAYTEST_RESULT"] = str(result_path)
        application.preview_theme.set(args.smoke_playtest)
        application.change_theme()

        def finish_smoke_test(attempts: int = 150) -> None:
            result = result_path.read_text(encoding="utf-8").strip()
            if (
                application.emulator.window
                and result.startswith("status=ready")
                and f"background={expected_background}" in result
            ):
                outcome["embedded"] = True
                application.stop_playtest()
                application.destroy()
            elif attempts:
                application.after(100, finish_smoke_test, attempts - 1)
            else:
                application.stop_playtest()
                application.destroy()

        application.after(50, application.playtest)
        application.after(100, finish_smoke_test)
        application.mainloop()
        os.environ.pop("SMB1_PLAYTEST_RESULT", None)
        if not outcome["embedded"]:
            raise RuntimeError(
                f"FCEUX {args.smoke_playtest} playtest did not reach the expected state",
            )
        print(
            f"[OK] FCEUX {args.smoke_playtest} playtest reached the expected palette, "
            "embedded, and stopped",
        )
    else:
        application.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
