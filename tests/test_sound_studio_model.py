from __future__ import annotations

import math
import sys
import tempfile
import unittest
import wave
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from sound_studio_model import (  # noqa: E402
    MusicBank,
    NTSC_FRAME_RATE,
    decode_periods,
    timer_frequency,
)


def synthetic_bank(values: list[int]) -> MusicBank:
    model = MusicBank.__new__(MusicBank)
    model.base = 0x8000
    model.end = model.base + len(values)
    model.document = type("Document", (), {
        "document": {"data": {"values": values}},
    })()
    model.periods = [136, 47, 0, 678] + [500] * 48
    model.lengths = [5] * 48
    return model


class SoundStudioModelTests(unittest.TestCase):
    def test_period_table_uses_engine_high_low_byte_order(self) -> None:
        self.assertEqual(decode_periods(bytes([0x00, 0x88, 0x02, 0xA6])), [0x0088, 0x02A6])
        self.assertAlmostEqual(timer_frequency(0x0088), 816.5, delta=0.5)
        self.assertEqual(timer_frequency(0), 0.0)

    def test_rest_timer_is_silent_and_secondary_channel_is_clipped(self) -> None:
        model = synthetic_bank([0x80, 0x04, 0x06, 0x00, 0x80, 0x06, 0x06, 0x06])
        song = {"length_offset": 0, "length_adder": 0}
        lead = model._decode_uncompressed(song, "square2", 0x8000, None)
        triangle = model._decode_uncompressed(song, "triangle", 0x8004, 7)
        self.assertEqual(lead["frames"], 10)
        self.assertEqual(lead["events"][0]["kind"], "rest")
        self.assertEqual([event["frames"] for event in triangle["events"]], [5, 2])

    def test_square1_control_reload_consumes_no_musical_time(self) -> None:
        model = synthetic_bank([0x00, 0x06, 0x06])
        channel = model._decode_compressed(
            {"length_offset": 0, "length_adder": 0}, "square1", 0x8000, 10
        )
        self.assertEqual(channel["frames"], 10)
        self.assertEqual(len(channel["events"]), 2)

    def test_wav_duration_follows_ntsc_frame_timing(self) -> None:
        model = synthetic_bank([])
        pattern = {
            "label": "test",
            "length_adder": 0,
            "frames": 6,
            "channels": [{
                "name": "square2",
                "events": [{"frequency": 440.0, "frames": 6}],
            }],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preview.wav"
            model.write_preview([pattern], path, sample_rate=6000)
            with wave.open(str(path), "rb") as source:
                self.assertEqual(source.getframerate(), 6000)
                self.assertEqual(source.getnframes(), round(6 * 6000 / NTSC_FRAME_RATE))
                samples = source.readframes(source.getnframes())
            self.assertTrue(any(samples))
            self.assertFalse(math.isnan(timer_frequency(136)))


if __name__ == "__main__":
    unittest.main()
