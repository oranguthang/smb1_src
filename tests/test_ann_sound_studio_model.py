from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ann_sound_studio_model import (  # noqa: E402
    AnnFdsMusicBank,
    fds_wave_frequency,
)


class FakeDocument:
    def __init__(self, values: list[int]) -> None:
        self.document = {"data": {"values": values}}
        self.remembered = 0

    def _remember(self) -> None:
        self.remembered += 1


def synthetic_bank() -> AnnFdsMusicBank:
    model = AnnFdsMusicBank.__new__(AnnFdsMusicBank)
    model.base = 0x1000
    model.end = 0x1400
    model.document = FakeDocument([0] * (model.end - model.base))
    model.labels = {
        "tbl_ann_fds_wave_offsets": 0x1200,
        "tbl_ann_fds_wave_a_volumes": 0x1304,
        "tbl_ann_fds_wave_notes": 0x1310,
        "tbl_ann_fds_envelope": 0x1350,
    }
    model.period_bytes = bytes([0x00, 0x00, 0x00, 0x88])
    model.lengths = [6] * 16
    model.envelope_bytes = bytes([0x97] * 17)
    return model


class AnnFdsSoundStudioModelTests(unittest.TestCase):
    def test_fds_period_uses_64_sample_phase_accumulator(self) -> None:
        self.assertAlmostEqual(fds_wave_frequency(0x0144), 138.25, delta=0.1)

    def test_wave_configuration_selects_one_hot_descriptor(self) -> None:
        model = synthetic_bank()
        table = model.labels["tbl_ann_fds_wave_offsets"]
        values = model.values

        def write(address: int, data: list[int]) -> None:
            values[address - model.base:address - model.base + len(data)] = data

        write(table, [0x02, 0x0A])
        write(table + 2, [0x20, 0x12, 0x44, 0x04, 0x13, 0x40, 0x13, 0x20])
        write(table + 10, [0x40, 0x12, 0x60, 0x00, 0x13, 0x48, 0x13, 0x00])
        write(0x1220, list(range(32)))
        write(0x1240, list(reversed(range(32))))
        write(0x1300, [0xA0, 4, 0x18, 0x60])
        write(0x1304, [
            0x94, 2, 0x84, 4, 0xA0, 6,
            0x80, 8, 0x90, 10, 0x88, 12,
        ])

        self.assertEqual(model.waveform(1)["samples"], list(range(32)))
        self.assertEqual(model.waveform(2)["samples"], list(reversed(range(32))))
        self.assertEqual(
            [step["mode"] for step in model.volume_envelope(1)],
            ["direct", "direct", "direct", "direct", "direct", "direct"],
        )
        self.assertEqual(
            [step["mode"] for step in model.volume_envelope(2)],
            ["direct", "decrease"],
        )

    def test_uncompressed_channel_uses_ann_length_commands(self) -> None:
        model = synthetic_bank()
        start = 0x1100
        model.values[start - model.base:start - model.base + 3] = [0x82, 0x02, 0x00]
        channel = model._decode_uncompressed(
            {"length_offset": 0}, "square2", start, None, True
        )
        self.assertEqual(channel["bytes"], [0x82, 0x02, 0x00])
        self.assertEqual(channel["frames"], 6)
        self.assertTrue(channel["events"][0]["length_command"])

    def test_wave_sample_edit_preserves_fixed_storage(self) -> None:
        model = synthetic_bank()
        table = model.labels["tbl_ann_fds_wave_offsets"]
        model.values[table - model.base] = 2
        descriptor = table + 2
        model.values[descriptor - model.base:descriptor - model.base + 8] = [
            0x20, 0x12, 0, 0, 0x13, 0, 0, 0,
        ]
        model.set_wave_sample(1, 7, 63)
        self.assertEqual(model.byte(0x1227), 63)
        self.assertEqual(model.document.remembered, 1)


if __name__ == "__main__":
    unittest.main()
