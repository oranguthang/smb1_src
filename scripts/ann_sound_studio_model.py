"""Semantic model and preview renderer for the FDS ending music engine."""

from __future__ import annotations

import struct
import wave
from pathlib import Path
from typing import Any

from content_studio_model import ArtifactDocument
from sound_studio_model import (
    ApuOutputFilter,
    CPU_FREQUENCY,
    DEFAULT_SAMPLE_RATE,
    LENGTH_COUNTER_TABLE,
    MusicBank,
    NOISE_PERIODS,
    NTSC_FRAME_RATE,
    apu_mix,
    midi_name,
    timer_frequency,
)


ANN_PATTERN_NAMES = (
    "Opening A",
    "Opening A repeat",
    "Opening B",
    "Opening A return",
    "Procession A",
    "Procession C",
    "Procession A repeat",
    "Procession C repeat",
    "Procession B",
    "Procession A finale",
    "Coda",
)
FDS_ENDING_SYMBOLS = {
    "ann_fds_music_bank": {
        "sequence": "tbl_ann_fds_music_offsets",
        "periods": "tbl_music_note_periods",
        "lengths": "tbl_ann_fds_note_lengths",
        "envelope": "tbl_ann_fds_envelope",
        "wave_notes": "tbl_ann_fds_wave_notes",
        "wave_a_volumes": "tbl_ann_fds_wave_a_volumes",
        "wave_offsets": "tbl_ann_fds_wave_offsets",
        "composition": "ANN ending suite",
        "pattern_prefix": "ann_fds_pattern_",
    },
    "smb2_fds_music_bank": {
        "sequence": "tbl_smb2_data3_music_header_offset_data",
        "periods": "tbl_smb2_main_music_note_periods",
        "lengths": "tbl_smb2_data3_music_note_lengths",
        "envelope": "off_smb2_data3_victory_music_envelope_data",
        "wave_notes": "tbl_smb2_data3_fds_freq_lookup_tbl",
        "wave_a_volumes": "off_smb2_data3_volume_envelope_data_1",
        "wave_offsets": "tbl_smb2_data3_waveform_header_offsets",
        "composition": "SMB2 ending suite",
        "pattern_prefix": "smb2_fds_pattern_",
    },
}
MAX_CHANNEL_BYTES = 256


def fds_wave_frequency(period: int) -> float:
    """Convert the FDS 12-bit phase increment to a 64-sample wave frequency."""
    return CPU_FREQUENCY * period / (65_536.0 * 64.0)


def _resolve_boundary(value: int | str, labels: dict[str, int]) -> int:
    """Resolve a numeric or symbol-owned artifact boundary."""
    return labels[value] if isinstance(value, str) else int(value)


class AnnFdsMusicBank(MusicBank):
    """Decode the ANN or SMB2 APU/FDS ending suite without canonical assumptions."""

    def __init__(
        self,
        document: ArtifactDocument,
        labels: dict[str, int],
        main_prg: bytes,
        load_address: int = 0x6000,
    ) -> None:
        self.document = document
        self.labels = labels
        self.prg = main_prg
        self.load_address = load_address
        try:
            self.symbols = FDS_ENDING_SYMBOLS[document.entry["id"]]
        except KeyError as exc:
            raise ValueError(
                f"unsupported FDS ending artifact: {document.entry['id']}"
            ) from exc
        self.base = labels[self.symbols["sequence"]]
        self.end = _resolve_boundary(document.entry["end"], labels)
        self.period_bytes = self._prg_bytes(self.symbols["periods"], 0x66)
        self.periods = []
        self.lengths = [
            self.byte(labels[self.symbols["lengths"]] + index)
            for index in range(16)
        ]
        envelope = labels[self.symbols["envelope"]]
        self.envelope_bytes = bytes(self.byte(envelope + index) for index in range(17))
        self.sequence_offsets = [self.byte(self.base + index) for index in range(11)]
        unique_offsets = list(dict.fromkeys(self.sequence_offsets))
        self.header_labels = [
            f"{self.symbols['pattern_prefix']}{index + 1}"
            for index in range(len(unique_offsets))
        ]
        self.header_addresses = {
            label: self.base + offset
            for label, offset in zip(self.header_labels, unique_offsets, strict=True)
        }
        self.label_by_offset = {
            offset: label
            for label, offset in zip(self.header_labels, unique_offsets, strict=True)
        }

    @property
    def values(self) -> list[int]:
        return self.document.document["data"]["values"]

    def byte(self, address: int) -> int:
        return int(self.values[address - self.base])

    def set_byte(self, address: int, value: int) -> None:
        if not self.base <= address < self.end:
            raise ValueError("FDS music edit address is outside the ending-music data")
        index = address - self.base
        if self.values[index] != value:
            self.document._remember()
            self.values[index] = value

    def _length(self, song: dict[str, Any], index: int) -> int:
        table_index = int(song["length_offset"]) + index
        if not 0 <= table_index < len(self.lengths):
            raise ValueError(f"FDS music length index {table_index} is outside the table")
        return self.lengths[table_index]

    def _decode_uncompressed(
        self,
        song: dict[str, Any],
        name: str,
        start: int,
        duration_limit: int | None,
        terminate_on_zero: bool,
    ) -> dict[str, Any]:
        address = start
        length_index = 0
        length_command = False
        elapsed = 0
        raw: list[int] = []
        events: list[dict[str, Any]] = []
        while len(raw) < MAX_CHANNEL_BYTES and address < self.end:
            byte = self.byte(address)
            raw.append(byte)
            event_address = address
            address += 1
            if byte == 0 and terminate_on_zero:
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
            if name == "wave":
                period = self._wave_period(byte)
                frequency = fds_wave_frequency(period)
            else:
                period = self._period(byte)
                frequency = timer_frequency(period, name == "triangle")
            events.append({
                "address": event_address,
                "byte": byte,
                "frequency": frequency,
                "period": period,
                "frames": frames,
                "kind": "rest" if frequency == 0 else "note",
                "length_command": length_command,
            })
            length_command = False
            elapsed += frames
            if duration_limit is not None and elapsed >= duration_limit:
                break
        return {
            "name": name,
            "start": start,
            "end": address,
            "bytes": raw,
            "events": events,
            "frames": elapsed,
        }

    def _decode_compressed(
        self,
        song: dict[str, Any],
        name: str,
        start: int,
        duration_limit: int,
    ) -> dict[str, Any]:
        address = start
        elapsed = 0
        raw: list[int] = []
        events: list[dict[str, Any]] = []
        while len(raw) < MAX_CHANNEL_BYTES and address < self.end:
            byte = self.byte(address)
            raw.append(byte)
            event_address = address
            address += 1
            if name == "noise" and byte == 0:
                break
            length_index = ((byte & 1) << 2) | (byte >> 6)
            frames = self._length(song, length_index)
            if name != "noise":
                frames = min(frames, max(0, duration_limit - elapsed))
            if frames <= 0:
                break
            pitch = byte & 0x3E
            if name == "noise":
                events.append({
                    "address": event_address,
                    "byte": byte,
                    "frequency": 0.0,
                    "frames": frames,
                    "kind": "noise",
                    "beat": "strong" if pitch else "rest",
                    "period_index": 3,
                    "length_counter": LENGTH_COUNTER_TABLE[3],
                })
            else:
                period = self._period(pitch)
                frequency = timer_frequency(period)
                events.append({
                    "address": event_address,
                    "byte": byte,
                    "frequency": frequency,
                    "period": period,
                    "frames": frames,
                    "kind": "rest" if frequency == 0 else "note",
                })
            elapsed += frames
            if name != "noise" and elapsed >= duration_limit:
                break
        return {
            "name": name,
            "start": start,
            "end": address,
            "bytes": raw,
            "events": events,
            "frames": elapsed,
        }

    def _wave_period(self, note_byte: int) -> int:
        address = self.labels[self.symbols["wave_notes"]] + (note_byte & 0x7F)
        if address + 1 >= self.labels[self.symbols["envelope"]]:
            raise ValueError(f"FDS note ${note_byte:02X} is outside the period table")
        return (self.byte(address) << 8) | self.byte(address + 1)

    def songs(self) -> list[dict[str, Any]]:
        return [self.song(label) for label in self.header_labels]

    def song(
        self,
        label: str,
        length_adder: int = 0,
        event_music: int = 0,
        area_music: int = 0,
    ) -> dict[str, Any]:
        del length_adder, event_music, area_music
        address = self.header_addresses[label]
        header = [self.byte(address + index) for index in range(8)]
        data_address = header[1] | (header[2] << 8)
        song: dict[str, Any] = {
            "label": label,
            "name": label.replace(self.symbols["pattern_prefix"], "Ending pattern "),
            "address": address,
            "length_offset": header[0],
            "data_address": data_address,
            "wave_id": header[7],
            "event_music": 0,
            "area_music": 1,
        }
        square2 = self._decode_uncompressed(
            song, "square2", data_address, None, True
        )
        duration = int(square2["frames"])
        channels = [square2]
        for name, offset, compressed in (
            ("square1", header[4], True),
            ("triangle", header[3], False),
            ("wave", header[6], False),
            ("noise", header[5], True),
        ):
            if not offset:
                continue
            start = data_address + offset
            if compressed:
                channel = self._decode_compressed(song, name, start, duration)
            else:
                channel = self._decode_uncompressed(
                    song, name, start, duration, False
                )
            channels.append(channel)
        song["channels"] = channels
        song["frames"] = duration
        return song

    def compositions(self) -> list[dict[str, Any]]:
        patterns = []
        for index, offset in enumerate(self.sequence_offsets):
            pattern = self.song(self.label_by_offset[offset])
            pattern["name"] = ANN_PATTERN_NAMES[index]
            patterns.append(pattern)
        return [{
            "name": self.symbols["composition"],
            "pointer_indexes": list(range(11)),
            "patterns": patterns,
        }]

    def describe_byte(
        self,
        channel: str,
        byte: int,
        length_offset: int,
        length_adder: int = 0,
    ) -> str:
        del length_adder
        song = {"length_offset": length_offset}
        if channel in {"square2", "triangle", "wave"}:
            if byte & 0x80:
                index = byte & 7
                return f"length {index}: {self._length(song, index)} frames"
            if channel == "wave":
                frequency = fds_wave_frequency(self._wave_period(byte))
            else:
                frequency = timer_frequency(
                    self._period(byte), channel == "triangle"
                )
            return "rest" if frequency == 0 else f"{midi_name(frequency)} ({frequency:.1f} Hz)"
        if channel == "noise":
            if byte == 0:
                return "loop marker"
            index = ((byte & 1) << 2) | (byte >> 6)
            kind = "noise beat" if byte & 0x3E else "rest"
            return f"{kind}, {self._length(song, index)} frames"
        index = ((byte & 1) << 2) | (byte >> 6)
        frequency = timer_frequency(self._period(byte & 0x3E))
        if frequency == 0:
            return f"rest, {self._length(song, index)} frames"
        return f"{midi_name(frequency)} ({frequency:.1f} Hz), {self._length(song, index)} frames"

    def _pulse_control(
        self,
        song: dict[str, Any],
        age_samples: int,
        sample_rate: int,
    ) -> tuple[int, int]:
        del song
        age_frames = int(age_samples * NTSC_FRAME_RATE / sample_rate)
        register = self.envelope_bytes[max(0, 16 - age_frames)]
        return (register >> 6) & 3, register & 0x0F

    def _render_wave_channel(
        self,
        song: dict[str, Any],
        channel: dict[str, Any],
        total_samples: int,
        sample_rate: int,
    ) -> list[float]:
        output = [0.0] * total_samples
        waveform = self.waveform(int(song["wave_id"]))["samples"]
        mirrored = [0, *waveform, *reversed(waveform[:-1])]
        midpoint = sum(mirrored) / len(mirrored)
        envelope = self.volume_envelope(int(song["wave_id"]))
        frame_cursor = 0
        phase = 0.0
        for event in channel["events"]:
            start = round(frame_cursor * sample_rate / NTSC_FRAME_RATE)
            frame_cursor += int(event["frames"])
            end = min(total_samples, round(frame_cursor * sample_rate / NTSC_FRAME_RATE))
            frequency = float(event["frequency"])
            if frequency <= 0 or end <= start:
                continue
            step = frequency / sample_rate
            for sample_index in range(start, end):
                age_frames = int(
                    (sample_index - start) * NTSC_FRAME_RATE / sample_rate
                )
                volume = self._envelope_volume(envelope, age_frames)
                sample = mirrored[int(phase * 64.0) % 64] - midpoint
                output[sample_index] = sample / 32.0 * volume / 32.0
                phase = (phase + step) % 1.0
        return output

    @staticmethod
    def _envelope_volume(envelope: list[dict[str, int | str]], age: int) -> int:
        cursor = 0
        register = int(envelope[-1]["register"])
        for step in envelope:
            register = int(step["register"])
            duration = int(step["frames"])
            if age < cursor + duration:
                break
            cursor += duration
        value = register & 0x3F
        return min(32, value)

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
        tracks: dict[str, list[float]] = {}
        for channel in song["channels"]:
            name = channel["name"]
            if enabled_channels is not None and name not in enabled_channels:
                continue
            if name == "noise":
                tracks[name] = self._render_noise_channel(
                    channel, total_frames, total_samples, sample_rate
                )
            elif name == "triangle":
                tracks[name] = self._render_triangle_channel(
                    song, channel, total_samples, sample_rate
                )
            elif name == "wave":
                tracks[name] = self._render_wave_channel(
                    song, channel, total_samples, sample_rate
                )
            else:
                tracks[name] = self._render_pulse_channel(
                    song, channel, total_samples, sample_rate
                )
        if output_filter is None:
            output_filter = ApuOutputFilter(sample_rate)
            output_filter.prime(0.0)
        silent = [0.0] * total_samples
        pulse1 = tracks.get("square1", silent)
        pulse2 = tracks.get("square2", silent)
        triangle = tracks.get("triangle", silent)
        noise = tracks.get("noise", silent)
        fds_wave = tracks.get("wave", silent)
        pcm = bytearray()
        for index in range(total_samples):
            mixed = apu_mix(
                pulse1[index], pulse2[index], triangle[index], noise[index], 0
            ) + fds_wave[index] * 0.12
            filtered = output_filter.process(mixed)
            sample = max(-1.0, min(1.0, filtered * 2.8))
            pcm.extend(struct.pack("<h", round(sample * 32767)))
        return bytes(pcm)

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
        output_filter.prime(0.0)
        for pattern in patterns:
            pcm.extend(self.render_pattern(
                pattern, sample_rate, output_filter, enabled_channels
            ))
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(sample_rate)
            output.writeframes(bytes(pcm))
        return path

    def waveform(self, wave_id: int) -> dict[str, Any]:
        configuration = self._wave_configuration(wave_id)
        address = configuration["wave_address"]
        return {
            "id": wave_id,
            "name": f"FDS wave {wave_id}",
            "address": address,
            "samples": [self.byte(address + index) for index in range(32)],
        }

    def set_wave_sample(self, wave_id: int, index: int, value: int) -> None:
        if not 0 <= index < 32 or not 0 <= value <= 63:
            raise ValueError("FDS wave sample must use index 0..31 and value 0..63")
        address = int(self._wave_configuration(wave_id)["wave_address"]) + index
        self.set_byte(address, value)

    def volume_envelope(self, wave_id: int) -> list[dict[str, int | str]]:
        configuration = self._wave_configuration(wave_id)
        address = int(configuration["volume_address"])
        end = (
            self.labels[self.symbols["wave_a_volumes"]]
            if wave_id == 2
            else self.labels[self.symbols["wave_notes"]]
        )
        result = []
        for step, pointer in enumerate(range(address, end, 2)):
            register = self.byte(pointer)
            mode = "direct" if register & 0x80 else "increase" if register & 0x40 else "decrease"
            result.append({
                "step": step,
                "address": pointer,
                "mode": mode,
                "value": register & 0x3F,
                "frames": self.byte(pointer + 1),
                "register": register,
            })
        return result

    def set_volume_step(
        self,
        wave_id: int,
        step: int,
        mode: str,
        value: int,
        frames: int,
    ) -> None:
        modes = {"direct": 0x80, "increase": 0x40, "decrease": 0x00}
        envelope = self.volume_envelope(wave_id)
        if not 0 <= step < len(envelope):
            raise ValueError("FDS volume-envelope step is outside the table")
        if mode not in modes or not 0 <= value <= 63 or not 1 <= frames <= 255:
            raise ValueError("Invalid FDS volume-envelope parameters")
        address = int(envelope[step]["address"])
        self.set_byte(address, modes[mode] | value)
        self.set_byte(address + 1, frames)

    def _wave_configuration(self, wave_id: int) -> dict[str, int]:
        if wave_id <= 0 or wave_id & (wave_id - 1):
            raise ValueError(f"Unsupported FDS wave id: {wave_id}")
        selector = wave_id.bit_length()
        table = self.labels[self.symbols["wave_offsets"]]
        descriptor_offset = self.byte(table - 1 + selector)
        address = table + descriptor_offset
        return {
            "wave_address": self.byte(address) | (self.byte(address + 1) << 8),
            "envelope_frames": self.byte(address + 2),
            "volume_address": self.byte(address + 3) | (self.byte(address + 4) << 8),
            "modulation_address": self.byte(address + 5) | (self.byte(address + 6) << 8),
            "modulation_offset": self.byte(address + 7),
        }
