"""Parser and preview renderer for the complete vanilla SMB1 music bank."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path
from typing import Any

from content_studio_model import ArtifactDocument


CPU_FREQUENCY = 1_789_773.0
NTSC_FRAME_RATE = 60.0988
DEFAULT_SAMPLE_RATE = 44_100
MAX_CHANNEL_BYTES = 256
NOISE_PERIODS = (4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068)


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

COMPOSITION_SPECS = (
    ("Mario Dies", (0,)),
    ("Game Over", (1,)),
    ("Princess Rescued", (2,)),
    ("Castle Clear", (3,)),
    ("Course Clear", (5,)),
    ("Hurry Up!", (6,)),
    ("Silence", (7,)),
    ("Underwater", (9,)),
    ("Underground", (10,)),
    ("Castle", (11,)),
    ("Coin Heaven", (12,)),
    ("Pipe Cutscene", (13,)),
    ("Starman", (14,)),
    ("Overworld (complete)", tuple(range(16, 49))),
)


def decode_periods(raw: bytes) -> list[int]:
    """Decode the engine's high-byte, low-byte APU timer pairs."""
    if len(raw) % 2:
        raise ValueError("Music period table must contain complete byte pairs")
    return [(raw[index] << 8) | raw[index + 1] for index in range(0, len(raw), 2)]


def timer_frequency(period: int, triangle: bool = False) -> float:
    if period == 0:
        return 0.0
    divisor = 32 if triangle else 16
    return CPU_FREQUENCY / (divisor * (period + 1))


def _poly_blep(phase: float, step: float) -> float:
    if phase < step:
        value = phase / step
        return value + value - value * value - 1.0
    if phase > 1.0 - step:
        value = (phase - 1.0) / step
        return value * value + value + value + 1.0
    return 0.0


def _pulse_sample(phase: float, step: float) -> float:
    value = 1.0 if phase < 0.5 else -1.0
    value += _poly_blep(phase, step)
    value -= _poly_blep((phase + 0.5) % 1.0, step)
    return value


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
        self.header_by_offset = {
            labels[label] - self.base: label for label in self.header_labels
        }

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
        return decode_periods(raw)

    def _lengths(self) -> list[int]:
        return list(self._prg_bytes("tbl_music_note_lengths", 48))

    def _length(self, song: dict[str, Any], index: int) -> int:
        table_index = song["length_offset"] + song.get("length_adder", 0) + index
        if not 0 <= table_index < len(self.lengths):
            raise ValueError(f"Music length-table index {table_index} is outside the table")
        return self.lengths[table_index]

    def _frequency(self, note_byte: int, triangle: bool = False) -> float:
        table_offset = note_byte & 0x7F
        if table_offset % 2:
            raise ValueError(f"Music note offset ${table_offset:02X} must be even")
        period_index = table_offset // 2
        if period_index >= len(self.periods):
            raise ValueError(f"Music note offset ${table_offset:02X} is outside the period table")
        return timer_frequency(self.periods[period_index], triangle)

    def _decode_uncompressed(
        self,
        song: dict[str, Any],
        name: str,
        start: int,
        duration_limit: int | None,
    ) -> dict[str, Any]:
        address = start
        length_index = 0
        elapsed = 0
        raw = []
        events = []
        while len(raw) < MAX_CHANNEL_BYTES and address < self.end:
            byte = self.byte(address)
            raw.append(byte)
            event_address = address
            address += 1
            if byte == 0:
                break
            if byte & 0x80:
                length_index = byte & 7
                continue
            frames = self._length(song, length_index)
            if duration_limit is not None:
                frames = min(frames, max(0, duration_limit - elapsed))
            if frames <= 0:
                break
            frequency = self._frequency(byte, name == "triangle")
            events.append({
                "address": event_address,
                "byte": byte,
                "frequency": frequency,
                "frames": frames,
                "kind": "rest" if frequency == 0 else "note",
            })
            elapsed += frames
            if duration_limit is not None and elapsed >= duration_limit:
                break
        return {"name": name, "start": start, "end": address, "bytes": raw, "events": events, "frames": elapsed}

    def _decode_compressed(
        self,
        song: dict[str, Any],
        name: str,
        start: int,
        duration_limit: int,
    ) -> dict[str, Any]:
        address = start
        elapsed = 0
        raw = []
        events = []
        while len(raw) < MAX_CHANNEL_BYTES and address < self.end and elapsed < duration_limit:
            byte = self.byte(address)
            raw.append(byte)
            event_address = address
            address += 1
            if byte == 0:
                if name == "noise":
                    break
                continue
            length_index = ((byte & 1) << 2) | (byte >> 6)
            frames = min(self._length(song, length_index), duration_limit - elapsed)
            pitch = byte & 0x3E
            if name == "noise":
                events.append({
                    "address": event_address,
                    "byte": byte,
                    "frequency": 0.0,
                    "frames": frames,
                    "kind": "noise",
                    "beat": ("rest", "short", "strong", "long")[pitch >> 4],
                })
            else:
                frequency = self._frequency(pitch)
                events.append({
                    "address": event_address,
                    "byte": byte,
                    "frequency": frequency,
                    "frames": frames,
                    "kind": "rest" if frequency == 0 else "note",
                })
            elapsed += frames
        return {"name": name, "start": start, "end": address, "bytes": raw, "events": events, "frames": elapsed}

    def songs(self) -> list[dict[str, Any]]:
        return [self.song(label) for label in self.header_labels]

    def song(self, label: str, length_adder: int = 0) -> dict[str, Any]:
        address = self.labels[label]
        following = [self.labels[item] for item in self.header_labels if self.labels[item] > address]
        following.extend(value for value in self.stream_addresses if value > address)
        header_end = min(following)
        header = [self.byte(pointer) for pointer in range(address, header_end)]
        if len(header) not in {4, 5, 6}:
            raise ValueError(f"{label} has unsupported {len(header)}-byte header")
        data_address = header[1] | (header[2] << 8)
        song = {
            "label": label,
            "name": HEADER_NAMES[label],
            "address": address,
            "length_offset": header[0],
            "length_adder": length_adder,
            "data_address": data_address,
        }
        channels = [self._decode_uncompressed(song, "square2", data_address, None)]
        duration = channels[0]["frames"]
        if label == "off_music_header_underground":
            channels.append(self._decode_uncompressed(song, "triangle", data_address, duration))
        elif header[3]:
            channels.append(self._decode_uncompressed(song, "triangle", data_address + header[3], duration))
        if len(header) >= 5 and header[4]:
            channels.append(self._decode_compressed(song, "square1", data_address + header[4], duration))
        noise_headers = {
            "off_music_header_star_cloud",
            "off_music_header_water",
            "off_music_header_ground_part_1",
            "off_music_header_ground_part_2_a",
            "off_music_header_ground_part_2_b",
            "off_music_header_ground_part_2_c",
            "off_music_header_ground_part_3_a",
            "off_music_header_ground_part_3_b",
            "off_music_header_ground_lead_in",
            "off_music_header_ground_part_4_a",
            "off_music_header_ground_part_4_b",
            "off_music_header_ground_part_4_c",
        }
        if len(header) == 6 and header[5] and label in noise_headers:
            channels.append(self._decode_compressed(song, "noise", data_address + header[5], duration))
        song["channels"] = channels
        song["frames"] = duration
        return song

    def song_from_pointer(self, pointer_index: int) -> dict[str, Any]:
        header_offset = self.byte(self.base + pointer_index)
        try:
            label = self.header_by_offset[header_offset]
        except KeyError as error:
            raise ValueError(f"Music pointer {pointer_index} selects unknown header offset ${header_offset:02X}") from error
        return self.song(label, 8 if pointer_index == 6 else 0)

    def compositions(self) -> list[dict[str, Any]]:
        return [
            {
                "name": name,
                "pointer_indexes": indexes,
                "patterns": [self.song_from_pointer(index) for index in indexes],
            }
            for name, indexes in COMPOSITION_SPECS
        ]

    def describe_byte(self, channel: str, byte: int, length_offset: int, length_adder: int = 0) -> str:
        song = {"length_offset": length_offset, "length_adder": length_adder}
        if channel in {"square2", "triangle"}:
            if byte == 0:
                return "terminator"
            if byte & 0x80:
                index = byte & 7
                return f"length {index}: {self._length(song, index)} frames"
            frequency = self._frequency(byte, channel == "triangle")
        elif channel == "square1":
            if byte == 0:
                return "control-register reload"
            index = ((byte & 1) << 2) | (byte >> 6)
            frequency = self._frequency(byte & 0x3E)
            if frequency == 0:
                return f"rest, {self._length(song, index)} frames"
        else:
            if byte == 0:
                return "loop marker"
            beat = ("rest", "short beat", "strong beat", "long beat")[(byte & 0x3E) >> 4]
            index = ((byte & 1) << 2) | (byte >> 6)
            return f"{beat}, {self._length(song, index)} frames"
        if frequency == 0:
            return "rest"
        return f"{midi_name(frequency)} ({frequency:.1f} Hz)"

    def note_events(self, song: dict[str, Any], channel: dict[str, Any]) -> list[tuple[float, int]]:
        del song
        return [(float(event["frequency"]), int(event["frames"])) for event in channel["events"]]

    def _render_tonal_channel(self, channel: dict[str, Any], total_samples: int, sample_rate: int) -> list[float]:
        output = [0.0] * total_samples
        frame_cursor = 0
        is_triangle = channel["name"] == "triangle"
        amplitude = 0.23 if is_triangle else (0.18 if channel["name"] == "square1" else 0.20)
        for event in channel["events"]:
            start = round(frame_cursor * sample_rate / NTSC_FRAME_RATE)
            frame_cursor += event["frames"]
            end = min(total_samples, round(frame_cursor * sample_rate / NTSC_FRAME_RATE))
            frequency = event["frequency"]
            if frequency <= 0 or end <= start:
                continue
            phase = 0.0
            step = frequency / sample_rate
            edge = max(1, min(round(sample_rate * 0.002), (end - start) // 4))
            for sample_index in range(start, end):
                position = sample_index - start
                envelope = min(1.0, (position + 1) / edge, (end - sample_index) / edge)
                if is_triangle:
                    value = 1.0 - 4.0 * abs(phase - 0.5)
                else:
                    value = _pulse_sample(phase, step)
                output[sample_index] += value * amplitude * envelope
                phase = (phase + step) % 1.0
        return output

    def _render_noise_channel(
        self,
        channel: dict[str, Any],
        total_frames: int,
        total_samples: int,
        sample_rate: int,
    ) -> list[float]:
        output = [0.0] * total_samples
        events = channel["events"]
        if not events:
            return output
        frame_cursor = 0
        event_index = 0
        lfsr = 1
        noise_phase = 0.0
        while frame_cursor < total_frames:
            event = events[event_index]
            frames = min(event["frames"], total_frames - frame_cursor)
            start = round(frame_cursor * sample_rate / NTSC_FRAME_RATE)
            frame_cursor += frames
            end = min(total_samples, round(frame_cursor * sample_rate / NTSC_FRAME_RATE))
            beat = event["beat"]
            if beat != "rest":
                period_index = 12 if beat == "strong" else 3
                shift_rate = CPU_FREQUENCY / NOISE_PERIODS[period_index]
                amplitude = {"short": 0.035, "strong": 0.075, "long": 0.05}[beat]
                edge = max(1, min(round(sample_rate * 0.002), (end - start) // 4))
                for sample_index in range(start, end):
                    noise_phase += shift_rate / sample_rate
                    while noise_phase >= 1.0:
                        feedback = (lfsr ^ (lfsr >> 1)) & 1
                        lfsr = (lfsr >> 1) | (feedback << 14)
                        noise_phase -= 1.0
                    position = sample_index - start
                    envelope = min(1.0, (position + 1) / edge, (end - sample_index) / edge)
                    output[sample_index] += (1.0 if lfsr & 1 else -1.0) * amplitude * envelope
            event_index = (event_index + 1) % len(events)
        return output

    def render_pattern(self, song: dict[str, Any], sample_rate: int = DEFAULT_SAMPLE_RATE) -> bytes:
        if sample_rate <= 0:
            raise ValueError("Sample rate must be positive")
        total_frames = int(song["frames"])
        total_samples = max(1, round(total_frames * sample_rate / NTSC_FRAME_RATE))
        tracks = []
        for channel in song["channels"]:
            if channel["name"] == "noise":
                tracks.append(self._render_noise_channel(channel, total_frames, total_samples, sample_rate))
            else:
                tracks.append(self._render_tonal_channel(channel, total_samples, sample_rate))
        pcm = bytearray()
        for index in range(total_samples):
            mixed = sum(track[index] for track in tracks)
            softened = math.tanh(mixed * 1.15) * 0.82
            pcm.extend(struct.pack("<h", round(softened * 32767)))
        return bytes(pcm)

    def write_preview(
        self,
        patterns: list[dict[str, Any]],
        path: Path,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
    ) -> Path:
        if not patterns:
            raise ValueError("A music preview must contain at least one pattern")
        cache: dict[tuple[str, int], bytes] = {}
        pcm = bytearray()
        for pattern in patterns:
            key = (pattern["label"], pattern.get("length_adder", 0))
            if key not in cache:
                cache[key] = self.render_pattern(pattern, sample_rate)
            pcm.extend(cache[key])
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(sample_rate)
            output.writeframes(bytes(pcm))
        return path
