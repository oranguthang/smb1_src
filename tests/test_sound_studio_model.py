from __future__ import annotations

import math
import sys
import tempfile
import unittest
import wave
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from sound_studio_model import (  # noqa: E402
    ApuOutputFilter,
    MusicBank,
    NTSC_FRAME_RATE,
    apu_mix,
    available_header_labels,
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
    model.envelope_bytes = bytes([
        0x98, 0x99, 0x9A, 0x9B,
        0x90, 0x94, 0x94, 0x95, 0x95, 0x96, 0x97, 0x98,
        0x90, 0x91, 0x92, 0x92, 0x93, 0x93, 0x93, 0x94,
        0x94, 0x94, 0x94, 0x94, 0x94, 0x95, 0x95, 0x95,
        0x95, 0x95, 0x95, 0x96, 0x96, 0x96, 0x96, 0x96,
        0x96, 0x96, 0x96, 0x96, 0x96, 0x96, 0x96, 0x96,
        0x96, 0x96, 0x96, 0x96, 0x95, 0x95, 0x94, 0x93,
        0x15,
    ])
    return model


class SoundStudioModelTests(unittest.TestCase):
    def test_princess_composition_requires_the_victory_header(self) -> None:
        model = MusicBank.__new__(MusicBank)
        model.song_from_pointer = lambda index: {
            "label": (
                "off_music_header_victory"
                if index == 2 else "off_music_header_ground_part_1"
            )
        }
        self.assertIn(
            "Princess Rescued",
            [composition["name"] for composition in model.compositions()],
        )

        model.song_from_pointer = lambda index: {
            "label": (
                "off_music_header_game_over"
                if index == 2 else "off_music_header_ground_part_1"
            )
        }
        self.assertNotIn(
            "Princess Rescued",
            [composition["name"] for composition in model.compositions()],
        )

    def test_prg_lookup_uses_selected_profile_load_address(self) -> None:
        model = MusicBank.__new__(MusicBank)
        model.labels = {"data": 0x6002}
        model.prg = b"ABCDE"
        model.load_address = 0x6000
        self.assertEqual(model._prg_bytes("data", 2), b"CD")

    def test_header_list_uses_only_selected_profile_symbols(self) -> None:
        labels = {
            "off_music_header_game_over": 0x9004,
            "off_music_header_star_cloud": 0x9000,
        }
        self.assertEqual(
            available_header_labels(labels),
            ["off_music_header_star_cloud", "off_music_header_game_over"],
        )

    def test_period_table_uses_engine_high_low_byte_order(self) -> None:
        self.assertEqual(decode_periods(bytes([0x00, 0x88, 0x02, 0xA6])), [0x0088, 0x02A6])
        self.assertAlmostEqual(timer_frequency(0x0088), 816.5, delta=0.5)
        self.assertEqual(timer_frequency(0), 0.0)

    def test_period_lookup_accepts_profile_defined_odd_byte_offset(self) -> None:
        model = synthetic_bank([])
        model.period_bytes = bytes([0x00, 0x88, 0x02, 0xA6])
        self.assertEqual(model._period(0x01), 0x8802)

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
                "events": [{"frequency": 440.0, "period": 253, "frames": 6}],
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

    def test_preview_channel_switches_can_mute_everything(self) -> None:
        model = synthetic_bank([])
        pattern = {
            "label": "test",
            "length_adder": 0,
            "frames": 6,
            "channels": [{
                "name": "square2",
                "events": [{"frequency": 440.0, "period": 253, "frames": 6}],
            }],
        }
        pcm = model.render_pattern(pattern, sample_rate=6000, enabled_channels=set())
        self.assertEqual(set(pcm), {0})

    def test_noise_renderer_emits_real_four_bit_dac_levels(self) -> None:
        model = synthetic_bank([])
        channel = {
            "events": [{
                "frames": 4,
                "beat": "short",
                "period_index": 3,
                "length_counter": 2,
            }],
        }
        samples = model._render_noise_channel(channel, 4, 400, 6000)
        self.assertEqual(set(samples), {0.0, 12.0})
        gate_end = round(2 * 6000 / (NTSC_FRAME_RATE * 2))
        self.assertTrue(any(samples[:gate_end]))
        self.assertFalse(any(samples[gate_end:]))

    def test_nonlinear_mixer_and_output_filter_reject_dc(self) -> None:
        one_pulse = apu_mix(15, 0, 0, 0, 0)
        two_pulses = apu_mix(15, 15, 0, 0, 0)
        self.assertGreater(two_pulses, one_pulse)
        self.assertLess(two_pulses, one_pulse * 2)
        output_filter = ApuOutputFilter(44_100)
        value = 0.0
        for _index in range(88_200):
            value = output_filter.process(0.5)
        self.assertAlmostEqual(value, 0.0, delta=0.0001)

    def test_area_pulse_envelope_silences_a_long_note(self) -> None:
        model = synthetic_bank([])
        song = {"event_music": 0, "area_music": 1}
        channel = {"events": [{"period": 253, "frames": 20}]}
        samples = model._render_pulse_channel(song, channel, 2000, 6000)
        frame_samples = round(6000 / NTSC_FRAME_RATE)
        self.assertTrue(any(samples[:frame_samples * 8]))
        self.assertFalse(any(samples[frame_samples * 10:]))

    def test_pulse_software_envelopes_start_inside_their_own_tables(self) -> None:
        model = synthetic_bank([])
        sample_rate = 6000

        def volumes(song: dict[str, int], count: int) -> list[int]:
            return [
                model._pulse_control(
                    song,
                    round((frame + 0.5) * sample_rate / NTSC_FRAME_RATE),
                    sample_rate,
                )[1]
                for frame in range(count)
            ]

        self.assertEqual(volumes({"event_music": 0, "area_music": 1}, 10),
                         [8, 7, 6, 5, 5, 4, 4, 0, 0, 0])
        self.assertEqual(volumes({"event_music": 0x08, "area_music": 0}, 6),
                         [11, 10, 9, 8, 8, 8])
        self.assertEqual(volumes({"event_music": 0x02, "area_music": 0}, 6),
                         [3, 4, 5, 5, 6, 6])

    def test_ground_triangle_linear_counter_holds_after_eight_frames(self) -> None:
        model = synthetic_bank([])
        song = {"event_music": 0, "area_music": 1}
        channel = {"events": [{
            "period": 253,
            "frames": 20,
            "length_command": True,
        }]}
        samples = model._render_triangle_channel(song, channel, 2000, 6000)
        frame_samples = round(6000 / NTSC_FRAME_RATE)
        self.assertGreater(len(set(samples[:frame_samples * 6])), 8)
        self.assertEqual(len(set(samples[frame_samples * 9:frame_samples * 19])), 1)


if __name__ == "__main__":
    unittest.main()
