#!/usr/bin/env python3
"""Edit SMB1 world routing, area selection, and player movement characteristics."""

from __future__ import annotations

import argparse
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

from level_studio_model import AREA_TYPES
from studio_common import change_document, dirty, guard, load_documents, run_make, save_documents


PHYSICS_HELP = {
    "jump_gravity": "Upward force added each frame for standing, walking, running, and water profiles",
    "fall_gravity": "Downward force added each frame after the jump apex",
    "initial_y_speed": "Signed initial vertical speed; negative values move Mario upward",
    "initial_y_fraction": "Fractional component paired with the initial vertical speed",
    "maximum_left_speed": "Signed leftward speed limits for walking and running profiles",
    "maximum_right_speed": "Rightward speed limits for walking, running, and water profiles",
    "horizontal_friction": "Acceleration/deceleration force on ground and in water",
    "climb_y_speed": "Signed climbing speeds for idle, up, and down",
    "climb_y_fraction": "Fractional climbing speed components",
}


class WorldStudio(tk.Tk):
    def __init__(
        self, documents: dict, project_root: Path, profile_id: str = "ju"
    ) -> None:
        super().__init__()
        self.documents = documents
        self.project_root = project_root
        self.profile_id = profile_id
        self.pointer_document = documents["world_area_pointers"]
        self.physics_document = documents["player_physics_profiles"]
        self.selection: tuple[int, int] | None = None
        self.area_type = tk.StringVar()
        self.area_index = tk.IntVar()
        self.alternate = tk.BooleanVar()
        self.status = tk.StringVar()
        self.title(f"SMB1 World Studio [{profile_id}]")
        self.geometry("1050x720")
        self.protocol("WM_DELETE_WINDOW", self.close)
        self.build_ui()
        self.refresh()

    def build_ui(self) -> None:
        toolbar = ttk.Frame(self, padding=7)
        toolbar.pack(fill="x")
        for text, command in (
            ("Undo routing", self.undo_routing), ("Undo physics", self.undo_physics),
            ("Save", self.save),
            ("Build ROM", lambda: run_make(
                self.project_root, "build-content", self.profile_id,
            )),
            ("Run FCEUX", lambda: run_make(
                self.project_root, "run-content", self.profile_id,
            )),
        ):
            ttk.Button(toolbar, text=text, command=command).pack(side="left", padx=2)
        notebook = ttk.Notebook(self)
        notebook.pack(fill="both", expand=True, padx=7)
        routing = ttk.Frame(notebook, padding=7)
        physics = ttk.Frame(notebook, padding=7)
        notebook.add(routing, text="World routing")
        notebook.add(physics, text="Player physics")
        self.build_routing(routing)
        self.build_physics(physics)
        ttk.Label(self, textvariable=self.status, anchor="w", padding=7).pack(fill="x")

    def build_routing(self, parent: ttk.Frame) -> None:
        ttk.Label(
            parent,
            text="Each visible course chooses one reusable area stream. Changing a route does not duplicate or move level data.",
        ).pack(anchor="w", pady=(0, 6))
        body = ttk.Panedwindow(parent, orient="horizontal")
        body.pack(fill="both", expand=True)
        self.tree = ttk.Treeview(body, columns=("course", "type", "index", "alternate"), show="headings")
        for name, heading, width in (
            ("course", "Course", 90), ("type", "Area type", 140),
            ("index", "Area number", 100), ("alternate", "Alternate bit", 100),
        ):
            self.tree.heading(name, text=heading)
            self.tree.column(name, width=width)
        self.tree.bind("<<TreeviewSelect>>", self.select_pointer)
        body.add(self.tree, weight=3)
        editor = ttk.LabelFrame(body, text="Selected course", padding=12)
        body.add(editor, weight=1)
        ttk.Label(editor, text="Area type").grid(row=0, column=0, sticky="w")
        ttk.Combobox(editor, textvariable=self.area_type, values=AREA_TYPES,
                     state="readonly", width=16).grid(row=0, column=1, padx=5)
        ttk.Label(editor, text="Area number").grid(row=1, column=0, sticky="w", pady=8)
        ttk.Spinbox(editor, from_=1, to=32, textvariable=self.area_index, width=6).grid(row=1, column=1)
        ttk.Checkbutton(editor, text="Set alternate/high bit", variable=self.alternate).grid(
            row=2, column=0, columnspan=2, sticky="w"
        )
        ttk.Button(editor, text="Apply route", command=self.apply_pointer).grid(
            row=3, column=0, columnspan=2, sticky="ew", pady=(10, 0)
        )

    def build_physics(self, parent: ttk.Frame) -> None:
        canvas = tk.Canvas(parent, highlightthickness=0)
        scrollbar = ttk.Scrollbar(parent, orient="vertical", command=canvas.yview)
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        frame = ttk.Frame(canvas)
        canvas.create_window((0, 0), window=frame, anchor="nw")
        frame.bind("<Configure>", lambda _event: canvas.configure(scrollregion=canvas.bbox("all")))
        self.physics_vars: list[list[tk.IntVar]] = []
        tables = self.physics_document.document["data"]["tables"]
        for row, table in enumerate(tables):
            group = ttk.LabelFrame(frame, text=table["name"].replace("_", " ").title(), padding=7)
            group.grid(row=row, column=0, sticky="ew", pady=4)
            variables = []
            for column, value in enumerate(table["values"]):
                variable = tk.IntVar(value=value)
                variables.append(variable)
                ttk.Label(group, text=f"Profile {column}").grid(row=0, column=column, padx=3)
                low, high = (-128, 127) if table["signed"] else (0, 255)
                ttk.Spinbox(group, from_=low, to=high, textvariable=variable, width=6).grid(
                    row=1, column=column, padx=3
                )
            ttk.Label(group, text=PHYSICS_HELP.get(table["name"], ""), wraplength=760).grid(
                row=2, column=0, columnspan=max(1, len(variables)), sticky="w", pady=(6, 0)
            )
            self.physics_vars.append(variables)
        ttk.Button(frame, text="Apply all physics values", command=self.apply_physics).grid(
            row=len(tables), column=0, sticky="ew", pady=7
        )

    def refresh(self) -> None:
        self.tree.delete(*self.tree.get_children())
        for world_index, world in enumerate(self.pointer_document.document["data"]["worlds"]):
            for level_index, pointer in enumerate(world["areas"]):
                iid = f"{world_index}:{level_index}"
                self.tree.insert("", "end", iid=iid, values=(
                    f"{world_index + 1}-{level_index + 1}", AREA_TYPES[pointer["area_type"]],
                    pointer["area_index"] + 1, "yes" if pointer["alternate_bit"] else "no",
                ))
        self.status.set("Unsaved edits" if dirty(self.documents) else "All world settings are saved")
        self.title(
            f"SMB1 World Studio [{self.profile_id}]"
            + (" *" if dirty(self.documents) else "")
        )

    def select_pointer(self, _event: object = None) -> None:
        if not self.tree.selection():
            return
        world, level = (int(value) for value in self.tree.selection()[0].split(":"))
        self.selection = world, level
        pointer = self.pointer_document.document["data"]["worlds"][world]["areas"][level]
        self.area_type.set(AREA_TYPES[pointer["area_type"]])
        self.area_index.set(pointer["area_index"] + 1)
        self.alternate.set(pointer["alternate_bit"])

    def apply_pointer(self) -> None:
        if self.selection is None:
            return
        world, level = self.selection
        pointer = self.pointer_document.document["data"]["worlds"][world]["areas"][level]
        replacement = {
            "area_type": AREA_TYPES.index(self.area_type.get()),
            "area_index": int(self.area_index.get()) - 1,
            "alternate_bit": bool(self.alternate.get()),
        }
        if replacement != pointer:
            routes = self.pointer_document.document["data"]["worlds"][world]["areas"]
            guard("World Studio", lambda: (
                change_document(self.pointer_document, lambda: routes.__setitem__(level, replacement)),
                self.refresh(),
            ))

    def apply_physics(self) -> None:
        tables = self.physics_document.document["data"]["tables"]
        replacement = [[int(variable.get()) for variable in row] for row in self.physics_vars]
        if replacement != [table["values"] for table in tables]:
            def apply() -> None:
                for table, values in zip(tables, replacement):
                    table["values"] = values
            guard("World Studio", lambda: (
                change_document(self.physics_document, apply), self.refresh(),
            ))

    def undo_routing(self) -> None:
        self.pointer_document.undo()
        self.refresh()

    def undo_physics(self) -> None:
        if self.physics_document.undo():
            for table, variables in zip(self.physics_document.document["data"]["tables"], self.physics_vars):
                for value, variable in zip(table["values"], variables):
                    variable.set(value)
        self.refresh()

    def save(self) -> None:
        self.apply_physics()
        guard("World Studio", lambda: (save_documents(self.documents), self.refresh()))

    def close(self) -> None:
        if dirty(self.documents) and not messagebox.askyesno("Unsaved edits", "Discard unsaved world edits?"):
            return
        self.destroy()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--formats", required=True, type=Path)
    parser.add_argument("--studios", required=True, type=Path)
    parser.add_argument("--profiles", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--content-prg", required=True, type=Path)
    parser.add_argument("--content-chr", required=True, type=Path)
    parser.add_argument("--content-payload", action="append")
    parser.add_argument("--content-payload-labels", action="append")
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--smoke-ui", action="store_true")
    args = parser.parse_args()
    documents, _labels = load_documents(
        args.formats,
        args.studios,
        args.labels,
        args.profiles,
        args.content_prg,
        args.content_chr,
        args.content_payload,
        args.content_payload_labels,
        args.workspace,
        "world",
        args.profile,
    )
    for document in documents.values():
        document.validate()
    if args.check:
        worlds = documents["world_area_pointers"].document["data"]["worlds"]
        profiles = documents["player_physics_profiles"].document["data"]["tables"]
        print(f"[OK] World Studio: {sum(len(world['areas']) for world in worlds)} routes and {len(profiles)} physics tables")
        return 0
    application = WorldStudio(documents, args.project_root, args.profile)
    if args.smoke_ui:
        application.update_idletasks()
        application.destroy()
        print("[OK] World Studio widgets constructed")
    else:
        application.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
