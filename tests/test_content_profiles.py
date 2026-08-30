from __future__ import annotations

import copy
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

from content_profiles import load_profiles, profile_by_id, require_supported, validate_profiles


class ContentProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.document = load_profiles(
            PROJECT_ROOT / "config" / "content_authoring_profiles.json"
        )

    def test_project_manifest_is_valid(self) -> None:
        self.assertEqual(validate_profiles(self.document), [])

    def test_default_profile_must_be_supported(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "ann_fds")["status"] = "partial"
        document["default_profile"] = "ann_fds"
        self.assertIn(
            "default content authoring profile is not supported",
            validate_profiles(document),
        )

    def test_supported_profile_cannot_retain_a_blocker(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "ju")["blockers"] = ["not actually ready"]
        self.assertIn(
            "supported profile retains blockers: ju",
            validate_profiles(document),
        )

    def test_unknown_profile_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "profile not found"):
            profile_by_id(self.document, "unknown")

    def test_ann_profile_accepts_each_studio(self) -> None:
        for studio in self.document["studio_ids"]:
            self.assertEqual(
                require_supported(self.document, "ann_fds", studio)["id"],
                "ann_fds",
            )

    def test_supported_profile_accepts_each_studio(self) -> None:
        for studio in self.document["studio_ids"]:
            self.assertEqual(require_supported(self.document, "ju", studio)["id"], "ju")

    def test_supported_fds_profile_requires_disjoint_record_sets(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "fds_smb")["chr_record_ids"] = [4]
        self.assertIn(
            "overlapping FDS record IDs: fds_smb",
            validate_profiles(document),
        )

    def test_ann_profile_declares_each_fixed_program_payload(self) -> None:
        profile = profile_by_id(self.document, "ann_fds")
        self.assertEqual(
            [entry["payload"] for entry in profile["program_payloads"]],
            ["prg", "NSMDATA2", "NSMDATA3", "NSMDATA4"],
        )
        self.assertEqual(profile["chr_source"], "fds_records")

    def test_ann_profile_declares_its_level_rendering_layout(self) -> None:
        rendering = profile_by_id(self.document, "ann_fds")["level_rendering"]
        self.assertEqual(rendering["metatile_group_starts"], [0, 39, 86, 96])
        self.assertEqual(rendering["metatile_group_sizes"], [39, 47, 10, 6])
        self.assertEqual(rendering["terrain_metatiles"][1], "0x6a")
        self.assertEqual(rendering["residual_flag_metatile"], "0x6e")
        self.assertTrue(rendering["upside_down_pipes"])
        self.assertEqual(rendering["small_object_table"], "ann")

    def test_level_rendering_groups_must_be_contiguous(self) -> None:
        document = copy.deepcopy(self.document)
        rendering = profile_by_id(document, "ann_fds")["level_rendering"]
        rendering["metatile_group_starts"][2] = 85
        self.assertIn(
            "invalid level rendering layout: ann_fds",
            validate_profiles(document),
        )

    def test_level_rendering_rejects_unknown_small_object_table(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "ann_fds")["level_rendering"][
            "small_object_table"
        ] = "late_fds"
        self.assertIn(
            "invalid level rendering layout: ann_fds",
            validate_profiles(document),
        )

    def test_fds_program_mapping_requires_known_unique_payloads(self) -> None:
        document = copy.deepcopy(self.document)
        profile = profile_by_id(document, "ann_fds")
        profile["program_payloads"][1]["payload"] = "UNKNOWN"
        self.assertIn(
            "invalid FDS program payloads: ann_fds",
            validate_profiles(document),
        )

    def test_payload_contract_requires_a_valid_hash(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "ann_fds")["payloads"]["NSMDATA2"]["sha1"] = "bad"
        self.assertIn(
            "invalid payload contract: ann_fds/NSMDATA2",
            validate_profiles(document),
        )

    def test_ann_course_banks_keep_explicit_payload_ownership(self) -> None:
        profile = profile_by_id(self.document, "ann_fds")
        self.assertEqual(len(profile["stream_payload_maps"]["normal"]), 45)
        self.assertEqual(len(profile["stream_payload_maps"]["extended"]), 21)
        self.assertEqual(
            [bank["id"] for bank in profile["studio_banks"]["level"]],
            ["normal", "extended"],
        )
        self.assertEqual(
            profile["studio_banks"]["level"][1]["playtest"],
            {"loader": "ann_extended"},
        )

    def test_smb2_profile_owns_normal_and_hard_course_payloads(self) -> None:
        profile = profile_by_id(self.document, "smb2_jp_fds")
        self.assertEqual(
            [entry["payload"] for entry in profile["program_payloads"]],
            ["prg", "SM2DATA2", "SM2DATA3", "SM2DATA4"],
        )
        self.assertEqual(len(profile["stream_payload_maps"]["normal"]), 52)
        self.assertEqual(len(profile["stream_payload_maps"]["hard"]), 21)
        self.assertEqual(
            [bank["id"] for bank in profile["studio_banks"]["level"]],
            ["normal", "hard"],
        )
        self.assertEqual(
            profile["studio_banks"]["level"][0]["unused_areas"],
            ["ground_24", "ground_26", "ground_27"],
        )
        for studio in self.document["studio_ids"]:
            self.assertEqual(
                require_supported(self.document, "smb2_jp_fds", studio)["id"],
                "smb2_jp_fds",
            )

    def test_only_smb2_declares_unused_level_slots(self) -> None:
        declarations = {
            profile["id"]: [
                name
                for bank in profile.get("studio_banks", {}).get("level", [])
                for name in bank.get("unused_areas", [])
            ]
            for profile in self.document["profiles"]
        }
        self.assertEqual(
            {profile: names for profile, names in declarations.items() if names},
            {
                "smb2_jp_fds": [
                    "ground_24", "ground_26", "ground_27",
                ],
            },
        )

    def test_smb2_profile_declares_its_later_engine_rendering_tables(self) -> None:
        rendering = profile_by_id(self.document, "smb2_jp_fds")["level_rendering"]
        self.assertEqual(rendering["metatile_group_starts"], [0, 36, 84, 97])
        self.assertEqual(rendering["metatile_group_sizes"], [36, 48, 13, 7])
        self.assertEqual(rendering["small_object_table"], "smb2")
        self.assertEqual(rendering["side_pipe_top_metatiles"][0], "0x19")
        self.assertEqual(
            rendering["secondary_ledge_metatiles"], ["0x8a", "0x8b", "0x8c"]
        )
        self.assertEqual(rendering["secondary_ledge_support_metatiles"], [])
        self.assertEqual(rendering["flagpole_metatiles"], ["0x21", "0x22", "0x62"])
        self.assertTrue(rendering["upside_down_pipes"])

    def test_level_bank_rejects_an_unknown_playtest_loader(self) -> None:
        document = copy.deepcopy(self.document)
        bank = profile_by_id(document, "ann_fds")["studio_banks"]["level"][1]
        bank["playtest"] = {"loader": "guess"}
        self.assertIn(
            "invalid bank playtest contract: ann_fds/extended",
            validate_profiles(document),
        )

    def test_level_bank_rejects_duplicate_unused_areas(self) -> None:
        document = copy.deepcopy(self.document)
        bank = profile_by_id(document, "smb2_jp_fds")["studio_banks"]["level"][0]
        bank["unused_areas"] = ["ground_24", "ground_24"]
        self.assertIn(
            "invalid unused-area contract: smb2_jp_fds/normal",
            validate_profiles(document),
        )

    def test_stream_payload_map_rejects_an_unknown_owner(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "ann_fds")["stream_payload_maps"]["normal"][0] = "BAD"
        self.assertIn(
            "invalid stream payload map: ann_fds/normal",
            validate_profiles(document),
        )

    def test_loader_rejects_duplicate_json_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profiles.json"
            path.write_text('{"schema_version": 1, "schema_version": 1}\n')
            with self.assertRaisesRegex(ValueError, "duplicate JSON key: schema_version"):
                load_profiles(path)

    def test_vs_profile_requires_a_bounded_chr_editable_range(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "vs_smb")["chr_layout"]["editable_size"] = 16385
        self.assertIn("invalid CHR layout: vs_smb", validate_profiles(document))

    def test_vs_profile_requires_a_valid_ppu_contract(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "vs_smb")["ppu"]["nes2_vs_ppu_id"] = 16
        self.assertIn("invalid PPU contract: vs_smb", validate_profiles(document))

    def test_vs_external_stream_override_requires_a_chr_bank(self) -> None:
        document = copy.deepcopy(self.document)
        override = profile_by_id(document, "vs_smb")["artifact_overrides"][
            "area_object_streams"
        ]
        del override["bank_offset"]
        self.assertIn(
            "invalid external stream override: vs_smb/area_object_streams",
            validate_profiles(document),
        )

    def test_profile_playtest_values_are_bounded(self) -> None:
        document = copy.deepcopy(self.document)
        profile_by_id(document, "vs_smb")["playtest"]["game_mode"] = 256
        self.assertIn("invalid playtest game_mode: vs_smb", validate_profiles(document))


if __name__ == "__main__":
    unittest.main()
