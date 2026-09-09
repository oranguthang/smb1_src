#!/usr/bin/env python3
"""Audit the active Source Reconstruction 3.0 development contract."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any

from authoring.content_profiles import validate_profiles
from validation.make_contract import combined_makefile_text


EXPECTED_MILESTONES = [
    "relocation_architecture",
    "canonical_relocation",
    "revision_relocation",
    "platform_relocation",
    "platform_interfaces",
    "semantic_runtime_evidence",
    "scoring_runtime_evidence",
    "profile_aware_authoring",
    "later_engine_feasibility",
    "smb2_architecture",
    "smb2_identity_build",
    "smb2_source_reconstruction",
    "smb2_runtime_relocation",
    "smb2_authoring",
    "source_reconstruction_3_0",
]

EXPECTED_REQUIREMENTS = {
    "canonical_identity",
    "accepted_profile_identity",
    "runtime_coverage",
    "relocation_architecture",
    "semantic_runtime_evidence",
    "profile_aware_authoring",
    "toolchain_reproducibility",
    "licensing_and_provenance",
    "aggregate_release_gate",
}

EXPECTED_PROFILES = [
    "ju",
    "pc10",
    "pal",
    "vs_smb",
    "fds_smb",
    "ann_fds",
    "smb2_jp_fds",
]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def git_output(project_root: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=project_root,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.stdout.strip()


def make_target_name(command: str) -> str:
    parts = command.split()
    if parts and parts[0] == "make":
        parts = parts[1:]
    return parts[0] if parts else ""


def make_targets(makefile: str) -> set[str]:
    return set(re.findall(r"^([A-Za-z0-9_.-]+)\s*:", makefile, re.MULTILINE))


def validate_contract_metadata(
    project_root: Path,
    release: dict[str, Any],
    makefile: str,
) -> list[str]:
    errors: list[str] = []
    if release.get("release_line") != "3.0":
        errors.append("Source 3.0 release line differs")
    if release.get("release") != "Source Reconstruction 3.0":
        errors.append("Source 3.0 release name differs")
    if release.get("release_kind") != "optional_advanced_generation":
        errors.append("Source 3.0 release kind differs")

    included = release.get("included_scope", [])
    if len(included) != len(set(included)) or not included:
        errors.append("Source 3.0 included scope is empty or duplicated")
    excluded = release.get("excluded_scope", [])
    excluded_ids = [item.get("id") for item in excluded]
    if len(excluded_ids) != len(set(excluded_ids)) or any(
        not item.get("reason") or item.get("status") not in {"unsupported", "not_applicable"}
        for item in excluded
    ):
        errors.append("Source 3.0 excluded scope lacks unique IDs, status, or reasons")
    delta = release.get("delta", [])
    delta_ids = [item.get("id") for item in delta]
    if len(delta_ids) != len(set(delta_ids)) or any(
        not item.get("summary") or not item.get("evidence") for item in delta
    ):
        errors.append("Source 3.0 delta lacks unique IDs, summaries, or evidence")
    for item in delta:
        for relative in item.get("evidence", []):
            if not (project_root / relative).exists():
                errors.append(f"Source 3.0 delta evidence is missing: {relative}")

    requirements = release.get("requirements", {})
    if set(requirements) != EXPECTED_REQUIREMENTS:
        errors.append("Source 3.0 requirement set differs")
    targets = make_targets(makefile)
    for identifier, requirement in requirements.items():
        if requirement.get("status") != "satisfied":
            errors.append(f"Source 3.0 requirement is not satisfied: {identifier}")
        evidence = requirement.get("evidence", {})
        if not evidence:
            errors.append(f"Source 3.0 requirement lacks evidence: {identifier}")
        for command in evidence.get("targets", []):
            target = make_target_name(command)
            if target not in targets:
                errors.append(f"Source 3.0 evidence target is missing: {target}")
        for field in ("manifests", "documents"):
            for relative in evidence.get(field, []):
                if not (project_root / relative).is_file():
                    errors.append(f"Source 3.0 evidence file is missing: {relative}")

    profile_sources: dict[str, tuple[str, int, str]] = {}
    for relative in (
        "config/revision_profiles.json",
        "config/platform_profiles.json",
        "config/smb2_platform_profile.json",
    ):
        document = load_json(project_root / relative)
        entries = document.get("supported", document.get("profiles", []))
        for profile in entries:
            size = profile.get("rom_size", profile.get("disk_size"))
            digest = profile.get("rom_sha1", profile.get("disk_sha1"))
            profile_sources[profile["id"]] = (relative, size, digest)

    profiles = release.get("profiles", [])
    profile_ids = [item.get("id") for item in profiles]
    if profile_ids != EXPECTED_PROFILES:
        errors.append("Source 3.0 accepted profile order or identity differs")
    for profile in profiles:
        identifier = profile.get("id")
        expected = profile_sources.get(identifier)
        actual = (
            profile.get("identity_manifest"),
            profile.get("size"),
            profile.get("sha1"),
        )
        if actual != expected:
            errors.append(f"Source 3.0 artifact identity differs: {identifier}")
        if make_target_name(profile.get("verify_target", "")) not in targets:
            errors.append(f"Source 3.0 profile verify target is missing: {identifier}")

    coverage = release.get("runtime_coverage", [])
    coverage_ids = [item.get("profile") for item in coverage]
    if coverage_ids != EXPECTED_PROFILES:
        errors.append("Source 3.0 runtime coverage profile set differs")
    for item in coverage:
        identifier = item.get("profile")
        kind = item.get("kind")
        if kind == "direct":
            if not item.get("targets"):
                errors.append(f"Source 3.0 direct runtime coverage is empty: {identifier}")
        elif kind == "runtime_equivalent_to":
            if item.get("profile") == item.get("equivalent_to") or item.get("equivalent_to") not in coverage_ids:
                errors.append(f"Source 3.0 runtime equivalence is invalid: {identifier}")
        else:
            errors.append(f"Source 3.0 runtime coverage kind is invalid: {identifier}")
        for command in item.get("targets", []):
            if make_target_name(command) not in targets:
                errors.append(f"Source 3.0 runtime target is missing: {command}")

    artifacts = release.get("artifacts", {})
    if artifacts.get("accepted_profiles") != EXPECTED_PROFILES:
        errors.append("Source 3.0 artifact profile set differs")
    if artifacts.get("generated_root") != "build" or artifacts.get("committed") is not False:
        errors.append("Source 3.0 generated artifact policy differs")

    toolchain = release.get("toolchain", {})
    toolchain_path = project_root / toolchain.get("manifest", "")
    if not toolchain_path.is_file():
        errors.append("Source 3.0 toolchain manifest is missing")
    else:
        document = load_json(toolchain_path)
        if document.get("schema_version") != 1 or document.get("release") != release.get("release"):
            errors.append("Source 3.0 toolchain contract differs")
    if toolchain.get("verification_target") not in targets:
        errors.append("Source 3.0 toolchain verification target is missing")

    gates = release.get("aggregate_gates", {})
    if gates != {
        "release": "source-3-check",
        "pre_tag": "source-3-pre-tag",
        "post_tag": "source-3-post-tag",
    }:
        errors.append("Source 3.0 aggregate gate map differs")
    if any(target not in targets for target in gates.values()):
        errors.append("Source 3.0 aggregate gate target is missing")
    deviations = release.get("layout_deviations", [])
    if [item.get("id") for item in deviations] != ["make_profile_routing"] or any(
        item.get("status") != "accepted"
        or not item.get("reason")
        or not item.get("compensating_control")
        for item in deviations
    ):
        errors.append("Source 3.0 project deviation record differs")

    licensing = release.get("licensing", {})
    if licensing.get("game_source") != "license_not_granted" or licensing.get("private_inputs_committed") is not False:
        errors.append("Source 3.0 licensing boundary differs")
    for relative in (
        licensing.get("status_document", ""),
        *release.get("provenance", {}).values(),
    ):
        if not (project_root / relative).is_file():
            errors.append(f"Source 3.0 licensing or provenance file is missing: {relative}")
    return errors


def release_commits(project_root: Path, predecessor: str) -> list[dict[str, str]]:
    result = subprocess.run(
        [
            "git",
            "log",
            "--reverse",
            "--format=%H%x1f%aI%x1f%cI%x1f%B%x1e",
            f"{predecessor}..HEAD",
        ],
        cwd=project_root,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    commits = []
    for record in result.stdout.split("\x1e"):
        record = record.strip()
        if not record:
            continue
        commit, author_date, commit_date, message = record.split("\x1f", 3)
        commits.append({
            "commit": commit,
            "author_date": author_date,
            "commit_date": commit_date,
            "message": message.strip(),
        })
    return commits


def validate_release_history(project_root: Path, predecessor: str) -> list[str]:
    errors: list[str] = []
    previous_author: datetime | None = None
    previous_commit: datetime | None = None
    commits = release_commits(project_root, predecessor)
    for item in commits:
        message = item["message"]
        parts = re.split(r"\n\s*\n", message)
        subject = parts[0]
        body = [part for part in parts[1:] if not part.startswith("Co-Authored-By:")]
        short = item["commit"][:12]
        if re.search(r"[\u0400-\u052f]", message):
            errors.append(f"release commit message is not English: {short}")
        if len(subject) > 72 or subject.endswith("."):
            errors.append(f"release commit subject is not concise: {short}")
        if len(body) not in {2, 3}:
            errors.append(f"release commit body must contain two or three paragraphs: {short}")
        if "Co-Authored-By: Codex <noreply@openai.com>" not in parts:
            errors.append(f"release commit lacks the Codex co-author trailer: {short}")
        author_date = datetime.fromisoformat(item["author_date"])
        commit_date = datetime.fromisoformat(item["commit_date"])
        if previous_author is not None and author_date <= previous_author:
            errors.append(f"release AuthorDate order is not strictly increasing: {short}")
        if previous_commit is not None and commit_date <= previous_commit:
            errors.append(f"release CommitDate order is not strictly increasing: {short}")
        previous_author = author_date
        previous_commit = commit_date
    if not commits:
        errors.append("Source 3.0 release history is empty")
    return errors


def validate_tag_contract(
    project_root: Path,
    release: dict[str, Any],
    phase: str,
    check_remote: bool,
) -> list[str]:
    errors: list[str] = []
    tag = release.get("tag", "")
    policy = release.get("tag_policy", {})
    try:
        tag_object = git_output(project_root, "rev-parse", f"refs/tags/{tag}")
        tag_type = git_output(project_root, "cat-file", "-t", f"refs/tags/{tag}")
        peeled = git_output(project_root, "rev-list", "-n", "1", tag)
    except subprocess.CalledProcessError:
        tag_object = tag_type = peeled = ""

    if phase == "pre":
        if git_output(project_root, "status", "--porcelain", "--untracked-files=all"):
            errors.append("pre-tag audit requires a clean Git tree")
        branch = git_output(project_root, "branch", "--show-current")
        if not branch.startswith("rewrite/"):
            errors.append("pre-tag rewrite audit must run from a rewrite/* branch")
        if git_output(project_root, "log", "-1", "--format=%s") != "Complete Source Reconstruction 3.0":
            errors.append("pre-tag HEAD is not the Source Reconstruction 3.0 release commit")
        errors.extend(validate_release_history(project_root, release["predecessor"]["commit"]))
        if policy.get("mode") != "unpublished_owner_rewrite":
            if tag_object:
                errors.append(f"future release tag already exists locally: {tag}")
        else:
            if tag_type != "tag":
                errors.append("preserved Source 3.0 tag is not annotated")
            if tag_object != policy.get("existing_tag_object") or peeled != policy.get("preserved_old_target"):
                errors.append("preserved Source 3.0 tag differs from the rewrite policy")
            protected = git_output(project_root, "rev-parse", policy.get("protected_ref", ""))
            if protected != policy.get("preserved_old_target"):
                errors.append("protected main ref no longer preserves the old Source 3.0 target")
    elif phase == "post":
        if git_output(project_root, "status", "--porcelain", "--untracked-files=all"):
            errors.append("post-tag audit requires a clean Git tree")
        if tag_type != "tag":
            errors.append("Source 3.0 release tag is missing or is not annotated")
        head = git_output(project_root, "rev-parse", "HEAD")
        if peeled != head:
            errors.append("Source 3.0 tag does not point to HEAD")
        tag_message = git_output(project_root, "for-each-ref", "--format=%(contents)", f"refs/tags/{tag}")
        if release.get("release", "") not in tag_message:
            errors.append("Source 3.0 annotated tag lacks a release summary")
    else:
        errors.append(f"unsupported tag audit phase: {phase}")

    if check_remote:
        remote = policy.get("remote", "origin")
        result = subprocess.run(
            ["git", "ls-remote", "--tags", remote, f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}"],
            cwd=project_root,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if result.returncode != 0:
            errors.append(f"cannot inspect release tag on remote {remote}")
        else:
            refs = dict(
                line.split("\t", 1)[::-1]
                for line in result.stdout.splitlines()
                if "\t" in line
            )
            remote_object = refs.get(f"refs/tags/{tag}", "")
            remote_peeled = refs.get(f"refs/tags/{tag}^{{}}", "")
            expected_object = tag_object
            expected_peeled = peeled
            if remote_object != expected_object or remote_peeled != expected_peeled:
                errors.append(f"remote release tag differs from local annotated tag: {remote}")
    return errors


def validate_milestones(
    milestones: list[dict[str, str]], status: str
) -> list[str]:
    errors: list[str] = []
    identifiers = [item.get("id") for item in milestones]
    if identifiers != EXPECTED_MILESTONES:
        errors.append("Source 3.0 milestone order or identity differs")
        return errors

    states = [item.get("status") for item in milestones]
    if any(state not in {"planned", "in-progress", "complete"} for state in states):
        errors.append("Source 3.0 milestone status is invalid")
        return errors
    if status == "tag-ready":
        if any(state != "complete" for state in states):
            errors.append("tag-ready Source 3.0 has incomplete milestones")
        return errors

    seen_open = False
    active = 0
    for state in states:
        if state == "complete":
            if seen_open:
                errors.append("completed Source 3.0 milestone follows an open milestone")
                break
        else:
            seen_open = True
        if state == "in-progress":
            active += 1
    if active != 1:
        errors.append("development Source 3.0 requires exactly one active milestone")
    first_open = next(
        (state for state in states if state != "complete"),
        None,
    )
    if first_open != "in-progress":
        errors.append("first open Source 3.0 milestone is not active")
    return errors


def validate_roadmap(text: str, status: str) -> list[str]:
    errors = [
        f"roadmap milestone {number} is not Complete"
        for number in range(15)
        if re.search(
            rf"^### {number}\. .* - Complete$", text, re.MULTILINE
        ) is None
    ]
    expected = "Complete" if status == "tag-ready" else "In Progress"
    if re.search(rf"^### 15\. .* - {expected}$", text, re.MULTILINE) is None:
        errors.append(f"roadmap milestone 15 is not {expected}")
    return errors


def validate_scenario_ids(
    document: dict[str, Any], expected: list[str]
) -> list[str]:
    actual = [scenario.get("id") for scenario in document.get("scenarios", [])]
    if actual != expected:
        return ["Source 3.0 semantic runtime scenario list differs"]
    return []


def validate_resolved_unknowns(text: str, expected: list[str]) -> list[str]:
    errors: list[str] = []
    for identifier in expected:
        match = re.search(
            rf"^### {re.escape(identifier)}\b.*?(?=^### |\Z)",
            text,
            re.MULTILINE | re.DOTALL,
        )
        if match is None or "- **Status:** Resolved" not in match.group(0):
            errors.append(f"semantic evidence unknown is not resolved: {identifier}")
    return errors


def validate_authoring_contract(
    project_root: Path, contract: dict[str, Any]
) -> list[str]:
    format_relative = contract.get("format_manifest", "")
    if not (project_root / format_relative).is_file():
        return ["Source 3.0 content format manifest is missing"]
    relative = contract.get("profile_manifest", "")
    path = project_root / relative
    if not path.is_file():
        return ["Source 3.0 content authoring profile manifest is missing"]
    document = load_json(path)
    errors = validate_profiles(document)
    if errors:
        return [f"content authoring contract: {error}" for error in errors]

    if document["default_profile"] != contract.get("default_profile"):
        errors.append("Source 3.0 default content authoring profile differs")
    if document["studio_ids"] != contract.get("studio_ids"):
        errors.append("Source 3.0 content authoring studio list differs")
    supported = [
        profile["id"]
        for profile in document["profiles"]
        if profile["status"] == "supported"
    ]
    planned = [
        profile["id"]
        for profile in document["profiles"]
        if profile["status"] == "planned"
    ]
    partial = [
        profile["id"]
        for profile in document["profiles"]
        if profile["status"] == "partial"
    ]
    if supported != contract.get("supported_profiles"):
        errors.append("Source 3.0 supported content profile list differs")
    if planned != contract.get("planned_profiles"):
        errors.append("Source 3.0 planned content profile list differs")
    if partial != contract.get("partial_profiles"):
        errors.append("Source 3.0 partial content profile list differs")
    return errors


def validate_later_engine_contract(
    project_root: Path, contract: dict[str, Any]
) -> list[str]:
    relative = contract.get("feasibility_manifest", "")
    path = project_root / relative
    if not path.is_file():
        return ["Source 3.0 later-engine feasibility manifest is missing"]
    document = load_json(path)
    decision = document.get("decision", {})
    expected = {
        "subject": document.get("subject"),
        "classification": decision.get("classification"),
        "source_3_scope": decision.get("source_3_scope"),
        "shared_profile": decision.get("shared_profile"),
        "future_boundary": decision.get("future_boundary"),
    }
    actual = {field: contract.get(field) for field in expected}
    if actual != expected:
        return ["Source 3.0 later-engine decision differs from its evidence manifest"]
    if actual != {
        "subject": "smb2_jp_fds",
        "classification": "later-engine-sibling",
        "source_3_scope": "sibling-reconstruction",
        "shared_profile": False,
        "future_boundary": "smb2-owned-source",
    }:
        return ["Source 3.0 later-engine sibling boundary differs"]
    return []


def validate_smb2_contract(project_root: Path, contract: dict[str, Any]) -> list[str]:
    relative = contract.get("reconstruction_manifest", "")
    path = project_root / relative
    if not path.is_file():
        return ["Source 3.0 SMB2 reconstruction manifest is missing"]
    document = load_json(path)
    if document.get("schema_version") != 1 or document.get("id") != "smb2_jp_fds":
        return ["Source 3.0 SMB2 reconstruction identity differs"]
    if document.get("status") != "source-ready":
        return ["Source 3.0 SMB2 source is not ready"]
    if contract.get("profile") != document["id"]:
        return ["Source 3.0 SMB2 profile differs from its reconstruction manifest"]
    if contract.get("source_roots") != document.get("source_roots"):
        return ["Source 3.0 SMB2 source boundary differs"]
    if contract.get("shared_profile") is not False:
        return ["Source 3.0 SMB2 must remain a sibling engine"]
    complexity = document.get("complexity_contract", {})
    expected = {
        "existing_smb1_smb2_conditionals": 0,
        "executable_incbin": False,
        "shared_code_requires_independent_equivalence": True,
        "payloads_build_independently": True,
        "source_2_files_may_change": False,
    }
    if complexity != expected:
        return ["Source 3.0 SMB2 complexity boundary differs"]
    if len(document.get("payloads", [])) != 4:
        return ["Source 3.0 SMB2 program payload set differs"]
    source_build = document.get("source_build", {})
    expected_order = ["SM2MAIN", "SM2DATA2", "SM2DATA3", "SM2DATA4"]
    if source_build.get("payload_order") != expected_order:
        return ["Source 3.0 SMB2 source payload order differs"]
    if source_build.get("combined_size") != sum(
        int(payload["size"]) for payload in document["payloads"]
    ):
        return ["Source 3.0 SMB2 combined source size differs"]
    if any(
        source_build.get(field) != value
        for field, value in {
            "build_target": "build-smb2-source",
            "payload_verify_target": "verify-smb2-source",
            "image_verify_target": "verify-smb2",
        }.items()
    ):
        return ["Source 3.0 SMB2 source targets differ"]
    for field in (
        "aggregate_source",
        "linker_config",
        "build_script",
        "provenance_manifest",
        "import_script",
    ):
        if not (project_root / source_build.get(field, "")).is_file():
            return [f"Source 3.0 SMB2 {field} is missing"]
    for payload in document["payloads"]:
        if not (project_root / payload.get("source", "")).is_file():
            return [f"Source 3.0 SMB2 payload source is missing: {payload.get('name')}"]
    provenance = load_json(project_root / source_build["provenance_manifest"])
    if provenance.get("schema_version") != 1:
        return ["Source 3.0 SMB2 provenance schema differs"]
    smb2_provenance = provenance.get("registries", {}).get("smb2", provenance)
    if smb2_provenance.get("counts", {}).get("labels") != len(
        [
            item
            for item in smb2_provenance.get("renames", [])
            if item.get("kind") == "label"
        ]
    ):
        return ["Source 3.0 SMB2 provenance label count differs"]
    platform_path = project_root / document.get("platform_manifest", "")
    if not platform_path.is_file():
        return ["Source 3.0 SMB2 platform manifest is missing"]
    platform_document = load_json(platform_path)
    profiles = platform_document.get("profiles", [])
    if len(profiles) != 1 or profiles[0].get("id") != document["id"]:
        return ["Source 3.0 SMB2 platform identity differs"]
    platform_payloads = profiles[0].get("verified_payloads", [])
    source_payloads = document["payloads"]
    if [item.get("name") for item in platform_payloads] != [
        item.get("name") for item in source_payloads
    ]:
        return ["Source 3.0 SMB2 platform payload set differs"]
    for platform_payload, source_payload in zip(
        platform_payloads, source_payloads, strict=True
    ):
        if any(
            platform_payload.get(field) != source_payload.get(field)
            for field in ("size", "sha1")
        ):
            return ["Source 3.0 SMB2 payload identity differs"]
    errors = []
    source_roots = [project_root / value for value in document["source_roots"]]
    declaration_modules = {
        (project_root / value).resolve()
        for value in document.get("declaration_modules", [])
    }
    actual_declarations: set[Path] = set()
    assembly_root = project_root / "src"
    if assembly_root.is_dir():
        for path in assembly_root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".asm", ".inc"}:
                continue
            text = path.read_text(encoding="utf-8")
            inside_smb2 = any(
                source_root == path.parent or source_root in path.parents
                for source_root in source_roots
            )
            if inside_smb2 and path.suffix.lower() == ".inc":
                actual_declarations.add(path.resolve())
            if inside_smb2 and any(
                part.lower() in {"data2", "data3", "data4"}
                for part in path.relative_to(assembly_root).parts
            ):
                errors.append(f"SMB2 source path uses a physical payload number: {path}")
            if not inside_smb2 and re.search(
                r"^\s*\.(?:if|ifdef|ifndef|elseif).*\bsmb2\b",
                text,
                re.IGNORECASE | re.MULTILINE,
            ):
                errors.append(f"SMB1 source contains an SMB2 conditional: {path}")
            if inside_smb2 and re.search(
                r"^\s*\.incbin\b", text, re.IGNORECASE | re.MULTILINE
            ):
                errors.append(f"SMB2 source hides bytes with incbin: {path}")
            if inside_smb2 and len(text.splitlines()) > 700:
                errors.append(f"SMB2 source module exceeds 700 lines: {path}")
    if actual_declarations != declaration_modules:
        errors.append("SMB2 .inc declaration boundary differs")
    common_root = project_root / document.get("shared_source_root", "")
    common_modules = document.get("common_modules", [])
    for module in common_modules:
        common_path = project_root / module.get("source", "")
        if not common_path.is_file() or common_root not in common_path.parents:
            errors.append(f"Late-FDS common module boundary differs: {common_path}")
            continue
        common_text = common_path.read_text(encoding="utf-8")
        if re.search(
            r"^\s*\.(?:if|ifdef|ifndef|elseif).*\b(?:ann|smb2)\b",
            common_text,
            re.IGNORECASE | re.MULTILINE,
        ):
            errors.append(f"Late-FDS common module contains a revision branch: {common_path}")
        if re.search(r"^\s*\.incbin\b", common_text, re.IGNORECASE | re.MULTILINE):
            errors.append(f"Late-FDS common module hides bytes with incbin: {common_path}")
        common_include = common_path.relative_to(common_root.parent).as_posix()
        for consumer_value in module.get("consumer_sources", []):
            consumer_path = project_root / consumer_value
            if not consumer_path.is_file():
                errors.append(f"Late-FDS common consumer is missing: {consumer_path}")
                continue
            consumer_text = consumer_path.read_text(encoding="utf-8")
            if common_include not in consumer_text.replace("\\", "/"):
                errors.append(
                    f"Late-FDS common consumer omits {common_include}: {consumer_path}"
                )
    return errors


def validate_source_3(
    project_root: Path,
    manifest_path: Path,
    require_ready: bool = False,
) -> list[str]:
    release = load_json(manifest_path)
    errors: list[str] = []
    status = release.get("status")
    if release.get("schema_version") != 2:
        errors.append("Source Reconstruction 3.0 manifest is not schema 2")
    if status not in {"development", "tag-ready"}:
        errors.append("Source Reconstruction 3.0 status is invalid")
        return errors
    if require_ready and status != "tag-ready":
        errors.append("Source Reconstruction 3.0 manifest is not tag-ready")
    if status == "tag-ready" and release.get("tag") != "source-reconstruction-3.0":
        errors.append("Source Reconstruction 3.0 release tag differs")

    predecessor = release["predecessor"]
    predecessor_manifest = load_json(project_root / predecessor["manifest"])
    if predecessor_manifest.get("tag") != predecessor["tag"]:
        errors.append("Source 3.0 predecessor tag disagrees with the 2.0 manifest")
    if predecessor_manifest.get("status") != "tag-ready":
        errors.append("Source 3.0 predecessor manifest is not tag-ready")
    try:
        target = git_output(
            project_root,
            "rev-parse",
            f"refs/tags/{predecessor['tag']}^{{commit}}",
        )
    except subprocess.CalledProcessError:
        errors.append(f"predecessor tag is missing: {predecessor['tag']}")
    else:
        if target != predecessor["commit"]:
            errors.append("Source 2.0 tag target differs from the 3.0 contract")
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", predecessor["commit"], "HEAD"],
            cwd=project_root,
            check=False,
        )
        if ancestor.returncode != 0:
            errors.append("Source Reconstruction 2.0 is not an ancestor of HEAD")

    makefile = combined_makefile_text(project_root)
    errors.extend(validate_contract_metadata(project_root, release, makefile))
    errors.extend(validate_milestones(release["milestones"], status))
    relocation = release["relocation"]
    expected_layout = {
        "cpu_range": {"start": "0x8000", "end": "0xffff"},
        "fixed_audio": {"start": "0xf2d0", "end": "0xfeff"},
        "fixed_tail": {"start": "0xff00", "end": "0xffff"},
    }
    for field, expected in expected_layout.items():
        if relocation.get(field) != expected:
            errors.append(f"canonical relocation {field} differs")
    budgets = relocation.get("relocation_budgets", [])
    expected_budgets = [
        ("game_and_rendering", "source-declared-unused", 6),
        ("audio", "decoder-and-runtime-proven", 3),
    ]
    actual_budgets = [
        (item.get("id"), item.get("status"), item.get("insertions"))
        for item in budgets
    ]
    if actual_budgets != expected_budgets:
        errors.append("canonical relocation budgets differ or lack evidence")
    if relocation.get("maximum_insertions") != 9:
        errors.append("canonical relocation insertion budget differs")

    semantic = release.get("semantic_evidence", {})
    enemy_manifest = project_root / semantic.get("enemy_stream_manifest", "")
    unreachable_manifest = project_root / semantic.get(
        "unreachable_code_manifest", ""
    )
    runtime_manifest = project_root / semantic.get("runtime_manifest", "")
    scoring_runtime_manifest = project_root / semantic.get(
        "scoring_runtime_manifest", ""
    )
    if not enemy_manifest.is_file():
        errors.append("Source 3.0 enemy-stream evidence manifest is missing")
    if not unreachable_manifest.is_file():
        errors.append("Source 3.0 unreachable-code evidence manifest is missing")
    if not runtime_manifest.is_file():
        errors.append("Source 3.0 semantic runtime manifest is missing")
    else:
        errors.extend(
            validate_scenario_ids(
                load_json(runtime_manifest),
                semantic.get("runtime_scenarios", []),
            )
        )
    if not scoring_runtime_manifest.is_file():
        errors.append("Source 3.0 scoring runtime manifest is missing")
    else:
        errors.extend(
            validate_scenario_ids(
                load_json(scoring_runtime_manifest),
                semantic.get("scoring_runtime_scenarios", []),
            )
        )
    preservation = load_json(
        project_root / "config" / "preservation_source_1_0.json"
    )
    stable_runtime = load_json(project_root / "scenarios" / "runtime_scenarios.json")
    stable_scenario_count = preservation["evidence"]["runtime_scenarios"]
    if len(stable_runtime.get("scenarios", [])) != stable_scenario_count:
        errors.append("Preservation Source 1.0 runtime scenario count changed")
    errors.extend(
        validate_resolved_unknowns(
            (project_root / "docs" / "unknowns.md").read_text(encoding="utf-8"),
            semantic.get("resolved_unknowns", []),
        )
    )
    errors.extend(validate_authoring_contract(project_root, release.get("authoring", {})))
    errors.extend(
        validate_later_engine_contract(project_root, release.get("later_engine", {}))
    )
    errors.extend(validate_smb2_contract(project_root, release.get("smb2", {})))

    for relative in release["required_documents"]:
        if not (project_root / relative).is_file():
            errors.append(f"required 3.0 document is missing: {relative}")
    for target_name in release["required_stable_targets"]:
        if re.search(
            rf"^{re.escape(target_name)}\s*:", makefile, re.MULTILINE
        ) is None:
            errors.append(f"required stable Make target is missing: {target_name}")
    relocation_manifests = relocation.get("manifests", [])
    if len(relocation_manifests) != 3 or any(
        not (project_root / relative).is_file()
        for relative in relocation_manifests
    ):
        errors.append("revision relocation manifest matrix is incomplete")
    platform_manifests = relocation.get("platform_manifests", [])
    if len(platform_manifests) != 3 or any(
        not (project_root / relative).is_file()
        for relative in platform_manifests
    ):
        errors.append("platform relocation manifest matrix is incomplete")
    for target_name in release["required_development_targets"]:
        if re.search(
            rf"^{re.escape(target_name)}\s*:", makefile, re.MULTILINE
        ) is None:
            errors.append(f"required development Make target is missing: {target_name}")
    errors.extend(
        validate_roadmap(
            (project_root / "docs" / "roadmap.md").read_text(encoding="utf-8"),
            status,
        )
    )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parents[2]
        / "config"
        / "source_reconstruction_3_0.json",
    )
    parser.add_argument(
        "--require-ready",
        action="store_true",
        help="fail unless every milestone and the release manifest are tag-ready",
    )
    parser.add_argument(
        "--tag-phase",
        choices=("pre", "post"),
        help="also enforce the local pre-tag or post-tag contract",
    )
    parser.add_argument(
        "--check-remote",
        action="store_true",
        help="compare the annotated release tag with the configured remote",
    )
    args = parser.parse_args()
    errors = validate_source_3(
        args.project_root.resolve(),
        args.manifest.resolve(),
        args.require_ready,
    )
    if not errors and args.tag_phase:
        errors.extend(
            validate_tag_contract(
                args.project_root.resolve(),
                load_json(args.manifest.resolve()),
                args.tag_phase,
                args.check_remote,
            )
        )
    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        print(f"[FAIL] Source Reconstruction 3.0 audit found {len(errors)} error(s)")
        return 1
    print("[OK] Source Reconstruction 3.0 boundary and milestones agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
