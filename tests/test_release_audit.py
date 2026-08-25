from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from release_audit import validate_hash_contracts, validate_roadmap  # noqa: E402


class ReleaseAuditTests(unittest.TestCase):
    def test_hash_contract_accepts_matching_manifests(self) -> None:
        release = {
            "reference": {
                "rom_sha1": "rom", "prg_sha1": "prg", "chr_sha1": "chr",
                "mapper": 0, "mirroring": "vertical",
            },
            "evidence": {"movie_sha1": "movie"},
        }
        assets = {"reference_rom": {
            "sha1": "rom", "prg_sha1": "prg", "chr_sha1": "chr",
            "mapper": 0, "mirroring": "vertical",
        }}
        runtime = {"rom_sha1": "rom", "movie_sha1": "movie"}
        self.assertEqual(validate_hash_contracts(release, assets, runtime), [])

    def test_roadmap_requires_every_milestone_through_nine(self) -> None:
        text = "\n".join(f"### {number}. Milestone - Complete" for number in range(9))
        self.assertEqual(validate_roadmap(text), ["roadmap milestone 9 is not Complete"])


if __name__ == "__main__":
    unittest.main()
