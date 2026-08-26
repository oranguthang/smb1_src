#!/usr/bin/env python3
"""Edit SMB1 CHR pixels, palettes, metatiles, player sprites, and screen text."""

from __future__ import annotations

import argparse
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

from content_studio_model import ChrDocument, smb_tile_text
from studio_common import (
    NES_RGB, change_document, dirty, draw_tile, guard, load_documents,
    run_make, save_documents,
)


METATILE_GROUPS = (("Palette 0", 0, 39), ("Palette 1", 39, 85),
                   ("Palette 2", 85, 95), ("Palette 3", 95, 101))
TEXT_CHAR_TO_TILE = {str(value): value for value in range(10)}
TEXT_CHAR_TO_TILE.update({chr(ord("A") + value): 0x0A + value for value in range(26)})
TEXT_CHAR_TO_TILE.update({" ": 0x24, "-": 0x28, "!": 0x2B, "x": 0x29})


class GraphicsStudio(tk.Tk):
    def __init__(self, documents: dict, chr_document: ChrDocument, project_root: Path) -> None:
        super().__init__()
        self.documents = documents
        self.chr_document = chr_document
        self.project_root = project_root
        self.tile_index = tk.IntVar(value=256)
        self.bank = tk.IntVar(value=1)
        self.ink = tk.IntVar(value=1)
        self.palette_name = tk.StringVar(value="ground")
        self.palette_slot = tk.IntVar(value=0)
        self.metatile_index = tk.IntVar(value=0)
        self.frame_index = tk.IntVar(value=0)
        self.text_block = tk.StringVar(value="top_status_bar")
        self.text_value = tk.StringVar()
        self.status = tk.StringVar()
        self.stroke = False
        self.title("SMB1 Graphics Studio")
        self.geometry("1320x830")
        self.minsize(1050, 690)
        self.protocol("WM_DELETE_WINDOW", self.close)
        self.build_ui()
        self.refresh_all()

    def build_ui(self) -> None:
        toolbar = ttk.Frame(self, padding=7)
        toolbar.pack(fill="x")
        for text, command in (
            ("Undo CHR", self.undo_chr), ("Restore tile", self.restore_tile),
            ("Save all", self.save), ("Build ROM", lambda: run_make(self.project_root, "build-content")),
            ("Run FCEUX", lambda: run_make(self.project_root, "run-content")),
        ):
            ttk.Button(toolbar, text=text, command=command).pack(side="left", padx=2)
        notebook = ttk.Notebook(self)
        notebook.pack(fill="both", expand=True, padx=7)
        tile_tab = ttk.Frame(notebook, padding=6)
        metatile_tab = ttk.Frame(notebook, padding=6)
        sprite_tab = ttk.Frame(notebook, padding=6)
        palette_tab = ttk.Frame(notebook, padding=6)
        notebook.add(tile_tab, text="CHR tiles")
        notebook.add(metatile_tab, text="Background metatiles")
        notebook.add(sprite_tab, text="Player sprites")
        notebook.add(palette_tab, text="Palettes and UI text")
        self.build_chr_tab(tile_tab)
        self.build_metatile_tab(metatile_tab)
        self.build_sprite_tab(sprite_tab)
        self.build_palette_tab(palette_tab)
        ttk.Label(self, textvariable=self.status, padding=7, anchor="w").pack(fill="x")

    def build_chr_tab(self, parent: ttk.Frame) -> None:
        switch = ttk.Frame(parent)
        switch.pack(fill="x")
        ttk.Label(switch, text="SMB pattern tables:").pack(side="left")
        for label, value in (("Sprites $000-$0FF", 0), ("Background $100-$1FF", 1)):
            ttk.Radiobutton(switch, text=label, variable=self.bank, value=value,
                            command=self.change_bank).pack(side="left", padx=8)
        body = ttk.Panedwindow(parent, orient="horizontal")
        body.pack(fill="both", expand=True, pady=6)
        left = ttk.Frame(body)
        right = ttk.Frame(body, padding=8)
        body.add(left, weight=3)
        body.add(right, weight=2)
        self.bank_canvas = tk.Canvas(left, bg="#1a2028", width=640, height=640)
        self.bank_canvas.pack(fill="both", expand=True)
        self.bank_canvas.bind("<Configure>", lambda _event: self.draw_bank())
        self.bank_canvas.bind("<Button-1>", self.select_tile)
        ttk.Label(right, text="8x8 2bpp pixel editor", font=("Segoe UI", 11, "bold")).pack(anchor="w")
        self.tile_label = ttk.Label(right)
        self.tile_label.pack(anchor="w", pady=4)
        self.pixel_canvas = tk.Canvas(right, width=384, height=384, bg="#111", highlightthickness=0)
        self.pixel_canvas.pack()
        self.pixel_canvas.bind("<ButtonPress-1>", self.start_paint)
        self.pixel_canvas.bind("<B1-Motion>", self.paint)
        self.pixel_canvas.bind("<ButtonRelease-1>", self.end_paint)
        palette = ttk.LabelFrame(right, text="Paint color", padding=6)
        palette.pack(fill="x", pady=8)
        for index in range(4):
            button = tk.Radiobutton(palette, text=str(index), variable=self.ink, value=index,
                                    indicatoron=False, width=7, height=2)
            button.configure(bg=NES_RGB[self.preview_palette()[index]])
            button.pack(side="left", padx=3)

    def build_metatile_tab(self, parent: ttk.Frame) -> None:
        controls = ttk.Frame(parent)
        controls.pack(fill="x")
        ttk.Label(controls, text="Metatile").pack(side="left")
        self.metatile_box = ttk.Combobox(controls, state="readonly", width=34)
        self.metatile_box.pack(side="left", padx=5)
        self.metatile_box.bind("<<ComboboxSelected>>", self.select_metatile)
        ttk.Label(controls, text="Preview palette").pack(side="left", padx=(15, 3))
        palette_box = ttk.Combobox(controls, textvariable=self.palette_name,
                                   values=self.palette_names(), state="readonly", width=15)
        palette_box.pack(side="left")
        palette_box.bind("<<ComboboxSelected>>", lambda _event: self.draw_metatile())
        self.metatile_canvas = tk.Canvas(parent, width=384, height=384, bg="#111")
        self.metatile_canvas.pack(pady=12)
        editor = ttk.LabelFrame(parent, text="Four background tile indexes", padding=7)
        editor.pack()
        self.metatile_vars = [tk.IntVar() for _ in range(4)]
        for index, variable in enumerate(self.metatile_vars):
            ttk.Label(editor, text=("TL", "TR", "BL", "BR")[index]).grid(row=0, column=index)
            ttk.Spinbox(editor, from_=0, to=255, textvariable=variable, width=7).grid(row=1, column=index, padx=4)
        ttk.Button(editor, text="Apply metatile", command=self.apply_metatile).grid(
            row=2, column=0, columnspan=4, sticky="ew", pady=(7, 0)
        )

    def build_sprite_tab(self, parent: ttk.Frame) -> None:
        controls = ttk.Frame(parent)
        controls.pack(fill="x")
        ttk.Label(controls, text="Player animation frame").pack(side="left")
        self.frame_box = ttk.Combobox(controls, state="readonly", width=25)
        self.frame_box.pack(side="left", padx=5)
        self.frame_box.bind("<<ComboboxSelected>>", self.select_frame)
        ttk.Label(controls, text="Sprite palette row").pack(side="left", padx=(15, 3))
        ttk.Spinbox(controls, from_=0, to=3, textvariable=self.palette_slot, width=4,
                    command=self.draw_sprite).pack(side="left")
        self.sprite_canvas = tk.Canvas(parent, width=320, height=520, bg="#111")
        self.sprite_canvas.pack(side="left", padx=25, pady=10)
        editor = ttk.LabelFrame(parent, text="2 x 4 tile mapping", padding=8)
        editor.pack(side="left", padx=25, pady=10)
        self.frame_vars = [tk.IntVar() for _ in range(8)]
        for index, variable in enumerate(self.frame_vars):
            ttk.Spinbox(editor, from_=0, to=255, textvariable=variable, width=7).grid(
                row=index // 2, column=index % 2, padx=4, pady=4
            )
        ttk.Button(editor, text="Apply frame mapping", command=self.apply_frame).grid(
            row=4, column=0, columnspan=2, sticky="ew", pady=(8, 0)
        )
        ttk.Label(editor, text="$FC hides a sprite cell", foreground="#805000").grid(
            row=5, column=0, columnspan=2, pady=7
        )

    def build_palette_tab(self, parent: ttk.Frame) -> None:
        ttk.Label(parent, text="Area palette packet").pack(anchor="w")
        palette_box = ttk.Combobox(parent, textvariable=self.palette_name,
                                   values=self.palette_names(), state="readonly", width=20)
        palette_box.pack(anchor="w", pady=4)
        palette_box.bind("<<ComboboxSelected>>", lambda _event: self.refresh_all())
        self.palette_frame = ttk.Frame(parent)
        self.palette_frame.pack(anchor="w", pady=6)
        self.palette_buttons = []
        for index in range(32):
            button = tk.Button(self.palette_frame, width=8, height=2,
                               command=lambda slot=index: self.choose_color(slot))
            button.grid(row=index // 4, column=index % 4, padx=2, pady=2)
            self.palette_buttons.append(button)
        text_group = ttk.LabelFrame(parent, text="Fixed-length UI text packets", padding=7)
        text_group.pack(fill="x", pady=(12, 0))
        self.text_box = ttk.Combobox(text_group, textvariable=self.text_block,
                                     values=self.text_names(), state="readonly", width=25)
        self.text_box.grid(row=0, column=0, padx=4)
        self.text_box.bind("<<ComboboxSelected>>", lambda _event: self.load_text())
        ttk.Entry(text_group, textvariable=self.text_value, width=55).grid(row=0, column=1, padx=4)
        ttk.Button(text_group, text="Apply text", command=self.apply_text).grid(row=0, column=2, padx=4)
        ttk.Label(text_group, text="Use A-Z, 0-9, space, -, !, and x; encoded length cannot change.").grid(
            row=1, column=0, columnspan=3, sticky="w", pady=5
        )

    def palette_blocks(self) -> list[dict]:
        return self.documents["area_palette_packets"].document["data"]["blocks"]

    def palette_names(self) -> list[str]:
        return [block["name"] for block in self.palette_blocks()]

    def current_palette_values(self) -> list[int]:
        block = next(item for item in self.palette_blocks() if item["name"] == self.palette_name.get())
        values = list(block["packets"][0]["values"])
        base = [0x0F, 0x30, 0x21, 0x11] * 8
        return (values + base[len(values):])[:32]

    def preview_palette(self, sprite: bool | None = None) -> list[int]:
        values = self.current_palette_values()
        if sprite is None:
            sprite = self.bank.get() == 0
        start = (16 if sprite else 0) + self.palette_slot.get() * 4
        return values[start:start + 4]

    def text_names(self) -> list[str]:
        return [block["name"] for block in self.documents["game_text_packets"].document["data"]["blocks"]]

    def refresh_all(self) -> None:
        self.draw_bank()
        self.draw_pixel_editor()
        self.refresh_metatile_choices()
        self.refresh_frame_choices()
        self.refresh_palette_buttons()
        self.load_text()
        changed = dirty(self.documents) or self.chr_document.dirty
        self.status.set(f"Tile ${self.tile_index.get():03X} | palette {self.palette_name.get()} | {'unsaved edits' if changed else 'saved'}")
        self.title("SMB1 Graphics Studio" + (" *" if changed else ""))

    def change_bank(self) -> None:
        self.tile_index.set(self.bank.get() * 256)
        self.refresh_all()

    def draw_bank(self) -> None:
        if not hasattr(self, "bank_canvas"):
            return
        self.bank_canvas.delete("all")
        size = max(2, min(self.bank_canvas.winfo_width(), self.bank_canvas.winfo_height()) // 128)
        tile_size = size * 8
        palette = self.preview_palette()
        base = self.bank.get() * 256
        for relative in range(256):
            x, y = (relative % 16) * tile_size, (relative // 16) * tile_size
            draw_tile(self.bank_canvas, self.chr_document.tiles, base + relative, x, y, size, palette)
            if base + relative == self.tile_index.get():
                self.bank_canvas.create_rectangle(x, y, x + tile_size, y + tile_size, outline="#ffe066", width=2)
        self.bank_canvas.configure(scrollregion=(0, 0, tile_size * 16, tile_size * 16))

    def select_tile(self, event: tk.Event) -> None:
        size = max(2, min(self.bank_canvas.winfo_width(), self.bank_canvas.winfo_height()) // 128)
        tile_size = size * 8
        column, row = event.x // tile_size, event.y // tile_size
        if 0 <= column < 16 and 0 <= row < 16:
            self.tile_index.set(self.bank.get() * 256 + row * 16 + column)
            self.refresh_all()

    def draw_pixel_editor(self) -> None:
        if not hasattr(self, "pixel_canvas"):
            return
        self.pixel_canvas.delete("all")
        palette = self.preview_palette()
        pixels = self.chr_document.tiles[self.tile_index.get()]
        for row in range(8):
            for column in range(8):
                color = NES_RGB[palette[pixels[row][column]]]
                self.pixel_canvas.create_rectangle(column * 48, row * 48, (column + 1) * 48,
                                                   (row + 1) * 48, fill=color, outline="#333")
        self.tile_label.configure(text=f"Tile ${self.tile_index.get():03X}" +
                                  (" - changed" if self.chr_document.changed(self.tile_index.get()) else ""))

    def start_paint(self, event: tk.Event) -> None:
        self.chr_document.begin_stroke(self.tile_index.get())
        self.stroke = True
        self.paint(event)

    def paint(self, event: tk.Event) -> None:
        row, column = event.y // 48, event.x // 48
        if 0 <= row < 8 and 0 <= column < 8:
            self.chr_document.paint(self.tile_index.get(), row, column, self.ink.get())
            self.draw_pixel_editor()

    def end_paint(self, _event: object = None) -> None:
        if self.stroke:
            self.chr_document.end_stroke()
            self.stroke = False
            self.refresh_all()

    def refresh_metatile_choices(self) -> None:
        records = self.documents["all_metatiles"].document["data"]["metatiles"]
        labels = []
        for index in range(len(records)):
            group = next(name for name, start, end in METATILE_GROUPS if start <= index < end)
            labels.append(f"{index:03d} - {group}")
        self.metatile_box.configure(values=labels)
        if self.metatile_box.current() < 0:
            self.metatile_box.current(self.metatile_index.get())
        self.load_metatile()

    def select_metatile(self, _event: object = None) -> None:
        self.metatile_index.set(self.metatile_box.current())
        self.load_metatile()

    def load_metatile(self) -> None:
        record = self.documents["all_metatiles"].document["data"]["metatiles"][self.metatile_index.get()]
        for value, variable in zip(record, self.metatile_vars):
            variable.set(value)
        self.draw_metatile()

    def draw_metatile(self) -> None:
        if not hasattr(self, "metatile_canvas"):
            return
        self.metatile_canvas.delete("all")
        values = self.current_palette_values()
        group_index = next(index for index, (_name, start, end) in enumerate(METATILE_GROUPS)
                           if start <= self.metatile_index.get() < end)
        palette = values[group_index * 4:group_index * 4 + 4]
        for index, variable in enumerate(self.metatile_vars):
            draw_tile(self.metatile_canvas, self.chr_document.tiles, 256 + int(variable.get()),
                      (index % 2) * 192, (index // 2) * 192, 24, palette)

    def apply_metatile(self) -> None:
        document = self.documents["all_metatiles"]
        replacement = [int(variable.get()) for variable in self.metatile_vars]
        records = document.document["data"]["metatiles"]
        if replacement != records[self.metatile_index.get()]:
            guard("Graphics Studio", lambda: (
                change_document(document, lambda: records.__setitem__(self.metatile_index.get(), replacement)),
                self.refresh_all(),
            ))

    def refresh_frame_choices(self) -> None:
        frames = self.documents["player_animation_tiles"].document["data"]["frames"]
        self.frame_box.configure(values=[f"Frame {index:02d}" for index in range(len(frames))])
        if self.frame_box.current() < 0:
            self.frame_box.current(0)
        self.load_frame()

    def select_frame(self, _event: object = None) -> None:
        self.frame_index.set(self.frame_box.current())
        self.load_frame()

    def load_frame(self) -> None:
        frame = self.documents["player_animation_tiles"].document["data"]["frames"][self.frame_index.get()]
        for value, variable in zip(frame, self.frame_vars):
            variable.set(value)
        self.draw_sprite()

    def draw_sprite(self) -> None:
        if not hasattr(self, "sprite_canvas"):
            return
        self.sprite_canvas.delete("all")
        palette = self.preview_palette(sprite=True)
        for index, variable in enumerate(self.frame_vars):
            tile = int(variable.get())
            if tile != 0xFC:
                draw_tile(self.sprite_canvas, self.chr_document.tiles, tile,
                          64 + (index % 2) * 96, 55 + (index // 2) * 96, 12, palette)

    def apply_frame(self) -> None:
        document = self.documents["player_animation_tiles"]
        frames = document.document["data"]["frames"]
        replacement = [int(variable.get()) for variable in self.frame_vars]
        if replacement != frames[self.frame_index.get()]:
            guard("Graphics Studio", lambda: (
                change_document(document, lambda: frames.__setitem__(self.frame_index.get(), replacement)),
                self.refresh_all(),
            ))

    def refresh_palette_buttons(self) -> None:
        if not hasattr(self, "palette_buttons"):
            return
        values = self.current_palette_values()
        for index, button in enumerate(self.palette_buttons):
            value = values[index]
            button.configure(bg=NES_RGB[value], text=f"${value:02X}")

    def choose_color(self, slot: int) -> None:
        picker = tk.Toplevel(self)
        picker.title("Choose NES color")
        for value, color in enumerate(NES_RGB):
            tk.Button(picker, bg=color, text=f"{value:02X}", width=4, height=2,
                      command=lambda selected=value: self.set_color(slot, selected, picker)).grid(
                          row=value // 8, column=value % 8
                      )

    def set_color(self, slot: int, value: int, picker: tk.Toplevel) -> None:
        document = self.documents["area_palette_packets"]
        block = next(item for item in document.document["data"]["blocks"] if item["name"] == self.palette_name.get())
        values = block["packets"][0]["values"]
        if slot >= len(values):
            messagebox.showerror("Graphics Studio", "This short modifier packet does not contain that palette slot")
        elif values[slot] != value:
            guard("Graphics Studio", lambda: (
                change_document(document, lambda: values.__setitem__(slot, value)),
                self.refresh_all(),
            ))
        picker.destroy()

    def current_text_packet(self) -> dict:
        block = next(item for item in self.documents["game_text_packets"].document["data"]["blocks"]
                     if item["name"] == self.text_block.get())
        return block["packets"][0]

    def load_text(self) -> None:
        if hasattr(self, "text_box"):
            self.text_value.set(smb_tile_text(self.current_text_packet()["values"]))

    def apply_text(self) -> None:
        packet = self.current_text_packet()
        text = self.text_value.get().upper()
        if len(text) != len(packet["values"]):
            messagebox.showerror("Graphics Studio", f"Text must remain exactly {len(packet['values'])} characters")
            return
        try:
            replacement = [TEXT_CHAR_TO_TILE[character] for character in text]
        except KeyError as error:
            messagebox.showerror("Graphics Studio", f"Unsupported character: {error.args[0]}")
            return
        document = self.documents["game_text_packets"]
        if replacement != packet["values"]:
            guard("Graphics Studio", lambda: (
                change_document(document, lambda: packet.__setitem__("values", replacement)),
                self.refresh_all(),
            ))

    def undo_chr(self) -> None:
        self.chr_document.undo()
        self.refresh_all()

    def restore_tile(self) -> None:
        self.chr_document.restore_tile(self.tile_index.get())
        self.refresh_all()

    def save(self) -> None:
        guard("Graphics Studio", lambda: (save_documents(self.documents), self.chr_document.save(), self.refresh_all()))

    def close(self) -> None:
        changed = dirty(self.documents) or self.chr_document.dirty
        if changed and not messagebox.askyesno("Unsaved edits", "Discard unsaved graphics edits?"):
            return
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
    args = parser.parse_args()
    documents, _labels = load_documents(args.formats, args.studios, args.labels, args.workspace, "graphics")
    chr_path = args.workspace / "graphics" / "smb.chr"
    chr_document = ChrDocument(chr_path.read_bytes(), chr_path)
    for document in documents.values():
        document.validate()
    if args.check:
        metatiles = documents["all_metatiles"].document["data"]["metatiles"]
        frames = documents["player_animation_tiles"].document["data"]["frames"]
        print(f"[OK] Graphics Studio: 512 CHR tiles, {len(metatiles)} metatiles, and {len(frames)} player frames")
        return 0
    application = GraphicsStudio(documents, chr_document, args.project_root)
    if args.smoke_ui:
        application.update_idletasks()
        application.destroy()
        print("[OK] Graphics Studio widgets constructed")
    else:
        application.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
