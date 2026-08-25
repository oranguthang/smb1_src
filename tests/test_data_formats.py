from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from data_formats import (  # noqa: E402
    decode_area_object_stream,
    decode_enemy_object_stream,
    decode_music_channels,
    decode_ppu_packets,
    encode_area_object_stream,
    encode_enemy_object_stream,
    encode_music_channels,
    encode_ppu_packets,
)


class DataFormatTests(unittest.TestCase):
    def test_area_header_and_object_pair_round_trip(self) -> None:
        data = bytes([0x9B, 0x07, 0x05, 0x32, 0xFD])
        decoded = decode_area_object_stream(data, {})
        self.assertEqual(decoded["header"]["timer_setting"], 2)
        self.assertEqual(decoded["header"]["entrance_control"], 3)
        self.assertEqual(decoded["objects"][0]["column"], 0)
        self.assertEqual(decoded["objects"][0]["row"], 5)
        self.assertEqual(encode_area_object_stream(decoded, {}), data)

    def test_enemy_entrance_record_is_three_bytes(self) -> None:
        data = bytes([0x1E, 0xC2, 0x65, 0x6B, 0x06, 0xFF])
        decoded = decode_enemy_object_stream(data, {})
        entrance = decoded["records"][0]
        self.assertEqual(entrance["kind"], "entrance")
        self.assertEqual(entrance["destination_world"], 3)
        self.assertEqual(entrance["destination_page"], 5)
        self.assertEqual(encode_enemy_object_stream(decoded, {}), data)

    def test_ppu_repeat_packet_consumes_one_value(self) -> None:
        entry = {"terminator": 0xFF}
        data = bytes([0x23, 0xC0, 0x7F, 0xAA, 0xFF])
        decoded = decode_ppu_packets(data, entry)
        packet = decoded["packets"][0]
        self.assertTrue(packet["repeat"])
        self.assertEqual(packet["length"], 0x3F)
        self.assertEqual(packet["values"], [0xAA])
        self.assertEqual(encode_ppu_packets(decoded, entry), data)

    def test_music_event_fields_reconstruct_every_bit(self) -> None:
        entry = {
            "channels": [
                {"name": "square2", "format": "square2", "length": 3},
                {"name": "noise", "format": "noise", "length": 2},
            ]
        }
        data = bytes([0x84, 0x2C, 0x00, 0xD0, 0x21])
        decoded = decode_music_channels(data, entry)
        self.assertEqual(decoded["channels"][0]["events"][0]["kind"], "length")
        self.assertEqual(decoded["channels"][0]["events"][1], {"kind": "note", "offset": 0x2C})
        self.assertEqual(encode_music_channels(decoded, entry), data)


if __name__ == "__main__":
    unittest.main()
