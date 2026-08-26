#!/usr/bin/env python3
"""Visual editor for every original SMB1 area, object, enemy, and entrance stream."""

from __future__ import annotations

import argparse
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

from level_studio_model import LevelDocument, positioned_area_objects, positioned_enemy_objects
from studio_common import dirty, guard, load_documents, run_make, save_documents


CELL = 28
ROWS = 14


class LevelStudio(tk.Tk):
    def __init__(self, model: LevelDocument, documents: dict, project_root: Path) -> None:
        super().__init__()
        self.model = model
        self.documents = documents
        self.project_root = project_root
        self.area_name = tk.StringVar(value=model.names[0])
        self.selection: tuple[str, int] | None = None
        self.status = tk.StringVar()
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
        area_box.bind("<<ComboboxSelected>>", lambda _event: self.select_area())
        for text, command in (
            ("Add object", self.add_object), ("Add enemy", self.add_enemy),
            ("Delete selected", self.delete_selected), ("Undo", self.undo),
            ("Save", self.save), ("Build ROM", lambda: run_make(project_root, "build-content")),
            ("Run FCEUX", lambda: run_make(project_root, "run-content")),
        ):
            ttk.Button(toolbar, text=text, command=command).pack(side="left", padx=2)

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
            spin = ttk.Spinbox(header, from_=low, to=high, textvariable=variable, width=4)
            spin.grid(row=0, column=column * 2 + 1, padx=(0, 8))
            spin.bind("<Return>", lambda _event: self.apply_header())
            spin.bind("<FocusOut>", lambda _event: self.apply_header())

        body = ttk.Panedwindow(self, orient="horizontal")
        body.pack(fill="both", expand=True, padx=7, pady=7)
        view = ttk.Frame(body)
        side = ttk.Frame(body, padding=(7, 0))
        body.add(view, weight=5)
        body.add(side, weight=2)
        self.canvas = tk.Canvas(view, bg="#101820", height=ROWS * CELL + 40)
        x_scroll = ttk.Scrollbar(view, orient="horizontal", command=self.canvas.xview)
        self.canvas.configure(xscrollcommand=x_scroll.set)
        self.canvas.pack(fill="both", expand=True)
        x_scroll.pack(fill="x")
        self.canvas.bind("<Button-1>", self.canvas_click)

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
            text="Values accept decimal or $hex. The canvas uses 16-pixel engine cells; blue records are terrain objects and red records are enemies.",
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

    def select_area(self) -> None:
        self.selection = None
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
        max_x = max([32] + [int(item["x"]) for item in objects + enemies]) + 3
        width = max_x * CELL
        for page in range((max_x + 15) // 16):
            x = page * 16 * CELL
            self.canvas.create_rectangle(x, 0, x + 16 * CELL, ROWS * CELL, outline="#415365")
            self.canvas.create_text(x + 5, 5, text=f"Page {page}", fill="#8ea4b7", anchor="nw")
        for row in range(ROWS):
            y = row * CELL
            self.canvas.create_line(0, y, width, y, fill="#263747")
        for item in objects:
            x, y = int(item["x"]) * CELL, min(int(item["row"]), ROWS - 1) * CELL
            selected = self.selection == ("object", int(item["index"]))
            self.canvas.create_rectangle(x + 2, y + 2, x + CELL - 2, y + CELL - 2,
                                         fill="#2f81b7", outline="#ffe066" if selected else "#a7d8f5", width=3 if selected else 1,
                                         tags=(f"object:{item['index']}",))
            self.canvas.create_text(x + CELL / 2, y + CELL / 2, text=str(item["index"]), fill="white",
                                    tags=(f"object:{item['index']}",))
        for item in enemies:
            x, y = int(item["x"]) * CELL, min(int(item["row"]), ROWS - 1) * CELL
            selected = self.selection == ("enemy", int(item["index"]))
            self.canvas.create_oval(x + 3, y + 3, x + CELL - 3, y + CELL - 3,
                                    fill="#c44536", outline="#ffe066" if selected else "#ffc0b8", width=3 if selected else 1,
                                    tags=(f"enemy:{item['index']}",))
            self.canvas.create_text(x + CELL / 2, y + CELL / 2, text=str(item["index"]), fill="white",
                                    tags=(f"enemy:{item['index']}",))
        self.canvas.configure(scrollregion=(0, 0, width, ROWS * CELL + 1))

    def canvas_click(self, event: tk.Event) -> None:
        items = self.canvas.find_overlapping(self.canvas.canvasx(event.x), event.y, self.canvas.canvasx(event.x), event.y)
        for canvas_item in reversed(items):
            for tag in self.canvas.gettags(canvas_item):
                if ":" in tag:
                    kind, index = tag.split(":", 1)
                    self.set_selection(kind, int(index))
                    return

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
            self.model.remember(self.model.area_document)
            area["data"]["header"] = replacement
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
    documents, _labels = load_documents(args.formats, args.studios, args.labels, args.workspace, "level")
    model = LevelDocument(documents["area_object_streams"], documents["enemy_object_streams"])
    for name in model.names:
        positioned_area_objects(model.area(name))
        positioned_enemy_objects(model.enemies(name))
    if args.check:
        for document in documents.values():
            document.validate()
        print(f"[OK] Level Studio: {len(model.names)} areas are editable")
        return 0
    application = LevelStudio(model, documents, args.project_root)
    if args.smoke_ui:
        application.update_idletasks()
        application.destroy()
        print("[OK] Level Studio widgets constructed")
    else:
        application.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
