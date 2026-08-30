#!/usr/bin/env python3
"""Piano-roll and envelope editor for the complete SMB sound banks."""

from __future__ import annotations

import argparse
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

from ann_sound_studio_model import AnnFdsMusicBank
from sound_studio_model import MusicBank
from studio_common import (
    change_document, dirty, guard, load_documents, run_make, save_documents,
    studio_game_name,
)


def canonical_music_labels(labels: dict[str, int]) -> dict[str, int]:
    """Expose SMB2's role-prefixed music symbols through the shared engine model."""
    if "off_smb2_main_music_header_offsets" not in labels:
        return labels
    result = dict(labels)
    result.update({
        "tbl_music_header_offsets": labels["off_smb2_main_music_header_offsets"],
        "tbl_music_note_periods": labels["tbl_smb2_main_music_note_periods"],
        "tbl_music_note_lengths": labels["tbl_smb2_main_music_note_lengths"],
        "tbl_castle_clear_music_envelope": labels[
            "off_smb2_main_castle_clear_music_envelope"
        ],
    })
    for name, address in labels.items():
        header_prefix = "tbl_smb2_main_music_header_"
        stream_prefix = "off_smb2_main_music_stream_"
        if name.startswith(header_prefix):
            suffix = name.removeprefix(header_prefix)
            canonical = (
                "unused_music_header_residual"
                if suffix == "residual"
                else f"off_music_header_{suffix}"
            )
            result[canonical] = address
        elif name.startswith(stream_prefix):
            result[f"off_music_stream_{name.removeprefix(stream_prefix)}"] = address
    return result


class SoundStudio(tk.Tk):
    def __init__(
        self,
        documents: dict,
        banks: list[tuple[str, MusicBank]],
        project_root: Path,
        preview: Path,
        profile_id: str = "ju",
    ) -> None:
        super().__init__()
        self.documents = documents
        self.banks = banks
        self.bank_name = tk.StringVar(value=banks[0][0])
        self.model = banks[0][1]
        self.project_root = project_root
        self.profile_id = profile_id
        self.preview_path = preview
        self.song_label = tk.StringVar(value=self.model.header_labels[0])
        self.channel_name = tk.StringVar()
        self.channel_enabled = {
            name: tk.BooleanVar(value=True)
            for name in ("square2", "square1", "triangle", "noise", "wave")
        }
        self.raw_value = tk.IntVar()
        self.status = tk.StringVar()
        self.compositions = self.model.compositions()
        self.current_composition = self.compositions[0]
        self.current_song = self.current_composition["patterns"][0]
        self.current_channel = self.current_song["channels"][0]
        self.game_name = studio_game_name(profile_id)
        self.title(f"{self.game_name} Sound Studio [{profile_id}]")
        self.geometry("1240x790")
        self.protocol("WM_DELETE_WINDOW", self.close)
        self.build_ui()
        self.select_song()

    def build_ui(self) -> None:
        toolbar = ttk.Frame(self, padding=7)
        toolbar.pack(fill="x")
        ttk.Label(toolbar, text="Bank").pack(side="left")
        self.bank_box = ttk.Combobox(
            toolbar,
            state="readonly",
            width=18,
            textvariable=self.bank_name,
            values=[name for name, _model in self.banks],
        )
        self.bank_box.current(0)
        self.bank_box.pack(side="left", padx=5)
        self.bank_box.bind("<<ComboboxSelected>>", lambda _event: self.select_bank())
        ttk.Label(toolbar, text="Song").pack(side="left")
        self.song_box = ttk.Combobox(
            toolbar, state="readonly", width=32,
            values=[composition["name"] for composition in self.compositions],
        )
        self.song_box.current(0)
        self.song_box.pack(side="left", padx=5)
        self.song_box.bind("<<ComboboxSelected>>", lambda _event: self.select_song())
        for text, command in (
            ("Preview pattern", self.preview_pattern),
            ("Preview full song", self.preview_composition),
            ("Undo", self.undo), ("Save", self.save),
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
        music = ttk.Frame(notebook, padding=6)
        envelope = ttk.Frame(notebook, padding=6)
        notebook.add(music, text="Music sequencer")
        notebook.add(envelope, text="Swim/stomp envelope")
        self.build_music(music)
        self.build_envelope(envelope)
        if any(isinstance(model, AnnFdsMusicBank) for _name, model in self.banks):
            synthesis = ttk.Frame(notebook, padding=6)
            notebook.add(synthesis, text="FDS synthesis")
            self.build_fds_synthesis(synthesis)
        ttk.Label(self, textvariable=self.status, anchor="w", padding=7).pack(fill="x")

    def build_music(self, parent: ttk.Frame) -> None:
        channels = ttk.Frame(parent)
        channels.pack(fill="x")
        ttk.Label(channels, text="Pattern").pack(side="left")
        self.pattern_box = ttk.Combobox(channels, state="readonly", width=27)
        self.pattern_box.pack(side="left", padx=5)
        self.pattern_box.bind("<<ComboboxSelected>>", lambda _event: self.select_pattern())
        ttk.Label(channels, text="Channel").pack(side="left")
        self.channel_box = ttk.Combobox(channels, textvariable=self.channel_name, state="readonly", width=15)
        self.channel_box.pack(side="left", padx=5)
        self.channel_box.bind("<<ComboboxSelected>>", lambda _event: self.select_channel())
        mixer = ttk.LabelFrame(parent, text="Preview channels", padding=5)
        mixer.pack(fill="x", pady=(6, 0))
        for name, label in (
            ("square2", "Square 2"),
            ("square1", "Square 1"),
            ("triangle", "Triangle"),
            ("noise", "Noise"),
            ("wave", "FDS wave"),
        ):
            ttk.Checkbutton(
                mixer,
                text=label,
                variable=self.channel_enabled[name],
            ).pack(side="left", padx=10)
        roll_frame = ttk.LabelFrame(parent, text="Piano roll (horizontal scale is NTSC frames)", padding=5)
        roll_frame.pack(fill="both", expand=True, pady=6)
        self.roll = tk.Canvas(roll_frame, bg="#111824", height=330)
        x_scroll = ttk.Scrollbar(roll_frame, orient="horizontal", command=self.roll.xview)
        self.roll.configure(xscrollcommand=x_scroll.set)
        self.roll.pack(fill="both", expand=True)
        x_scroll.pack(fill="x")
        lower = ttk.Panedwindow(parent, orient="horizontal")
        lower.pack(fill="both", expand=True)
        self.events = ttk.Treeview(lower, columns=("index", "address", "raw", "meaning"), show="headings")
        for name, heading, width in (
            ("index", "#", 45), ("address", "CPU", 75),
            ("raw", "Byte", 65), ("meaning", "Decoded event", 300),
        ):
            self.events.heading(name, text=heading)
            self.events.column(name, width=width, stretch=name == "meaning")
        self.events.bind("<<TreeviewSelect>>", self.select_event)
        lower.add(self.events, weight=4)
        editor = ttk.LabelFrame(lower, text="Selected event", padding=10)
        lower.add(editor, weight=1)
        ttk.Label(editor, text="Raw engine byte").grid(row=0, column=0, sticky="w")
        ttk.Spinbox(editor, from_=0, to=255, textvariable=self.raw_value, width=8).grid(row=0, column=1, padx=5)
        ttk.Button(editor, text="Apply byte", command=self.apply_event).grid(
            row=1, column=0, columnspan=2, sticky="ew", pady=6
        )
        ttk.Label(
            editor,
            text="The decoded column shows notes, rests, duration changes, and noise beats. Byte count and channel offsets stay fixed, so every save remains safe for the original engine.",
            wraplength=250,
        ).grid(row=2, column=0, columnspan=2, sticky="w", pady=8)

    def build_envelope(self, parent: ttk.Frame) -> None:
        self.envelope_canvas = tk.Canvas(parent, width=900, height=360, bg="#111824")
        self.envelope_canvas.pack(fill="x", pady=8)
        self.envelope_index = tk.IntVar(value=0)
        self.envelope_volume = tk.IntVar(value=0)
        controls = ttk.Frame(parent)
        controls.pack()
        ttk.Label(controls, text="Step").grid(row=0, column=0)
        step = ttk.Spinbox(controls, from_=0, to=self.envelope_length() - 1,
                           textvariable=self.envelope_index, width=6, command=self.load_envelope_step)
        step.grid(row=0, column=1, padx=5)
        ttk.Label(controls, text="Volume 0-15").grid(row=0, column=2)
        ttk.Spinbox(controls, from_=0, to=15, textvariable=self.envelope_volume, width=6).grid(row=0, column=3, padx=5)
        ttk.Button(controls, text="Apply volume", command=self.apply_envelope).grid(row=0, column=4, padx=8)
        self.load_envelope_step()

    def build_fds_synthesis(self, parent: ttk.Frame) -> None:
        controls = ttk.Frame(parent)
        controls.pack(fill="x")
        self.fds_wave_id = tk.IntVar(value=1)
        self.fds_sample_index = tk.IntVar(value=0)
        self.fds_sample_value = tk.IntVar(value=0)
        ttk.Label(controls, text="Wave").pack(side="left")
        wave_box = ttk.Combobox(
            controls,
            state="readonly",
            width=12,
            values=("FDS wave 1", "FDS wave 2"),
        )
        wave_box.current(0)
        wave_box.pack(side="left", padx=5)
        wave_box.bind(
            "<<ComboboxSelected>>",
            lambda _event: (
                self.fds_wave_id.set(wave_box.current() + 1),
                self.refresh_fds_synthesis(),
            ),
        )
        ttk.Label(controls, text="Sample").pack(side="left")
        ttk.Spinbox(
            controls,
            from_=0,
            to=31,
            width=5,
            textvariable=self.fds_sample_index,
            command=self.load_fds_sample,
        ).pack(side="left", padx=4)
        ttk.Label(controls, text="Level 0-63").pack(side="left")
        ttk.Spinbox(
            controls,
            from_=0,
            to=63,
            width=5,
            textvariable=self.fds_sample_value,
        ).pack(side="left", padx=4)
        ttk.Button(
            controls, text="Apply sample", command=self.apply_fds_sample
        ).pack(side="left", padx=6)
        self.fds_wave_canvas = tk.Canvas(parent, height=260, bg="#111824")
        self.fds_wave_canvas.pack(fill="x", pady=8)
        envelope_frame = ttk.LabelFrame(parent, text="FDS volume program", padding=6)
        envelope_frame.pack(fill="both", expand=True)
        self.fds_volume_tree = ttk.Treeview(
            envelope_frame,
            columns=("step", "mode", "value", "frames"),
            show="headings",
            height=7,
        )
        for column, title, width in (
            ("step", "Step", 60),
            ("mode", "Mode", 120),
            ("value", "Value", 80),
            ("frames", "Frames", 80),
        ):
            self.fds_volume_tree.heading(column, text=title)
            self.fds_volume_tree.column(column, width=width)
        self.fds_volume_tree.pack(side="left", fill="both", expand=True)
        self.fds_volume_tree.bind(
            "<<TreeviewSelect>>", lambda _event: self.load_fds_volume_step()
        )
        editor = ttk.Frame(envelope_frame, padding=8)
        editor.pack(side="left", fill="y")
        self.fds_volume_mode = tk.StringVar(value="direct")
        self.fds_volume_value = tk.IntVar(value=0)
        self.fds_volume_frames = tk.IntVar(value=1)
        for row, (label, widget) in enumerate((
            ("Mode", ttk.Combobox(
                editor,
                state="readonly",
                width=10,
                textvariable=self.fds_volume_mode,
                values=("direct", "increase", "decrease"),
            )),
            ("Value", ttk.Spinbox(
                editor, from_=0, to=63, width=8,
                textvariable=self.fds_volume_value,
            )),
            ("Frames", ttk.Spinbox(
                editor, from_=1, to=255, width=8,
                textvariable=self.fds_volume_frames,
            )),
        )):
            ttk.Label(editor, text=label).grid(row=row, column=0, sticky="w")
            widget.grid(row=row, column=1, padx=4, pady=2)
        ttk.Button(
            editor, text="Apply step", command=self.apply_fds_volume_step
        ).grid(row=3, column=0, columnspan=2, sticky="ew", pady=8)
        ttk.Label(
            editor,
            text=(
                "The 32 stored samples are mirrored by the game into the "
                "64-sample FDS wave RAM. Volume steps preserve the engine's "
                "register mode and fixed byte count."
            ),
            wraplength=260,
        ).grid(row=4, column=0, columnspan=2, sticky="w")
        self.refresh_fds_synthesis()

    def ann_model(self) -> AnnFdsMusicBank:
        for _name, model in self.banks:
            if isinstance(model, AnnFdsMusicBank):
                return model
        raise ValueError("This profile has no FDS synthesis bank")

    def refresh_fds_synthesis(self) -> None:
        if not hasattr(self, "fds_wave_canvas"):
            return
        model = self.ann_model()
        waveform = model.waveform(int(self.fds_wave_id.get()))["samples"]
        self.fds_wave_canvas.delete("all")
        width = max(1, self.fds_wave_canvas.winfo_width())
        x_step = max(12, (width - 20) / len(waveform))
        points = []
        for index, value in enumerate(waveform):
            x = 10 + (index + 0.5) * x_step
            y = 240 - value * 3.5
            points.extend((x, y))
            self.fds_wave_canvas.create_line(x, 240, x, y, fill="#37536d")
        self.fds_wave_canvas.create_line(*points, fill="#65c4ff", width=2)
        self.fds_volume_tree.delete(*self.fds_volume_tree.get_children())
        for step in model.volume_envelope(int(self.fds_wave_id.get())):
            self.fds_volume_tree.insert(
                "",
                "end",
                iid=str(step["step"]),
                values=(step["step"], step["mode"], step["value"], step["frames"]),
            )
        self.load_fds_sample()
        if self.fds_volume_tree.get_children():
            self.fds_volume_tree.selection_set(self.fds_volume_tree.get_children()[0])
            self.load_fds_volume_step()

    def load_fds_sample(self) -> None:
        index = max(0, min(31, int(self.fds_sample_index.get())))
        self.fds_sample_index.set(index)
        self.fds_sample_value.set(
            self.ann_model().waveform(int(self.fds_wave_id.get()))["samples"][index]
        )

    def apply_fds_sample(self) -> None:
        def action() -> None:
            self.ann_model().set_wave_sample(
                int(self.fds_wave_id.get()),
                int(self.fds_sample_index.get()),
                int(self.fds_sample_value.get()),
            )
            self.refresh_fds_synthesis()
            if isinstance(self.model, AnnFdsMusicBank):
                self.refresh_music()
        guard("Sound Studio", action)

    def load_fds_volume_step(self) -> None:
        if not self.fds_volume_tree.selection():
            return
        step = int(self.fds_volume_tree.selection()[0])
        value = self.ann_model().volume_envelope(int(self.fds_wave_id.get()))[step]
        self.fds_volume_mode.set(str(value["mode"]))
        self.fds_volume_value.set(int(value["value"]))
        self.fds_volume_frames.set(int(value["frames"]))

    def apply_fds_volume_step(self) -> None:
        if not self.fds_volume_tree.selection():
            return
        step = int(self.fds_volume_tree.selection()[0])

        def action() -> None:
            self.ann_model().set_volume_step(
                int(self.fds_wave_id.get()),
                step,
                self.fds_volume_mode.get(),
                int(self.fds_volume_value.get()),
                int(self.fds_volume_frames.get()),
            )
            self.refresh_fds_synthesis()
            if isinstance(self.model, AnnFdsMusicBank):
                self.refresh_music()
        guard("Sound Studio", action)

    def envelope_steps(self) -> list[dict]:
        return self.documents["swim_stomp_envelope"].document["data"]["steps"]

    def envelope_length(self) -> int:
        return len(self.envelope_steps())

    def select_song(self) -> None:
        self.current_composition = self.compositions[self.song_box.current()]
        self.pattern_box.configure(values=[
            f"{index + 1:02d}: {pattern['name']}"
            for index, pattern in enumerate(self.current_composition["patterns"])
        ])
        self.pattern_box.current(0)
        self.select_pattern()

    def select_bank(self) -> None:
        self.model = dict(self.banks)[self.bank_name.get()]
        self.compositions = self.model.compositions()
        self.song_box.configure(
            values=[composition["name"] for composition in self.compositions]
        )
        self.song_box.current(0)
        self.select_song()

    def select_pattern(self) -> None:
        self.current_song = self.current_composition["patterns"][self.pattern_box.current()]
        self.song_label.set(self.current_song["label"])
        names = [channel["name"] for channel in self.current_song["channels"]]
        self.channel_box.configure(values=names)
        self.channel_box.current(0)
        self.select_channel()

    def select_channel(self) -> None:
        name = self.channel_box.get()
        self.current_channel = next(channel for channel in self.current_song["channels"] if channel["name"] == name)
        self.refresh_music()

    def refresh_music(self) -> None:
        self.current_song = self.model.song(
            self.song_label.get(),
            self.current_song.get("length_adder", 0),
            self.current_song.get("event_music", 0),
            self.current_song.get("area_music", 0),
        )
        self.current_composition["patterns"][self.pattern_box.current()] = self.current_song
        name = self.channel_box.get()
        self.current_channel = next(channel for channel in self.current_song["channels"] if channel["name"] == name)
        self.events.delete(*self.events.get_children())
        for index, byte in enumerate(self.current_channel["bytes"]):
            address = self.current_channel["start"] + index
            meaning = self.model.describe_byte(
                name,
                byte,
                self.current_song["length_offset"],
                self.current_song.get("length_adder", 0),
            )
            self.events.insert("", "end", iid=str(index), values=(index, f"${address:04X}", f"${byte:02X}", meaning))
        self.draw_roll()
        total = sum(frames for _frequency, frames in self.model.note_events(self.current_song, self.current_channel))
        self.status.set(
            f"{self.bank_name.get()} / {self.current_composition['name']} / "
            f"pattern {self.pattern_box.current() + 1} / {name}: "
            f"{len(self.current_channel['bytes'])} bytes, "
            f"{total} frames | {'unsaved edits' if dirty(self.documents) else 'saved'}"
        )
        self.title(
            f"{self.game_name} Sound Studio [{self.profile_id}]"
            + (" *" if dirty(self.documents) else "")
        )

    def draw_roll(self) -> None:
        self.roll.delete("all")
        events = self.model.note_events(self.current_song, self.current_channel)
        frequencies = [frequency for frequency, _duration in events if frequency > 0]
        if not frequencies:
            self.roll.create_text(20, 20, text="This channel contains commands or noise rather than pitched notes",
                                  fill="#b7c7d6", anchor="nw")
            return
        midi_values = [round(69 + 12 * __import__("math").log2(value / 440)) for value in frequencies]
        low, high = min(midi_values) - 1, max(midi_values) + 1
        row_height, frame_width, x = 18, 4, 65
        for midi in range(low, high + 1):
            y = 10 + (high - midi) * row_height
            self.roll.create_line(0, y + row_height, 100000, y + row_height, fill="#344150")
            self.roll.create_text(5, y + 8, text=str(midi), fill="#98aabd", anchor="w")
        for frequency, duration in events:
            width = max(3, duration * frame_width)
            if frequency > 0:
                midi = round(69 + 12 * __import__("math").log2(frequency / 440))
                y = 10 + (high - midi) * row_height + 2
                self.roll.create_rectangle(x, y, x + width, y + row_height - 3,
                                           fill="#54a7e8", outline="#d8efff")
            x += width
        self.roll.configure(scrollregion=(0, 0, max(900, x + 20), (high - low + 2) * row_height + 20))

    def select_event(self, _event: object = None) -> None:
        if self.events.selection():
            index = int(self.events.selection()[0])
            self.raw_value.set(self.current_channel["bytes"][index])

    def apply_event(self) -> None:
        if not self.events.selection():
            return
        index = int(self.events.selection()[0])
        address = self.current_channel["start"] + index
        guard("Sound Studio", lambda: self._apply_event(address, int(self.raw_value.get()), index))

    def _apply_event(self, address: int, value: int, selected: int) -> None:
        if not 0 <= value <= 255:
            raise ValueError("Music byte must be in range 0..255")
        self.model.set_byte(address, value)
        self.model.document.validate()
        self.refresh_music()
        self.events.selection_set(str(selected))

    def draw_envelope(self) -> None:
        self.envelope_canvas.delete("all")
        steps = self.envelope_steps()
        width = max(12, 880 // len(steps))
        for index, step in enumerate(steps):
            volume = int(step["volume"])
            x = 10 + index * width
            y = 330 - volume * 19
            color = "#ffe066" if index == self.envelope_index.get() else "#69b3e7"
            self.envelope_canvas.create_rectangle(x, y, x + width - 2, 330, fill=color, outline="")
            if index % 4 == 0:
                self.envelope_canvas.create_text(x, 342, text=str(index), fill="#aab8c5", anchor="n")

    def load_envelope_step(self) -> None:
        index = max(0, min(int(self.envelope_index.get()), self.envelope_length() - 1))
        self.envelope_index.set(index)
        self.envelope_volume.set(self.envelope_steps()[index]["volume"])
        if hasattr(self, "envelope_canvas"):
            self.draw_envelope()

    def apply_envelope(self) -> None:
        document = self.documents["swim_stomp_envelope"]
        index, volume = int(self.envelope_index.get()), int(self.envelope_volume.get())
        if not 0 <= volume <= 15:
            messagebox.showerror("Sound Studio", "Envelope volume must be in range 0..15")
            return
        if document.document["data"]["steps"][index]["volume"] != volume:
            steps = document.document["data"]["steps"]
            guard("Sound Studio", lambda: (
                change_document(document, lambda: steps[index].__setitem__("volume", volume)),
                self.draw_envelope(),
            ))

    def _preview(self, patterns: list[dict], description: str) -> None:
        def action() -> None:
            enabled = {
                name for name, variable in self.channel_enabled.items() if variable.get()
            }
            path = self.model.write_preview(
                patterns,
                self.preview_path,
                enabled_channels=enabled,
            )
            if sys.platform == "win32":
                import winsound
                winsound.PlaySound(str(path), winsound.SND_FILENAME | winsound.SND_ASYNC)
            seconds = sum(pattern["frames"] for pattern in patterns) / 60.0988
            channels = ", ".join(sorted(enabled)) if enabled else "muted"
            self.status.set(
                f"{description}: {seconds:.1f} s, channels: {channels} | {path}"
            )
        guard("Sound Studio", action)

    def preview_pattern(self) -> None:
        self._preview([self.current_song], "Pattern preview")

    def preview_composition(self) -> None:
        self._preview(self.current_composition["patterns"], "Full-song preview")

    def undo(self) -> None:
        if not self.model.document.undo():
            for document in self.documents.values():
                if document is not self.model.document and document.undo():
                    break
        self.refresh_music()
        self.load_envelope_step()
        self.refresh_fds_synthesis()

    def save(self) -> None:
        guard("Sound Studio", lambda: (save_documents(self.documents), self.refresh_music()))

    def close(self) -> None:
        if dirty(self.documents) and not messagebox.askyesno("Unsaved edits", "Discard unsaved sound edits?"):
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
    parser.add_argument("--prg", required=True, type=Path)
    parser.add_argument("--load-address", type=lambda value: int(value, 0), default=0x8000)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--smoke-ui", action="store_true")
    args = parser.parse_args()
    documents, labels = load_documents(
        args.formats,
        args.studios,
        args.labels,
        args.profiles,
        args.content_prg,
        args.content_chr,
        args.content_payload,
        args.content_payload_labels,
        args.workspace,
        "sound",
        args.profile,
    )
    labels = canonical_music_labels(labels)
    main_model = MusicBank(
        documents["music_bank"],
        labels,
        args.prg.read_bytes(),
        load_address=args.load_address,
    )
    banks: list[tuple[str, MusicBank]] = [("Main game", main_model)]
    fds_artifact = next(
        (
            artifact_id
            for artifact_id in ("ann_fds_music_bank", "smb2_fds_music_bank")
            if artifact_id in documents
        ),
        None,
    )
    if fds_artifact is not None:
        banks.append((
            "FDS ending",
            AnnFdsMusicBank(
                documents[fds_artifact],
                labels,
                args.prg.read_bytes(),
                load_address=args.load_address,
            ),
        ))
    for document in documents.values():
        document.validate()
    if args.check:
        songs = sum(len(model.songs()) for _name, model in banks)
        compositions = sum(len(model.compositions()) for _name, model in banks)
        channels = sum(
            len(song["channels"])
            for _name, model in banks
            for song in model.songs()
        )
        for _name, model in banks:
            if isinstance(model, AnnFdsMusicBank):
                preview_pcm = b"".join(
                    model.render_pattern(pattern, sample_rate=3000)
                    for pattern in model.compositions()[0]["patterns"]
                )
                if not any(preview_pcm):
                    raise ValueError("ANN FDS preview renderer produced silence")
        print(
            f"[OK] Sound Studio: {compositions} compositions across {len(banks)} "
            f"bank(s), {songs} headers, and {channels} active channel views"
        )
        return 0
    preview = args.workspace / "sound" / "preview.wav"
    application = SoundStudio(
        documents, banks, args.project_root, preview, args.profile
    )
    if args.smoke_ui:
        application.update_idletasks()
        application.destroy()
        print("[OK] Sound Studio widgets constructed")
    else:
        application.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
