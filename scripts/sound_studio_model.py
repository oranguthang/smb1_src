"""Parser and preview renderer for the complete vanilla SMB1 music bank."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path
from typing import Any

from content_studio_model import ArtifactDocument


HEADER_NAMES = {
    "off_music_header_time_running_out": "Hurry Up!",
    "off_music_header_star_cloud": "Starman / Coin Heaven",
    "off_music_header_end_of_level": "Course Clear",
    "unused_music_header_residual": "Unused residual",
    "off_music_header_underground": "Underground",
    "off_music_header_silence": "Silence",
    "off_music_header_castle": "Castle",
    "off_music_header_victory": "Princess Rescued",
    "off_music_header_game_over": "Game Over",
    "off_music_header_water": "Underwater",
    "off_music_header_castle_clear": "Castle Clear",
    "off_music_header_ground_part_1": "Ground part 1",
    "off_music_header_ground_part_2_a": "Ground part 2A",
    "off_music_header_ground_part_2_b": "Ground part 2B",
    "off_music_header_ground_part_2_c": "Ground part 2C",
    "off_music_header_ground_part_3_a": "Ground part 3A",
    "off_music_header_ground_part_3_b": "Ground part 3B",
    "off_music_header_ground_lead_in": "Ground lead-in",
    "off_music_header_ground_part_4_a": "Ground part 4A",
    "off_music_header_ground_part_4_b": "Ground part 4B",
    "off_music_header_ground_part_4_c": "Ground part 4C",
    "off_music_header_death": "Mario Dies",
}


def midi_name(frequency: float) -> str:
    if frequency <= 0:
        return "rest"
    midi = round(69 + 12 * math.log2(frequency / 440.0))
    names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    return f"{names[midi % 12]}{midi // 12 - 1}"


class MusicBank:
    def __init__(self, document: ArtifactDocument, labels: dict[str, int], prg: bytes) -> None:
        self.document = document
        self.labels = labels
        self.prg = prg
        self.base = labels["tbl_music_header_offsets"]
        self.end = labels["tbl_music_note_periods"]
        self.stream_addresses = sorted(
            {address for name, address in labels.items() if name.startswith("off_music_stream_")}
        )
        self.header_labels = sorted(HEADER_NAMES, key=labels.__getitem__)
        self.periods = self._periods()
        self.lengths = self._lengths()

    @property
    def values(self) -> list[int]:
        return self.document.document["data"]["values"]

    def byte(self, address: int) -> int:
        return int(self.values[address - self.base])

    def set_byte(self, address: int, value: int) -> None:
        if not self.base <= address < self.end:
            raise ValueError("Music edit address is outside the authored music bank")
        index = address - self.base
        if self.values[index] != value:
            self.document._remember()
            self.values[index] = value

    def _prg_bytes(self, label: str, length: int) -> bytes:
        offset = self.labels[label] - 0x8000
        return self.prg[offset:offset + length]

    def _periods(self) -> list[int]:
        raw = self._prg_bytes("tbl_music_note_periods", 0x66)
        return [raw[index] | (raw[index + 1] << 8) for index in range(0, len(raw), 2)]

    def _lengths(self) -> list[int]:
        return list(self._prg_bytes("tbl_music_note_lengths", 48))

    def songs(self) -> list[dict[str, Any]]:
        return [self.song(label) for label in self.header_labels]

    def song(self, label: str) -> dict[str, Any]:
        address = self.labels[label]
        following = [self.labels[item] for item in self.header_labels if self.labels[item] > address]
        following.extend(value for value in self.stream_addresses if value > address)
        header_end = min(following)
        header = [self.byte(pointer) for pointer in range(address, header_end)]
        if len(header) not in {4, 5, 6}:
            raise ValueError(f"{label} has unsupported {len(header)}-byte header")
        data_address = header[1] | (header[2] << 8)
        stream_end = min([value for value in self.stream_addresses if value > data_address] + [self.end])
        starts = {"square2": 0}
        if header[3]:
            starts["triangle"] = header[3]
        if len(header) >= 5 and header[4]:
            starts["square1"] = header[4]
        if len(header) == 6 and header[5]:
            starts["noise"] = header[5]
        ordered = sorted(starts.items(), key=lambda item: item[1])
        channels = []
        for index, (name, relative) in enumerate(ordered):
            end = data_address + (ordered[index + 1][1] if index + 1 < len(ordered) else stream_end - data_address)
            channels.append({
                "name": name,
                "start": data_address + relative,
                "end": end,
                "bytes": [self.byte(pointer) for pointer in range(data_address + relative, end)],
            })
        if label == "off_music_header_underground":
            channels.append({
                "name": "triangle",
                "start": data_address,
                "end": stream_end,
                "bytes": [self.byte(pointer) for pointer in range(data_address, stream_end)],
            })
        return {
            "label": label,
            "name": HEADER_NAMES[label],
            "address": address,
            "length_offset": header[0],
            "data_address": data_address,
            "channels": channels,
        }

    def describe_byte(self, channel: str, byte: int, length_offset: int) -> str:
        if channel in {"square2", "triangle"}:
            if byte == 0:
                return "terminator" if channel == "square2" else "rest"
            if byte & 0x80:
                index = byte & 7
                return f"length {index}: {self.lengths[(length_offset + index) % len(self.lengths)]} frames"
            period_index = (byte & 0x7F) // 2
        elif channel == "square1":
            if byte == 0:
                return "control-register reload"
            period_index = (byte >> 1) & 0x1F
        else:
            beat = ("rest", "short beat", "strong beat", "long beat")[(byte >> 4) & 3]
            length_index = ((byte & 1) << 2) | (byte >> 6)
            return f"{beat}, length {length_index}"
        if period_index >= len(self.periods):
            return f"note index {period_index}"
        frequency = 1_789_773 / (16 * (self.periods[period_index] + 1))
        return f"{midi_name(frequency)} ({frequency:.1f} Hz)"

    def note_events(self, song: dict[str, Any], channel: dict[str, Any]) -> list[tuple[float, int]]:
        length_index = 0
        events = []
        for byte in channel["bytes"]:
            if channel["name"] in {"square2", "triangle"}:
                if byte == 0 and channel["name"] == "square2":
                    break
                if byte & 0x80:
                    length_index = byte & 7
                    continue
                duration = self.lengths[(song["length_offset"] + length_index) % len(self.lengths)]
                if byte == 0:
                    events.append((0.0, duration))
                else:
                    period = self.periods[(byte & 0x7F) // 2]
                    divisor = 32 if channel["name"] == "triangle" else 16
                    events.append((1_789_773 / (divisor * (period + 1)), duration))
            elif channel["name"] == "square1":
                index = ((byte & 1) << 2) | (byte >> 6)
                duration = self.lengths[(song["length_offset"] + index) % len(self.lengths)]
                if byte == 0:
                    events.append((0.0, duration))
                else:
                    period = self.periods[(byte >> 1) & 0x1F]
                    events.append((1_789_773 / (16 * (period + 1)), duration))
        return events

    def write_preview(self, song: dict[str, Any], path: Path, sample_rate: int = 22050) -> Path:
        tracks = []
        for channel in song["channels"]:
            if channel["name"] == "noise":
                continue
            samples = []
            phase = 0.0
            for frequency, frames in self.note_events(song, channel):
                count = max(1, round(frames * sample_rate / 60))
                for _index in range(count):
                    if frequency <= 0:
                        samples.append(0.0)
                    else:
                        phase = (phase + frequency / sample_rate) % 1.0
                        value = (2 * abs(2 * phase - 1) - 1) if channel["name"] == "triangle" else (1 if phase < 0.5 else -1)
                        samples.append(value * 0.18)
            tracks.append(samples)
        length = max((len(track) for track in tracks), default=1)
        pcm = bytearray()
        for index in range(length):
            value = sum(track[index] if index < len(track) else 0.0 for track in tracks)
            pcm.extend(struct.pack("<h", max(-32768, min(32767, int(value * 32767)))))
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(sample_rate)
            output.writeframes(bytes(pcm))
        return path
