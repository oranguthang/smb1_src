from __future__ import annotations

import hashlib
import sys
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from platform_profiles import (
    build_fds_image,
    build_ines_image,
    extract_fds_payloads,
    make_fds_template,
    parse_fds_side,
    payload_paths,
    split_ines_reference,
)


class PlatformProfileTests(unittest.TestCase):
    def setUp(self) -> None:
        self.header = b"H" * 16
        self.prg = b"P" * 32
        self.chr_data = b"C" * 16
        self.image = self.header + self.prg + self.chr_data
        self.profile = {
            "id": "test",
            "format": "ines",
            "rom_size": len(self.image),
            "rom_sha1": hashlib.sha1(self.image).hexdigest(),
        }
        for name, data in (
            ("header", self.header),
            ("prg", self.prg),
            ("chr", self.chr_data),
        ):
            self.profile[f"{name}_size"] = len(data)
            self.profile[f"{name}_sha1"] = hashlib.sha1(data).hexdigest()

    def test_splits_and_rebuilds_exact_ines_profile(self) -> None:
        regions = split_ines_reference(self.image, self.profile)
        self.assertEqual(build_ines_image(self.profile, *regions), self.image)

    def test_rejects_wrong_private_reference(self) -> None:
        with self.assertRaisesRegex(ValueError, "private platform reference"):
            split_ines_reference(self.image[:-1], self.profile)

    def test_rejects_component_substitution(self) -> None:
        with self.assertRaisesRegex(ValueError, "prg hash mismatch"):
            build_ines_image(
                self.profile,
                self.header,
                b"Q" * len(self.prg),
                self.chr_data,
            )


class FdsPlatformProfileTests(unittest.TestCase):
    @staticmethod
    def file_block(
        file_number: int,
        file_id: int,
        name: bytes,
        load_address: int,
        data: bytes,
        file_type: int = 0,
    ) -> bytes:
        header = bytes((3, file_number, file_id))
        header += name.ljust(8, b" ")[:8]
        header += load_address.to_bytes(2, "little")
        header += len(data).to_bytes(2, "little")
        header += bytes((file_type,))
        return header + bytes((4,)) + data

    def setUp(self) -> None:
        disk_header = bytes((1,)) + bytes(55)
        files = (
            self.file_block(0, 1, b"ASSET", 0, b"CHR", 1),
            self.file_block(1, 3, b"MAIN-A", 0x6000, b"AB"),
            self.file_block(2, 4, b"MAIN-B", 0xA000, b"CDE"),
        )
        self.image = disk_header + bytes((2, len(files))) + b"".join(files) + bytes(10)
        self.payload = b"ABCDE"
        self.profile = {
            "id": "fds_test",
            "format": "fds_raw_side",
            "disk_size": len(self.image),
            "disk_sha1": hashlib.sha1(self.image).hexdigest(),
            "primary_payload": "MAIN",
            "verified_payloads": [
                {
                    "name": "MAIN",
                    "size": len(self.payload),
                    "sha1": hashlib.sha1(self.payload).hexdigest(),
                    "records": [
                        {"file_id": 3, "load_address": 0x6000, "size": 2},
                        {"file_id": 4, "load_address": 0xA000, "size": 3},
                    ],
                }
            ],
        }
        template = bytearray(self.image)
        records = parse_fds_side(self.image)
        for record in records[1:]:
            template[record.data_offset : record.data_offset + record.size] = bytes(
                record.size
            )
        self.template = bytes(template)
        self.profile["template_sha1"] = hashlib.sha1(self.template).hexdigest()

    def test_extracts_and_rebuilds_exact_fds_side(self) -> None:
        self.assertEqual(extract_fds_payloads(self.image, self.profile), {"MAIN": self.payload})
        self.assertEqual(make_fds_template(self.image, self.profile), self.template)
        self.assertEqual(
            build_fds_image(self.profile, self.template, {"MAIN": self.payload}),
            self.image,
        )

    def test_template_retains_unselected_file_data(self) -> None:
        records = parse_fds_side(self.template)
        asset = records[0]
        self.assertEqual(
            self.template[asset.data_offset : asset.data_offset + asset.size], b"CHR"
        )
        for record in records[1:]:
            self.assertEqual(
                self.template[record.data_offset : record.data_offset + record.size],
                bytes(record.size),
            )

    def test_rejects_payload_substitution(self) -> None:
        with self.assertRaisesRegex(ValueError, "payload hash mismatch"):
            build_fds_image(self.profile, self.template, {"MAIN": b"ABCDF"})

    def test_build_mode_accepts_reconstructed_payload_bytes(self) -> None:
        candidate = build_fds_image(
            self.profile,
            self.template,
            {"MAIN": b"ABCDF"},
            strict=False,
        )
        self.assertNotEqual(candidate, self.image)

    def test_resolves_auxiliary_payloads_from_private_assets(self) -> None:
        profile = dict(self.profile)
        profile["verified_payloads"] = [
            *self.profile["verified_payloads"],
            {"name": "DATA2", "size": 1, "sha1": "unused", "records": []},
        ]
        paths = payload_paths(
            profile,
            Path("main.bin"),
            [],
            Path("private") / "payloads",
        )
        self.assertEqual(paths["MAIN"], Path("main.bin"))
        self.assertEqual(paths["DATA2"], Path("private") / "payloads" / "DATA2.bin")

    def test_rejects_malformed_fds_side(self) -> None:
        with self.assertRaisesRegex(ValueError, "file-data block"):
            parse_fds_side(self.image[:74] + bytes((5,)) + self.image[75:])


if __name__ == "__main__":
    unittest.main()
