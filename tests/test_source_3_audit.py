from __future__ import annotations

import sys
import tempfile
import unittest
import json
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from source_3_audit import (
    EXPECTED_MILESTONES,
    validate_milestones,
    validate_authoring_contract,
    validate_later_engine_contract,
    validate_smb2_contract,
    validate_resolved_unknowns,
    validate_roadmap,
    validate_scenario_ids,
)


def milestones(*states: str) -> list[dict[str, str]]:
    return [
        {"id": identifier, "status": state}
        for identifier, state in zip(EXPECTED_MILESTONES, states, strict=True)
    ]


class Source3AuditTests(unittest.TestCase):
    def test_development_allows_one_active_milestone_after_complete_prefix(self) -> None:
        states = ["complete", "complete", "in-progress"]
        states.extend(["planned"] * (len(EXPECTED_MILESTONES) - len(states)))
        self.assertEqual(validate_milestones(milestones(*states), "development"), [])

    def test_development_rejects_multiple_active_milestones(self) -> None:
        states = ["in-progress", "in-progress"]
        states.extend(["planned"] * (len(EXPECTED_MILESTONES) - len(states)))
        self.assertIn(
            "development Source 3.0 requires exactly one active milestone",
            validate_milestones(milestones(*states), "development"),
        )

    def test_roadmap_keeps_stable_history_complete(self) -> None:
        text = "\n".join(
            [
                *(f"### {number}. Milestone - Complete" for number in range(15)),
                "### 15. Milestone - In Progress",
            ]
        )
        self.assertEqual(validate_roadmap(text, "development"), [])

    def test_semantic_scenario_order_is_manifest_owned(self) -> None:
        document = {"scenarios": [{"id": "time-up-clear"}]}
        self.assertEqual(validate_scenario_ids(document, ["time-up-clear"]), [])
        self.assertTrue(validate_scenario_ids(document, ["different-scenario"]))

    def test_resolved_unknowns_require_registry_status(self) -> None:
        text = """### DATA-001 TIME UP clear packet

- **Status:** Resolved

### RAM-001 Sprite control

- **Status:** Open
"""
        self.assertEqual(validate_resolved_unknowns(text, ["DATA-001"]), [])
        self.assertTrue(validate_resolved_unknowns(text, ["RAM-001"]))

    def test_authoring_contract_rejects_manifest_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {
                "schema_version": 1,
                "default_profile": "ju",
                "studio_ids": ["world", "level", "graphics", "sound"],
                "profiles": [],
            }
            (root / "profiles.json").write_text(
                json.dumps(manifest), encoding="utf-8"
            )
            errors = validate_authoring_contract(
                root,
                {
                    "profile_manifest": "profiles.json",
                    "default_profile": "ju",
                    "studio_ids": ["world", "level", "graphics", "sound"],
                    "supported_profiles": ["ju"],
                    "partial_profiles": [],
                    "planned_profiles": [],
                },
            )
            self.assertTrue(errors)

    def test_later_engine_contract_rejects_a_shared_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {
                "subject": "smb2_jp_fds",
                "decision": {
                    "classification": "later-engine-sibling",
                    "source_3_scope": "sibling-reconstruction",
                    "shared_profile": False,
                    "future_boundary": "smb2-owned-source",
                },
            }
            (root / "later.json").write_text(
                json.dumps(manifest), encoding="utf-8"
            )
            contract = {
                "feasibility_manifest": "later.json",
                "subject": "smb2_jp_fds",
                **manifest["decision"],
            }
            self.assertEqual(validate_later_engine_contract(root, contract), [])
            contract["shared_profile"] = True
            self.assertTrue(validate_later_engine_contract(root, contract))

    def test_smb2_contract_rejects_engine_conditionals_in_smb1(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {
                "schema_version": 1,
                "id": "smb2_jp_fds",
                "status": "source-ready",
                "source_root": "src/smb2",
                "platform_manifest": "platform.json",
                "payloads": [
                    {
                        "name": name,
                        "size": 1,
                        "sha1": name.lower(),
                        "source": f"src/smb2/{name.lower()}.asm",
                    }
                    for name in ("SM2MAIN", "SM2DATA2", "SM2DATA3", "SM2DATA4")
                ],
                "source_build": {
                    "aggregate_source": "src/smb2/build.asm",
                    "linker_config": "smb2.cfg",
                    "build_script": "build_smb2.py",
                    "provenance_manifest": "smb2_labels.json",
                    "import_script": "import_smb2.py",
                    "combined_size": 4,
                    "payload_order": ["SM2MAIN", "SM2DATA2", "SM2DATA3", "SM2DATA4"],
                    "build_target": "build-smb2-source",
                    "payload_verify_target": "verify-smb2-source",
                    "image_verify_target": "verify-smb2",
                },
                "complexity_contract": {
                    "existing_smb1_smb2_conditionals": 0,
                    "executable_incbin": False,
                    "shared_code_requires_independent_equivalence": True,
                    "payloads_build_independently": True,
                    "source_2_files_may_change": False,
                },
            }
            (root / "smb2.json").write_text(json.dumps(manifest), encoding="utf-8")
            (root / "platform.json").write_text(
                json.dumps({
                    "profiles": [{
                        "id": "smb2_jp_fds",
                        "verified_payloads": manifest["payloads"],
                    }]
                }),
                encoding="utf-8",
            )
            (root / "src" / "smb2").mkdir(parents=True)
            for payload in manifest["payloads"]:
                (root / payload["source"]).write_text("", encoding="utf-8")
            (root / "src" / "smb2" / "build.asm").write_text("", encoding="utf-8")
            for filename in ("smb2.cfg", "build_smb2.py", "import_smb2.py"):
                (root / filename).write_text("", encoding="utf-8")
            (root / "smb2_labels.json").write_text(
                json.dumps({
                    "schema_version": 1,
                    "counts": {"labels": 0},
                    "renames": [],
                }),
                encoding="utf-8",
            )
            contract = {
                "reconstruction_manifest": "smb2.json",
                "source_root": "src/smb2",
                "profile": "smb2_jp_fds",
                "shared_profile": False,
            }
            self.assertEqual(validate_smb2_contract(root, contract), [])
            (root / "src" / "main.asm").write_text(
                ".if SMB2\n.endif\n", encoding="utf-8"
            )
            self.assertTrue(validate_smb2_contract(root, contract))


if __name__ == "__main__":
    unittest.main()
