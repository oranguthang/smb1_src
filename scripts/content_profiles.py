#!/usr/bin/env python3
"""Validate and inspect manifest-owned content authoring profiles."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


EXPECTED_PROFILE_IDS = ("ju", "pc10", "pal", "vs_smb", "fds_smb", "ann_fds")
EXPECTED_STUDIO_IDS = ("world", "level", "graphics", "sound")
PROFILE_STATES = {"supported", "partial", "planned"}
STUDIO_STATES = {"supported", "planned", "unsupported"}


def valid_sha1(value: object) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_profiles(path: Path) -> dict[str, Any]:
    document = json.loads(
        path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_keys
    )
    errors = validate_profiles(document)
    if errors:
        raise ValueError("; ".join(errors))
    return document


def validate_profiles(document: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if document.get("schema_version") != 1:
        errors.append("content authoring profile manifest is not schema 1")
        return errors
    if tuple(document.get("studio_ids", [])) != EXPECTED_STUDIO_IDS:
        errors.append("content authoring studio identity or order differs")

    profiles = document.get("profiles", [])
    identifiers = [profile.get("id") for profile in profiles]
    if tuple(identifiers) != EXPECTED_PROFILE_IDS:
        errors.append("content authoring profile identity or order differs")
    if len(set(identifiers)) != len(identifiers):
        errors.append("content authoring profile identifiers are not unique")

    default = document.get("default_profile")
    by_id = {profile.get("id"): profile for profile in profiles}
    if default not in by_id:
        errors.append("default content authoring profile is missing")
    elif by_id[default].get("status") != "supported":
        errors.append("default content authoring profile is not supported")

    for profile in profiles:
        identifier = profile.get("id", "<missing>")
        status = profile.get("status")
        if status not in PROFILE_STATES:
            errors.append(f"invalid content profile status: {identifier}")
        baseline = profile.get("baseline", {})
        if baseline.get("kind") not in {"revision", "platform"}:
            errors.append(f"invalid baseline kind: {identifier}")
        if baseline.get("profile") != identifier:
            errors.append(f"baseline profile differs: {identifier}")
        try:
            load_address = int(str(baseline.get("load_address")), 0)
        except (TypeError, ValueError):
            errors.append(f"invalid load address: {identifier}")
        else:
            if load_address not in {0x6000, 0x8000}:
                errors.append(f"unsupported load address: {identifier}")

        studios = profile.get("studios", {})
        if tuple(studios) != EXPECTED_STUDIO_IDS:
            errors.append(f"studio matrix differs: {identifier}")
        if any(state not in STUDIO_STATES for state in studios.values()):
            errors.append(f"invalid studio state: {identifier}")
        blockers = profile.get("blockers", [])
        if status == "supported":
            if blockers:
                errors.append(f"supported profile retains blockers: {identifier}")
            if any(state != "supported" for state in studios.values()):
                errors.append(f"supported profile has unavailable studios: {identifier}")
        elif status == "partial":
            if not blockers:
                errors.append(f"partial profile lacks an explicit blocker: {identifier}")
            if not any(state == "supported" for state in studios.values()):
                errors.append(f"partial profile has an invalid Studio matrix: {identifier}")
        else:
            if not blockers:
                errors.append(f"planned profile lacks an explicit blocker: {identifier}")
            if any(state == "supported" for state in studios.values()):
                errors.append(f"planned profile has a supported Studio: {identifier}")

        for field in ("workspace", "output"):
            value = profile.get(field)
            if not isinstance(value, str) or not value.startswith(
                "content/" if field == "workspace" else "build/"
            ):
                errors.append(f"invalid {field} path: {identifier}")
        if not valid_sha1(profile.get("image_sha1")):
            errors.append(f"invalid image SHA-1: {identifier}")
        if not isinstance(profile.get("image_size"), int) or profile["image_size"] <= 0:
            errors.append(f"invalid image size: {identifier}")

        container = profile.get("container", "ines")
        if container not in {"ines", "fds"}:
            errors.append(f"invalid content container: {identifier}")
        for field in ("header_sha1", "chr_sha1"):
            if field in profile and not valid_sha1(profile[field]):
                errors.append(f"invalid {field}: {identifier}")

        layout = profile.get("chr_layout")
        if layout is not None:
            try:
                source_size = int(layout["source_size"])
                editable_offset = int(layout["editable_offset"])
                editable_size = int(layout["editable_size"])
            except (KeyError, TypeError, ValueError):
                errors.append(f"invalid CHR layout: {identifier}")
            else:
                if not (
                    source_size > 0
                    and editable_offset >= 0
                    and editable_size > 0
                    and editable_offset + editable_size <= source_size
                ):
                    errors.append(f"invalid CHR layout: {identifier}")

        payloads = profile.get("payloads", {})
        if not isinstance(payloads, dict):
            errors.append(f"invalid payload contracts: {identifier}")
            payloads = {}
        else:
            for payload_id, contract in payloads.items():
                if payload_id in {"prg", "chr"} or not isinstance(contract, dict):
                    errors.append(f"invalid payload contract: {identifier}/{payload_id}")
                    continue
                try:
                    payload_load_address = int(str(contract["load_address"]), 0)
                    payload_size = int(contract["size"])
                except (KeyError, TypeError, ValueError):
                    errors.append(f"invalid payload contract: {identifier}/{payload_id}")
                    continue
                if (
                    not 0 <= payload_load_address <= 0xFFFF
                    or payload_size <= 0
                    or not valid_sha1(contract.get("sha1"))
                ):
                    errors.append(f"invalid payload contract: {identifier}/{payload_id}")

        chr_source = profile.get("chr_source", "file")
        if chr_source not in {"file", "fds_records"}:
            errors.append(f"invalid CHR source: {identifier}")
        elif chr_source == "fds_records" and container != "fds":
            errors.append(f"FDS record CHR requires an FDS container: {identifier}")

        stream_payload_maps = profile.get("stream_payload_maps", {})
        if not isinstance(stream_payload_maps, dict):
            errors.append(f"invalid stream payload maps: {identifier}")
            stream_payload_maps = {}
        else:
            known_payloads = {"prg", "chr", *payloads}
            for map_id, owners in stream_payload_maps.items():
                if (
                    not isinstance(map_id, str)
                    or not isinstance(owners, list)
                    or not owners
                    or any(owner not in known_payloads for owner in owners)
                ):
                    errors.append(f"invalid stream payload map: {identifier}/{map_id}")

        studio_artifacts = profile.get("studio_artifacts", {})
        if not isinstance(studio_artifacts, dict) or any(
            studio_id not in EXPECTED_STUDIO_IDS
            or not isinstance(artifact_ids, list)
            or not artifact_ids
            or any(not isinstance(value, str) for value in artifact_ids)
            for studio_id, artifact_ids in (
                studio_artifacts.items() if isinstance(studio_artifacts, dict) else []
            )
        ):
            errors.append(f"invalid studio artifact selection: {identifier}")

        studio_banks = profile.get("studio_banks", {})
        if not isinstance(studio_banks, dict):
            errors.append(f"invalid Studio banks: {identifier}")
        else:
            for studio_id, banks in studio_banks.items():
                required_fields = (
                    {"id", "name", "routes"}
                    if studio_id == "world"
                    else {"id", "name", "areas", "enemies", "routes"}
                )
                if (
                    studio_id not in {"world", "level"}
                    or not isinstance(banks, list)
                    or not banks
                    or any(
                        not isinstance(bank, dict)
                        or not required_fields <= set(bank)
                        or any(not isinstance(bank[field], str) for field in required_fields)
                        for bank in banks
                    )
                    or len({bank.get("id") for bank in banks if isinstance(bank, dict)})
                    != len(banks)
                ):
                    errors.append(f"invalid Studio banks: {identifier}/{studio_id}")
                    continue
                if studio_id == "level":
                    for bank in banks:
                        bank_playtest = bank.get("playtest", True)
                        if isinstance(bank_playtest, bool):
                            continue
                        if not (
                            isinstance(bank_playtest, dict)
                            and bank_playtest.get("loader") == "ann_extended"
                            and set(bank_playtest) == {"loader"}
                        ):
                            errors.append(
                                f"invalid bank playtest contract: "
                                f"{identifier}/{bank.get('id')}"
                            )

        playtest = profile.get("playtest")
        if playtest is not None:
            if not isinstance(playtest, dict):
                errors.append(f"invalid playtest contract: {identifier}")
            else:
                for field in ("boot_task", "game_mode", "ready_task"):
                    if field in playtest and not (
                        isinstance(playtest[field], int)
                        and 0 <= playtest[field] <= 0xFF
                    ):
                        errors.append(f"invalid playtest {field}: {identifier}")
                for field in ("boot_frames", "ready_frames"):
                    if field in playtest and not (
                        isinstance(playtest[field], int)
                        and 1 <= playtest[field] <= 3600
                    ):
                        errors.append(f"invalid playtest {field}: {identifier}")

        overrides = profile.get("artifact_overrides", {})
        if not isinstance(overrides, dict):
            errors.append(f"invalid artifact overrides: {identifier}")
            overrides = {}
        else:
            for artifact_id, override in overrides.items():
                if not isinstance(override, dict):
                    errors.append(f"invalid artifact override: {identifier}/{artifact_id}")
                    continue
                if "pointer_table" not in override:
                    continue
                groups = override.get("groups")
                valid_groups = (
                    isinstance(groups, list)
                    and bool(groups)
                    and all(
                        isinstance(group, list)
                        and len(group) == 2
                        and isinstance(group[0], str)
                        and isinstance(group[1], int)
                        and group[1] > 0
                        for group in groups
                    )
                )
                dynamic_map = override.get("pointer_payload_map")
                if dynamic_map is not None:
                    pointer_payload = override.get("pointer_payload", "prg")
                    skipped = override.get("skip_pointer_indices", [])
                    pointer_count = (
                        sum(int(group[1]) for group in groups)
                        if valid_groups else 0
                    )
                    owners = stream_payload_maps.get(dynamic_map, [])
                    if (
                        dynamic_map not in stream_payload_maps
                        or len(owners) != pointer_count
                        or pointer_payload not in {"prg", "chr", *payloads}
                        or not isinstance(override.get("pointer_table"), str)
                        or not valid_groups
                        or not isinstance(skipped, list)
                        or any(
                            not isinstance(value, int)
                            or not 0 <= value < pointer_count
                            for value in skipped
                        )
                        or len(set(skipped)) != len(skipped)
                    ):
                        errors.append(
                            f"invalid pointer stream override: {identifier}/{artifact_id}"
                        )
                elif (
                    override.get("payload") != "chr"
                    or not isinstance(override.get("pointer_table"), str)
                    or not isinstance(override.get("bank_offset"), int)
                    or override["bank_offset"] < 0
                    or not valid_groups
                ):
                    errors.append(
                        f"invalid external stream override: {identifier}/{artifact_id}"
                    )

        if identifier == "vs_smb" and status == "supported":
            if container != "ines":
                errors.append("invalid Vs. container: vs_smb")
            for field in ("header_sha1", "chr_sha1", "chr_layout"):
                if field not in profile:
                    errors.append(f"missing Vs. {field}: vs_smb")
            for artifact_id in ("area_object_streams", "enemy_object_streams"):
                if artifact_id not in overrides:
                    errors.append(f"missing Vs. artifact override: {artifact_id}")

        if container == "fds":
            template = profile.get("template")
            if not isinstance(template, str) or not template.startswith(
                f"assets/generated/platforms/{identifier}/"
            ):
                errors.append(f"invalid FDS template path: {identifier}")
            for field in ("template_sha1", "chr_sha1"):
                if not valid_sha1(profile.get(field)):
                    errors.append(f"invalid FDS {field}: {identifier}")
            program_groups = profile.get("program_payloads")
            if program_groups is None:
                program_groups = [{
                    "payload": "prg",
                    "record_ids": profile.get("program_record_ids"),
                }]
            valid_program_groups = (
                isinstance(program_groups, list)
                and bool(program_groups)
                and all(
                    isinstance(group, dict)
                    and isinstance(group.get("payload"), str)
                    and group["payload"] in {"prg", *payloads}
                    and isinstance(group.get("record_ids"), list)
                    and bool(group["record_ids"])
                    and all(isinstance(value, int) for value in group["record_ids"])
                    for group in program_groups
                )
            )
            if not valid_program_groups:
                errors.append(f"invalid FDS program payloads: {identifier}")
                program_ids = []
            else:
                payload_ids = [group["payload"] for group in program_groups]
                program_ids = [
                    value
                    for group in program_groups
                    for value in group["record_ids"]
                ]
                if (
                    len(set(payload_ids)) != len(payload_ids)
                    or len(set(program_ids)) != len(program_ids)
                ):
                    errors.append(f"duplicate FDS program mapping: {identifier}")
            chr_ids = profile.get("chr_record_ids")
            if (
                not isinstance(chr_ids, list)
                or not chr_ids
                or any(not isinstance(value, int) for value in chr_ids)
                or len(set(chr_ids)) != len(chr_ids)
            ):
                errors.append(f"invalid FDS CHR record IDs: {identifier}")
            if isinstance(program_ids, list) and isinstance(chr_ids, list):
                if set(program_ids) & set(chr_ids):
                    errors.append(f"overlapping FDS record IDs: {identifier}")
    return errors


def profile_by_id(document: dict[str, Any], profile_id: str) -> dict[str, Any]:
    matches = [profile for profile in document["profiles"] if profile["id"] == profile_id]
    if len(matches) != 1:
        raise ValueError(f"content authoring profile not found: {profile_id}")
    return matches[0]


def require_supported(
    document: dict[str, Any], profile_id: str, studio_id: str | None = None
) -> dict[str, Any]:
    profile = profile_by_id(document, profile_id)
    if profile["status"] == "planned":
        blockers = "; ".join(profile["blockers"])
        raise ValueError(f"content authoring profile is not ready: {profile_id}: {blockers}")
    if studio_id is not None:
        if studio_id not in EXPECTED_STUDIO_IDS:
            raise ValueError(f"unknown content studio: {studio_id}")
        if profile["studios"][studio_id] != "supported":
            raise ValueError(
                f"content studio is not supported by {profile_id}: {studio_id}"
            )
    return profile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("audit", "list", "check"))
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--profile")
    parser.add_argument("--studio")
    args = parser.parse_args()
    try:
        document = load_profiles(args.manifest)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[ERROR] {exc}") from exc

    if args.command == "audit":
        print(
            f"[OK] Content authoring contract: {len(document['profiles'])} profiles, "
            f"default {document['default_profile']}"
        )
        return 0

    if args.command == "check":
        if args.profile is None:
            raise SystemExit("[ERROR] check requires --profile")
        try:
            profile = require_supported(document, args.profile, args.studio)
        except ValueError as exc:
            raise SystemExit(f"[ERROR] {exc}") from exc
        print(f"[OK] Content authoring profile is ready: {profile['id']}")
        return 0

    for profile in document["profiles"]:
        studios = ", ".join(
            f"{name}={state}" for name, state in profile["studios"].items()
        )
        print(f"{profile['id']}: {profile['status']} ({studios})")
        for blocker in profile["blockers"]:
            print(f"  blocker: {blocker}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
