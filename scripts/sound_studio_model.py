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
LENGTH_COUNTER_TABLE = (
    10, 254, 20, 2, 40, 4, 80, 6,
    160, 8, 60, 10, 14, 12, 26, 14,
    12, 16, 24, 18, 48, 20, 96, 22,
    192, 24, 72, 26, 16, 28, 32, 30,
)
NOISE_REGISTER_SETTINGS = {
    "short": (0x03, 0x18),
    "strong": (0x0C, 0x18),
    "long": (0x03, 0x58),
}
DUTY_SEQUENCES = (
    (0, 1, 0, 0, 0, 0, 0, 0),
    (0, 1, 1, 0, 0, 0, 0, 0),
    (0, 1, 1, 1, 1, 0, 0, 0),
    (1, 0, 0, 1, 1, 1, 1, 1),
)


HEADER_NAMES = {
    "off_music_header_vs_star_a": "Vs. Starman A",
    "off_music_header_vs_star_b": "Vs. Starman B",
    "off_music_header_vs_star_c": "Vs. Starman C",
    "off_music_header_vs_star_d": "Vs. Starman D",
    "off_music_header_time_running_out": "Hurry Up!",
    "off_music_header_star_cloud": "Starman / Coin Heaven",
    "off_music_header_end_of_level": "Course Clear",
    "unused_music_header_residual": "Unused residual",
    "off_music_header_underground": "Underground",
    "off_music_header_silence": "Silence",
    "off_music_header_castle": "Castle",
    "off_music_header_victory": "Princess Rescued",
    "off_music_header_vs_game_over": "Vs. Game Over",
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


def available_header_labels(labels: dict[str, int]) -> list[str]:
    """Return only music headers emitted by the selected build profile."""
    return sorted(
        (label for label in HEADER_NAMES if label in labels),
        key=labels.__getitem__,
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


def apu_mix(pulse1: float, pulse2: float, triangle: float, noise: float, dmc: float) -> float:
    """Apply the measured NES nonlinear pulse and TND transfer curves."""
    pulse_sum = pulse1 + pulse2
    pulse_output = 0.0 if pulse_sum == 0 else 95.88 / ((8128.0 / pulse_sum) + 100.0)
    tnd_input = triangle / 8227.0 + noise / 12241.0 + dmc / 22638.0
    tnd_output = 0.0 if tnd_input == 0 else 159.79 / ((1.0 / tnd_input) + 100.0)
    return pulse_output + tnd_output


class ApuOutputFilter:
    """Approximate the three first-order filters after the NES DACs."""

    def __init__(self, sample_rate: int) -> None:
        self.high_pass_90 = self._high_pass_coefficient(90.0, sample_rate)
        self.high_pass_440 = self._high_pass_coefficient(440.0, sample_rate)
        self.low_pass_14000 = self._low_pass_coefficient(14_000.0, sample_rate)
        self.hp90_input = 0.0
        self.hp90_output = 0.0
        self.hp440_input = 0.0
        self.hp440_output = 0.0
        self.lp_output = 0.0

    @staticmethod
    def _high_pass_coefficient(cutoff: float, sample_rate: int) -> float:
        time_constant = 1.0 / (2.0 * math.pi * cutoff)
        interval = 1.0 / sample_rate
        return time_constant / (time_constant + interval)

    @staticmethod
    def _low_pass_coefficient(cutoff: float, sample_rate: int) -> float:
        time_constant = 1.0 / (2.0 * math.pi * cutoff)
        interval = 1.0 / sample_rate
        return interval / (time_constant + interval)

    def process(self, value: float) -> float:
        hp90 = self.high_pass_90 * (self.hp90_output + value - self.hp90_input)
        self.hp90_input = value
        self.hp90_output = hp90
        hp440 = self.high_pass_440 * (self.hp440_output + hp90 - self.hp440_input)
        self.hp440_input = hp90
        self.hp440_output = hp440
        self.lp_output += self.low_pass_14000 * (hp440 - self.lp_output)
        return self.lp_output

    def prime(self, value: float) -> None:
        """Start from the steady-state response to an existing DAC level."""
        self.hp90_input = value
        self.hp90_output = 0.0
        self.hp440_input = 0.0
        self.hp440_output = 0.0
        self.lp_output = 0.0


def midi_name(frequency: float) -> str:
    if frequency <= 0:
        return "rest"
    midi = round(69 + 12 * math.log2(frequency / 440.0))
    names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    return f"{names[midi % 12]}{midi // 12 - 1}"


class MusicBank:
    def __init__(
        self,
        document: ArtifactDocument,
        labels: dict[str, int],
        prg: bytes,
        load_address: int = 0x8000,
    ) -> None:
        self.document = document
        self.labels = labels
        self.prg = prg
        self.load_address = load_address
        self.base = labels["tbl_music_header_offsets"]
        self.end = labels["tbl_music_note_periods"]
        self.stream_addresses = sorted(
            {address for name, address in labels.items() if name.startswith("off_music_stream_")}
        )
        self.header_labels = available_header_labels(labels)
        self.period_bytes = self._prg_bytes("tbl_music_note_periods", 0x66)
        self.periods = decode_periods(self.period_bytes)
        self.lengths = self._lengths()
        self.envelope_bytes = self._prg_bytes("tbl_castle_clear_music_envelope", 53)
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
        offset = self.labels[label] - self.load_address
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
        return timer_frequency(self._period(note_byte), triangle)

    def _period(self, note_byte: int) -> int:
        table_offset = note_byte & 0x7F
        period_bytes = getattr(self, "period_bytes", None)
        if period_bytes is not None:
            if table_offset + 1 >= len(period_bytes):
                raise ValueError(
                    f"Music note offset ${table_offset:02X} is outside the period table"
                )
            return (period_bytes[table_offset] << 8) | period_bytes[table_offset + 1]
        period_index = table_offset // 2
        if table_offset % 2 or period_index >= len(self.periods):
            raise ValueError(f"Music note offset ${table_offset:02X} is outside the period table")
        return self.periods[period_index]

    def _decode_uncompressed(
        self,
        song: dict[str, Any],
        name: str,
        start: int,
        duration_limit: int | None,
    ) -> dict[str, Any]:
        address = start
        length_index = 0
        length_command = False
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
                length_command = True
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
                "period": self._period(byte),
                "frames": frames,
                "kind": "rest" if frequency == 0 else "note",
                "length_command": length_command,
            })
            length_command = False
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
                beat = ("rest", "short", "strong", "long")[pitch >> 4]
                period_register, length_register = NOISE_REGISTER_SETTINGS.get(beat, (0, 0))
                events.append({
                    "address": event_address,
                    "byte": byte,
                    "frequency": 0.0,
                    "frames": frames,
                    "kind": "noise",
                    "beat": beat,
                    "period_index": period_register & 0x0F,
                    "length_counter": LENGTH_COUNTER_TABLE[length_register >> 3] if length_register else 0,
                })
            else:
                frequency = self._frequency(pitch)
                events.append({
                    "address": event_address,
                    "byte": byte,
                    "frequency": frequency,
                    "period": self._period(pitch),
                    "frames": frames,
                    "kind": "rest" if frequency == 0 else "note",
                })
            elapsed += frames
        return {"name": name, "start": start, "end": address, "bytes": raw, "events": events, "frames": elapsed}

    def songs(self) -> list[dict[str, Any]]:
        return [self.song(label) for label in self.header_labels]

    def song(
        self,
        label: str,
        length_adder: int = 0,
        event_music: int = 0,
        area_music: int = 0,
    ) -> dict[str, Any]:
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
            "event_music": event_music,
            "area_music": area_music,
            "dmc_level": 0x30 if area_music & 0x03 else 0,
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
        if pointer_index < 8:
            event_music = 1 << pointer_index
            area_music = 0
        elif pointer_index < 16:
            event_music = 0
            area_music = 1 << (pointer_index - 8)
        else:
            event_music = 0
            area_music = 1
        return self.song(
            label,
            8 if pointer_index == 6 else 0,
            event_music,
            area_music,
        )

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

    def _pulse_control(self, song: dict[str, Any], age_samples: int, sample_rate: int) -> tuple[int, int]:
        event_music = int(song.get("event_music", 0))
        area_music = int(song.get("area_music", 0))
        if event_music & 0x91:
            quarter_ticks = int(age_samples * NTSC_FRAME_RATE * 4.0 / sample_rate)
            return 2, max(0, 15 - quarter_ticks // 3)
        age_frames = int(age_samples * NTSC_FRAME_RATE / sample_rate)
        if event_music & 0x08:
            base, selector = 0, 4
        elif area_music & 0x7D:
            base, selector = 4, 8
        else:
            base, selector = 12, 40
        # SMB decrements the selector and writes the software-envelope byte in
        # the same music-handler pass that starts the note. Index selector is
        # therefore never audible and would point one byte beyond the table.
        envelope_index = base + max(0, selector - 1 - age_frames)
        register = self.envelope_bytes[envelope_index]
        return (register >> 6) & 3, register & 0x0F

    def _render_pulse_channel(
        self,
        song: dict[str, Any],
        channel: dict[str, Any],
        total_samples: int,
        sample_rate: int,
    ) -> list[float]:
        output = [0.0] * total_samples
        frame_cursor = 0
        for event in channel["events"]:
            start = round(frame_cursor * sample_rate / NTSC_FRAME_RATE)
            frame_cursor += event["frames"]
            end = min(total_samples, round(frame_cursor * sample_rate / NTSC_FRAME_RATE))
            period = event["period"]
            if period < 8 or end <= start:
                continue
            phase = 0.0
            step = timer_frequency(period) / sample_rate
            for sample_index in range(start, end):
                position = sample_index - start
                duty, volume = self._pulse_control(song, position, sample_rate)
                sequence_index = int(phase * 8.0) % 8
                output[sample_index] = float(volume * DUTY_SEQUENCES[duty][sequence_index])
                phase = (phase + step) % 1.0
        return output

    def _render_triangle_channel(
        self,
        song: dict[str, Any],
        channel: dict[str, Any],
        total_samples: int,
        sample_rate: int,
    ) -> list[float]:
        output = [7.0] * total_samples
        frame_cursor = 0
        phase = 0.0
        held_value = 7.0
        control_register = 0
        for event in channel["events"]:
            start = round(frame_cursor * sample_rate / NTSC_FRAME_RATE)
            frame_cursor += event["frames"]
            end = min(total_samples, round(frame_cursor * sample_rate / NTSC_FRAME_RATE))
            period = event["period"]
            if event.get("length_command"):
                control_register = 0x1F
            if period == 0 or end <= start:
                for sample_index in range(start, end):
                    output[sample_index] = held_value
                continue
            event_music = int(song.get("event_music", 0))
            area_music = int(song.get("area_music", 0))
            if event_music & 0x6E or area_music & 0x0A:
                if event["frames"] >= 0x12:
                    control_register = 0xFF
                elif event_music & 0x08:
                    control_register = 0x0F
                else:
                    control_register = 0x1F
            if control_register & 0x80:
                gate_end = end
            else:
                gate_samples = round(
                    (control_register & 0x7F) * sample_rate / (NTSC_FRAME_RATE * 4.0)
                )
                gate_end = min(end, start + gate_samples)
            step = timer_frequency(period, triangle=True) / sample_rate
            for sample_index in range(start, gate_end):
                sequence_index = int(phase * 32.0) % 32
                held_value = float(15 - sequence_index if sequence_index < 16 else sequence_index - 16)
                output[sample_index] = held_value
                phase = (phase + step) % 1.0
            for sample_index in range(gate_end, end):
                output[sample_index] = held_value
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
            shift_rate = CPU_FREQUENCY / NOISE_PERIODS[event["period_index"]]
            gate_samples = round(
                event["length_counter"] * sample_rate / (NTSC_FRAME_RATE * 2.0)
            )
            gate_end = min(end, start + gate_samples)
            for sample_index in range(start, end):
                noise_phase += shift_rate / sample_rate
                while noise_phase >= 1.0:
                    feedback = (lfsr ^ (lfsr >> 1)) & 1
                    lfsr = (lfsr >> 1) | (feedback << 14)
                    noise_phase -= 1.0
                if beat != "rest" and sample_index < gate_end and lfsr & 1 == 0:
                    output[sample_index] = 12.0
            event_index = (event_index + 1) % len(events)
        return output

    def render_pattern(
        self,
        song: dict[str, Any],
        sample_rate: int = DEFAULT_SAMPLE_RATE,
        output_filter: ApuOutputFilter | None = None,
        enabled_channels: set[str] | None = None,
    ) -> bytes:
        if sample_rate <= 0:
            raise ValueError("Sample rate must be positive")
        total_frames = int(song["frames"])
        total_samples = max(1, round(total_frames * sample_rate / NTSC_FRAME_RATE))
        tracks = {}
        for channel in song["channels"]:
            if enabled_channels is not None and channel["name"] not in enabled_channels:
                continue
            if channel["name"] == "noise":
                tracks["noise"] = self._render_noise_channel(channel, total_frames, total_samples, sample_rate)
            elif channel["name"] == "triangle":
                tracks["triangle"] = self._render_triangle_channel(song, channel, total_samples, sample_rate)
            else:
                tracks[channel["name"]] = self._render_pulse_channel(
                    song, channel, total_samples, sample_rate
                )
        if output_filter is None:
            output_filter = ApuOutputFilter(sample_rate)
            output_filter.prime(self._initial_mixer_level(song, enabled_channels))
        silent = [0.0] * total_samples
        pulse1 = tracks.get("square1", silent)
        pulse2 = tracks.get("square2", silent)
        triangle = tracks.get("triangle", silent)
        noise = tracks.get("noise", silent)
        dmc = float(song.get("dmc_level", 0))
        pcm = bytearray()
        for index in range(total_samples):
            mixed = apu_mix(pulse1[index], pulse2[index], triangle[index], noise[index], dmc)
            filtered = output_filter.process(mixed)
            sample = max(-1.0, min(1.0, filtered * 2.8))
            pcm.extend(struct.pack("<h", round(sample * 32767)))
        return bytes(pcm)

    @staticmethod
    def _initial_mixer_level(
        song: dict[str, Any], enabled_channels: set[str] | None
    ) -> float:
        triangle_present = any(
            channel["name"] == "triangle" for channel in song["channels"]
        )
        triangle_enabled = enabled_channels is None or "triangle" in enabled_channels
        triangle = 7 if triangle_present and triangle_enabled else 0
        return apu_mix(0, 0, triangle, 0, float(song.get("dmc_level", 0)))

    def write_preview(
        self,
        patterns: list[dict[str, Any]],
        path: Path,
        sample_rate: int = DEFAULT_SAMPLE_RATE,
        enabled_channels: set[str] | None = None,
    ) -> Path:
        if not patterns:
            raise ValueError("A music preview must contain at least one pattern")
        pcm = bytearray()
        output_filter = ApuOutputFilter(sample_rate)
        first_pattern = patterns[0]
        output_filter.prime(self._initial_mixer_level(first_pattern, enabled_channels))
        for pattern in patterns:
            pcm.extend(
                self.render_pattern(
                    pattern,
                    sample_rate,
                    output_filter,
                    enabled_channels,
                )
            )
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(sample_rate)
            output.writeframes(bytes(pcm))
        return path
