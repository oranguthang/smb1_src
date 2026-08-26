from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from content_studio import (
    atomic_write_json,
    load_format_manifest,
    load_workspace_chr,
    write_workspace_documents,
    encode_workspace_document,
)


class ContentStudioTests(unittest.TestCase):
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
                bytes([1, 2]),
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


if __name__ == "__main__":
    unittest.main()
