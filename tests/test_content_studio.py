from __future__ import annotations

import json
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from content_studio import (
    artifact_range,
    atomic_write_json,
    compose_profile_image,
    fds_record_data,
    initialize_chr_workspace,
    load_named_payloads,
    load_profile_chr,
    parse_named_paths,
    replace_fds_records,
    load_format_manifest,
    load_workspace_chr,
    resolve_profile_selection,
    scatter_virtual_streams,
    selected_entries,
    stream_end,
    validate_unmodified_image,
    write_workspace_documents,
    encode_workspace_document,
)
from platform_profiles import FdsFileRecord


class ContentStudioTests(unittest.TestCase):
    @staticmethod
    def fds_file_block(
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

    def test_atomic_json_write_replaces_complete_document(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "artifact.json"
            atomic_write_json(path, {"value": 1})
            atomic_write_json(path, {"value": 2})
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), {"value": 2})
            self.assertEqual(list(path.parent.glob("*.tmp")), [])

    def test_rejects_fixed_capacity_change(self) -> None:
        entry = {
            "id": "records",
            "codec": "fixed_records",
            "record_size": 2,
            "record_name": "record",
        }
        document = {
            "schema_version": 1,
            "artifact_id": "records",
            "codec": "fixed_records",
            "capacity_bytes": 2,
            "data": {"records": [[1, 2], [3, 4]]},
        }
        with self.assertRaisesRegex(ValueError, "fixed capacity"):
            encode_workspace_document(document, entry, 2)

    def test_rejects_modified_protected_metadata(self) -> None:
        entry = {
            "id": "records",
            "codec": "fixed_records",
            "record_size": 2,
            "record_name": "record",
        }
        document = {
            "schema_version": 1,
            "artifact_id": "different",
            "codec": "fixed_records",
            "capacity_bytes": 2,
            "data": {"records": [[1, 2]]},
        }
        with self.assertRaisesRegex(ValueError, "protected field"):
            encode_workspace_document(document, entry, 2)

    def test_rejects_workspace_from_another_profile(self) -> None:
        entry = {"id": "raw", "codec": "raw_bytes"}
        document = {
            "schema_version": 1,
            "profile": "pal",
            "artifact_id": "raw",
            "codec": "raw_bytes",
            "capacity_bytes": 1,
            "data": {"values": [0]},
        }
        with self.assertRaisesRegex(ValueError, "field profile"):
            encode_workspace_document(document, entry, 1, "ju")

    def test_fds_artifact_range_uses_payload_load_address(self) -> None:
        entry = {"id": "range", "start": "start", "end": "end"}
        self.assertEqual(
            artifact_range(
                entry,
                {"start": 0x6004, "end": 0x6008},
                0x20,
                load_address=0x6000,
            ),
            (4, 8),
        )

    def test_fds_program_is_distributed_across_selected_records(self) -> None:
        records = [
            FdsFileRecord(0, 3, b"SMMAIN3 ", 0x6000, 2, 0, 0, 1),
            FdsFileRecord(1, 4, b"SMMAIN4 ", 0xA000, 3, 0, 0, 4),
        ]
        image = bytearray(7)
        replace_fds_records(image, records, [3, 4], b"ABCDE", require_empty=True)
        self.assertEqual(image, bytearray(b"\x00AB\x00CDE"))

    def test_fds_program_rejects_nonempty_template_records(self) -> None:
        record = FdsFileRecord(0, 3, b"SMMAIN3 ", 0x6000, 2, 0, 0, 1)
        with self.assertRaisesRegex(ValueError, "not empty"):
            replace_fds_records(
                bytearray(b"\x00X\x00"),
                [record],
                [3],
                b"AB",
                require_empty=True,
            )

    def test_named_payload_paths_reject_reserved_and_duplicate_names(self) -> None:
        self.assertEqual(
            parse_named_paths(["DATA2=payload.bin"]),
            {"DATA2": Path("payload.bin")},
        )
        with self.assertRaisesRegex(ValueError, "reserved"):
            parse_named_paths(["prg=payload.bin"])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            parse_named_paths(["DATA2=first.bin", "DATA2=second.bin"])

    def test_named_payload_requires_manifest_size_and_hash(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "payload.bin"
            path.write_bytes(b"ABC")
            profile = {
                "payloads": {
                    "DATA2": {
                        "load_address": "0xc000",
                        "size": 3,
                        "sha1": hashlib.sha1(b"ABC").hexdigest(),
                    }
                }
            }
            self.assertEqual(
                load_named_payloads({"DATA2": path}, profile),
                {"DATA2": b"ABC"},
            )
            path.write_bytes(b"ABD")
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                load_named_payloads({"DATA2": path}, profile)

    def test_fds_chr_source_and_program_payloads_roundtrip(self) -> None:
        disk_header = bytes((1,)) + bytes(55)
        files = (
            self.fds_file_block(0, 1, b"CHAR", 0, b"CHR", 1),
            self.fds_file_block(1, 5, b"MAIN", 0x6000, bytes(2)),
            self.fds_file_block(2, 32, b"DATA2", 0xC000, bytes(3)),
        )
        template = disk_header + bytes((2, len(files))) + b"".join(files) + bytes(10)
        profile = {
            "id": "test",
            "baseline": {"kind": "platform"},
            "container": "fds",
            "template_sha1": hashlib.sha1(template).hexdigest(),
            "chr_source": "fds_records",
            "chr_record_ids": [1],
            "chr_sha1": hashlib.sha1(b"CHR").hexdigest(),
            "program_payloads": [
                {"payload": "prg", "record_ids": [5]},
                {"payload": "DATA2", "record_ids": [32]},
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "template.fds"
            path.write_bytes(template)
            self.assertEqual(load_profile_chr(path, profile), b"CHR")
        image = compose_profile_image(
            profile,
            b"AB",
            b"XYZ",
            payloads={"DATA2": b"CDE"},
            template=template,
        )
        self.assertEqual(fds_record_data(image, [1]), b"XYZ")
        self.assertEqual(fds_record_data(image, [5, 32]), b"ABCDE")

    def test_layered_content_manifest_preserves_base_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "base.json").write_text(
                json.dumps({"format": 1, "artifacts": [{"id": "old"}, {"id": "keep"}]}),
                encoding="utf-8",
            )
            (root / "content.json").write_text(
                json.dumps({
                    "format": 1,
                    "base_manifest": "base.json",
                    "excluded_artifacts": ["old"],
                    "artifacts": [{"id": "new"}],
                }),
                encoding="utf-8",
            )
            merged = load_format_manifest(root / "content.json")
            self.assertEqual([entry["id"] for entry in merged["artifacts"]], ["keep", "new"])

    def test_format_manifest_can_extend_an_existing_layer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "base.json").write_text(
                json.dumps({"format": 1, "artifacts": [{"id": "base"}]}),
                encoding="utf-8",
            )
            (root / "middle.json").write_text(
                json.dumps({
                    "format": 1,
                    "base_manifest": "base.json",
                    "artifacts": [{"id": "middle"}],
                }),
                encoding="utf-8",
            )
            (root / "active.json").write_text(
                json.dumps({
                    "format": 1,
                    "base_manifest": "middle.json",
                    "artifacts": [{"id": "active"}],
                }),
                encoding="utf-8",
            )
            merged = load_format_manifest(root / "active.json")
            self.assertEqual(
                [entry["id"] for entry in merged["artifacts"]],
                ["base", "middle", "active"],
            )

    def test_format_manifest_rejects_cycles(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "first.json").write_text(
                json.dumps({
                    "format": 1,
                    "base_manifest": "second.json",
                    "artifacts": [],
                }),
                encoding="utf-8",
            )
            (root / "second.json").write_text(
                json.dumps({
                    "format": 1,
                    "base_manifest": "first.json",
                    "artifacts": [],
                }),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "cyclic content format manifest"):
                load_format_manifest(root / "first.json")

    def test_init_keeps_existing_workspace_document(self) -> None:
        entry = {
            "id": "records",
            "codec": "fixed_records",
            "record_size": 2,
            "record_name": "record",
            "start": "start",
            "end": "end",
            "source": "source.asm",
        }
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            path = workspace / "graphics" / "records.json"
            path.parent.mkdir(parents=True)
            path.write_text('{"local": true}\n', encoding="utf-8")
            write_workspace_documents(
                workspace,
                [("graphics", entry)],
                {"start": 0x8000, "end": 0x8002},
                {"prg": bytes([1, 2])},
                overwrite=False,
            )
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), {"local": True})

    def test_workspace_chr_requires_fixed_8k_size(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.chr"
            source.write_bytes(bytes(8192))
            workspace = root / "workspace"
            (workspace / "graphics").mkdir(parents=True)
            (workspace / "graphics" / "smb.chr").write_bytes(bytes(8191))
            with self.assertRaisesRegex(ValueError, "exactly 8192"):
                load_workspace_chr(workspace, source)

    def test_chr_workspace_overlays_only_the_profile_editable_slice(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.chr"
            source.write_bytes(bytes([0x11]) * 8192 + bytes([0x22]) * 8192)
            workspace = root / "workspace"
            profile = {
                "chr_layout": {
                    "source_size": 16384,
                    "editable_offset": 0,
                    "editable_size": 8192,
                }
            }
            selection = [("graphics", {"id": "tiles"})]
            initialize_chr_workspace(workspace, source, selection, True, profile)
            editable = workspace / "graphics" / "smb.chr"
            self.assertEqual(editable.read_bytes(), bytes([0x11]) * 8192)
            edited = bytearray(editable.read_bytes())
            edited[0] = 0x33
            editable.write_bytes(edited)
            candidate, changed = load_workspace_chr(workspace, source, profile)
            self.assertEqual(changed, 1)
            self.assertEqual(candidate[0], 0x33)
            self.assertEqual(candidate[8192:], bytes([0x22]) * 8192)

    def test_stream_end_parses_area_and_enemy_record_widths(self) -> None:
        area = bytes([0x12, 0x34, 0x01, 0x02, 0x03, 0x04, 0xFD])
        enemy = bytes([0x0E, 0x10, 0x20, 0xFF])
        self.assertEqual(stream_end(area, 0, "area_object_stream", 6), 6)
        self.assertEqual(stream_end(enemy, 0, "enemy_object_stream", 3), 3)

    def test_external_streams_follow_physical_chr_pointer_order(self) -> None:
        entry = {
            "id": "area_object_streams",
            "codec": "stream_collection",
            "stream_codec": "area_object_stream",
            "stream_terminator": 0xFD,
        }
        profile = {
            "id": "vs_smb",
            "baseline": {"load_address": "0x8000"},
            "artifact_overrides": {
                "area_object_streams": {
                    "payload": "chr",
                    "bank_offset": 0,
                    "pointer_table": "pointers",
                    "groups": [["ground", 2]],
                }
            },
        }
        prg = bytes([0x04, 0x00, 0x00, 0x00])
        chr_data = bytes([0x10, 0x20, 0xFD, 0x00, 0x11, 0x21, 0x01, 0x02, 0xFD])
        resolved = resolve_profile_selection(
            [("level", entry)],
            profile,
            {"pointers": 0x8000},
            {"prg": prg, "chr": chr_data},
        )[0][1]
        self.assertEqual(resolved["stream_names"], ["ground_2", "ground_1"])
        self.assertEqual(resolved["stream_boundaries"], [0, 4, 9])
        self.assertEqual(
            resolved["streams"],
            [
                {"name": "ground_2", "capacity": 4},
                {"name": "ground_1", "capacity": 5},
            ],
        )

    def test_external_enemy_streams_allow_a_shared_terminator(self) -> None:
        entry = {
            "id": "enemy_object_streams",
            "codec": "stream_collection",
            "stream_codec": "enemy_object_stream",
            "stream_terminator": 0xFF,
        }
        profile = {
            "id": "vs_smb",
            "baseline": {"load_address": "0x8000"},
            "artifact_overrides": {
                "enemy_object_streams": {
                    "payload": "chr",
                    "bank_offset": 0,
                    "pointer_table": "pointers",
                    "groups": [["ground", 2]],
                }
            },
        }
        resolved = resolve_profile_selection(
            [("level", entry)],
            profile,
            {"pointers": 0x8000},
            {"prg": bytes([0, 0, 2, 0]), "chr": bytes([0x01, 0x02, 0xFF])},
        )[0][1]
        self.assertEqual(resolved["stream_boundaries"], [0, 2, 3])
        self.assertEqual(resolved["streams"][0]["capacity"], 2)

    def test_pointer_streams_gather_and_scatter_named_payloads(self) -> None:
        entry = {
            "id": "area_object_streams",
            "codec": "stream_collection",
            "stream_codec": "area_object_stream",
            "stream_terminator": 0xFD,
        }
        profile = {
            "id": "overlay",
            "baseline": {"load_address": "0x8000"},
            "payloads": {"DATA2": {"load_address": "0xc000"}},
            "stream_payload_maps": {
                "normal": ["DATA2", "DATA2", "DATA2"],
            },
            "artifact_overrides": {
                "area_object_streams": {
                    "pointer_table": "pointers",
                    "pointer_payload_map": "normal",
                    "groups": [["ground", 3]],
                    "allow_shared_pointers": True,
                }
            },
        }
        prg = bytes([0x00, 0xC0, 0x03, 0xC0, 0x00, 0xC0])
        payload = bytes([0x00, 0x00, 0xFD, 0x01, 0x01, 0xFD])
        resolved = resolve_profile_selection(
            [("level", entry)],
            profile,
            {"pointers": 0x8000},
            {"prg": prg, "chr": b"", "DATA2": payload},
        )[0][1]
        self.assertEqual(
            [stream["name"] for stream in resolved["streams"]],
            ["ground_1", "ground_2", "ground_3"],
        )
        candidates = {
            "prg": bytearray(prg),
            "chr": bytearray(),
            "DATA2": bytearray(payload),
        }
        scatter_virtual_streams(
            resolved,
            bytes([0x02, 0x02, 0xFD, 0x01, 0x01, 0xFD, 0x02, 0x02, 0xFD]),
            candidates,
        )
        self.assertEqual(candidates["DATA2"], bytearray([2, 2, 0xFD, 1, 1, 0xFD]))
        with self.assertRaisesRegex(ValueError, "shared stream"):
            scatter_virtual_streams(
                resolved,
                bytes([0, 0, 0xFD, 1, 1, 0xFD, 2, 2, 0xFD]),
                candidates,
            )

    def test_profile_can_select_additional_studio_artifacts(self) -> None:
        entries = {name: {"id": name} for name in ("normal", "extended")}
        studios = {"level": {"artifacts": ["normal"]}}
        selection = selected_entries(
            entries,
            studios,
            ["level"],
            {"level": ["normal", "extended"]},
        )
        self.assertEqual([entry["id"] for _studio, entry in selection], ["normal", "extended"])

    def test_unmodified_image_requires_profile_identity(self) -> None:
        profile = {
            "id": "test",
            "image_size": 3,
            "image_sha1": "a9993e364706816aba3e25717850c26c9cd0d89d",
        }
        validate_unmodified_image(profile, b"abc", 0)
        with self.assertRaisesRegex(ValueError, "SHA1 differs"):
            validate_unmodified_image(profile, b"abd", 0)
        validate_unmodified_image(profile, b"edited", 1)


if __name__ == "__main__":
    unittest.main()
