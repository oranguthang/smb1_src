#!/usr/bin/env python3
"""Audit the self-contained Source Reconstruction 3.1 project contract."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any

from validation.lint_project import (
    lint_documentation_corpus,
    lint_label_registry_location,
)
from validation.make_contract import make_targets


EXPECTED_PROFILES = [
    "ju",
    "pc10",
    "pal",
    "vs_smb",
    "fds_smb",
    "ann_fds",
    "smb2_jp_fds",
]
CYRILLIC_RE = re.compile(r"[\u0400-\u052f]")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
TEXT_SUFFIXES = {".asm", ".cfg", ".inc", ".json", ".lua", ".md", ".mk", ".py", ".txt"}
TEXT_NAMES = {".editorconfig", ".gitattributes", ".gitignore", "Makefile"}


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


def target_name(command: str) -> str:
    parts = command.split()
    if parts and parts[0] == "make":
        parts = parts[1:]
    return parts[0] if parts else ""


def present_paths(project_root: Path) -> list[Path]:
    tracked = git_output(project_root, "ls-files").splitlines()
    untracked = git_output(
        project_root, "ls-files", "--others", "--exclude-standard"
    ).splitlines()
    return sorted(
        {
            project_root / relative
            for relative in [*tracked, *untracked]
            if relative and (project_root / relative).is_file()
        }
    )


def validate_public_language(project_root: Path) -> list[str]:
    errors: list[str] = []
    for path in present_paths(project_root):
        relative = path.relative_to(project_root)
        if CYRILLIC_RE.search(relative.as_posix()):
            errors.append(f"public path contains Cyrillic: {relative.as_posix()}")
        if relative.name not in TEXT_NAMES and relative.suffix.lower() not in TEXT_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if CYRILLIC_RE.search(text):
            errors.append(f"public text contains Cyrillic: {relative.as_posix()}")
    return errors


def validate_layout(project_root: Path, layout_path: Path) -> list[str]:
    layout = load_json(layout_path)
    errors: list[str] = []
    tracked = set(git_output(project_root, "ls-files").splitlines())
    root_rule = layout.get("root_makefile", {})
    root_path = project_root / root_rule.get("path", "")
    if not root_path.is_file():
        errors.append("root Makefile is missing")
    elif len(root_path.read_text(encoding="utf-8").splitlines()) > root_rule.get(
        "maximum_lines", 0
    ):
        errors.append("root Makefile exceeds its line budget")

    fragment_rule = layout.get("make_fragments", {})
    declared_fragments = fragment_rule.get("files", [])
    actual_fragments = sorted(
        path.relative_to(project_root).as_posix()
        for path in (project_root / fragment_rule.get("directory", "")).glob("*.mk")
    )
    if actual_fragments != declared_fragments:
        errors.append("Make fragment inventory differs from the layout contract")
    for relative in declared_fragments:
        path = project_root / relative
        if not path.is_file():
            errors.append(f"Make fragment is missing: {relative}")
        elif len(path.read_text(encoding="utf-8").splitlines()) > fragment_rule.get(
            "maximum_lines", 0
        ):
            errors.append(f"Make fragment exceeds its line budget: {relative}")

    packages = layout.get("responsibility_packages", [])
    for package in packages:
        for root in ("scripts", "tests"):
            path = project_root / root / package
            init_path = (path / "__init__.py").relative_to(project_root).as_posix()
            if (
                not path.is_dir()
                or not (path / "__init__.py").is_file()
                or init_path not in tracked
            ):
                errors.append(f"responsibility package is incomplete: {root}/{package}")

    assembly_rule = layout.get("assembly_size_policy", {})
    short_limit = assembly_rule.get("short_module_lines", 0)
    large_limit = assembly_rule.get("large_module_lines", 0)
    declared_assembly = {
        item.get("path") for item in assembly_rule.get("exceptions", [])
    }
    actual_assembly: set[str] = set()
    for path in sorted((project_root / "src").rglob("*")):
        if not path.is_file() or path.suffix.lower() not in {".asm", ".inc"}:
            continue
        lines = len(path.read_text(encoding="utf-8").splitlines())
        if lines < short_limit or lines > large_limit:
            actual_assembly.add(path.relative_to(project_root).as_posix())
    if declared_assembly != actual_assembly:
        missing = sorted(actual_assembly - declared_assembly)
        stale = sorted(declared_assembly - actual_assembly)
        if missing:
            errors.append(f"assembly size exceptions are missing: {', '.join(missing)}")
        if stale:
            errors.append(f"assembly size exceptions are stale: {', '.join(stale)}")
    for item in assembly_rule.get("exceptions", []):
        if not item.get("kind") or not item.get("reason"):
            errors.append(f"assembly size exception lacks a reason: {item.get('path')}")

    python_rule = layout.get("python_size_policy", {})
    review_limit = python_rule.get("review_lines", 0)
    declared_python = {item.get("path") for item in python_rule.get("reviews", [])}
    actual_python = {
        path.relative_to(project_root).as_posix()
        for path in (project_root / "scripts").rglob("*.py")
        if len(path.read_text(encoding="utf-8").splitlines()) > review_limit
    }
    if declared_python != actual_python:
        errors.append("Python size-review inventory differs from the layout contract")
    for item in python_rule.get("reviews", []):
        if any(
            not item.get(field)
            for field in ("cohesion", "extraction_decision", "public_api_control")
        ):
            errors.append(f"Python size review is incomplete: {item.get('path')}")
    return errors


def release_commits(project_root: Path, predecessor: str) -> list[dict[str, str]]:
    result = subprocess.run(
        [
            "git",
            "log",
            "--reverse",
            "--format=%H%x1f%aI%x1f%cI%x1f%an%x1f%ae%x1f%cn%x1f%ce%x1f%B%x1e",
            f"{predecessor}..HEAD",
        ],
        cwd=project_root,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    commits: list[dict[str, str]] = []
    for record in result.stdout.split("\x1e"):
        record = record.strip()
        if not record:
            continue
        fields = record.split("\x1f", 7)
        if len(fields) != 8:
            continue
        commits.append(
            dict(
                zip(
                    ("commit", "author_date", "commit_date", "author_name", "author_email", "committer_name", "committer_email", "message"),
                    fields,
                    strict=True,
                )
            )
        )
    return commits


def validate_release_objects(project_root: Path, predecessor: str) -> list[str]:
    """Check paths and blobs first introduced after the published predecessor."""
    errors: list[str] = []
    commit_ids = git_output(
        project_root, "rev-list", "--reverse", f"{predecessor}..HEAD"
    ).splitlines()
    for commit in commit_ids:
        result = subprocess.run(
            ["git", "diff-tree", "--no-commit-id", "--name-only", "-r", "-z", commit],
            cwd=project_root,
            check=True,
            capture_output=True,
        )
        for raw_path in result.stdout.split(b"\0"):
            if not raw_path:
                continue
            path = raw_path.decode("utf-8", errors="surrogateescape")
            if CYRILLIC_RE.search(path):
                errors.append(
                    f"release commit introduces a Cyrillic path: {commit[:12]} {path}"
                )

    result = subprocess.run(
        [
            "git",
            "-c",
            "core.quotePath=false",
            "rev-list",
            "--objects",
            f"{predecessor}..HEAD",
        ],
        cwd=project_root,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="surrogateescape",
    )
    for record in result.stdout.splitlines():
        object_id, _, path = record.partition(" ")
        if git_output(project_root, "cat-file", "-t", object_id) != "blob":
            continue
        blob = subprocess.run(
            ["git", "cat-file", "blob", object_id],
            cwd=project_root,
            check=True,
            capture_output=True,
        ).stdout
        try:
            text = blob.decode("utf-8")
        except UnicodeDecodeError:
            continue
        if CYRILLIC_RE.search(text):
            label = path or object_id
            errors.append(f"release range introduces a Cyrillic blob: {label}")
    return errors


def validate_release_history(
    project_root: Path, predecessor: str, history: dict[str, Any]
) -> list[str]:
    errors: list[str] = []
    allowed = {
        (item.get("name"), item.get("email"))
        for item in history.get("allowed_identities", [])
    }
    required_coauthor = history.get("required_coauthor", "")
    predecessor_dates = git_output(
        project_root, "show", "-s", "--format=%aI%x1f%cI", predecessor
    ).split("\x1f")
    previous_author = datetime.fromisoformat(predecessor_dates[0])
    previous_commit = datetime.fromisoformat(predecessor_dates[1])
    commits = release_commits(project_root, predecessor)
    if not commits:
        return ["Source Reconstruction 3.1 release history is empty"]
    for item in commits:
        short = item["commit"][:12]
        message = item["message"].strip()
        paragraphs = re.split(r"\n\s*\n", message)
        subject = paragraphs[0]
        body = [part for part in paragraphs[1:] if part != required_coauthor]
        if CYRILLIC_RE.search(message):
            errors.append(f"release commit message is not English: {short}")
        if not subject or len(subject) > 72 or subject.endswith("."):
            errors.append(f"release commit subject is invalid: {short}")
        if subject.lower() in {"fix", "update", "changes", "wip"}:
            errors.append(f"release commit subject is not descriptive: {short}")
        if len(body) not in {2, 3}:
            errors.append(f"release commit body must contain two or three paragraphs: {short}")
        if required_coauthor not in paragraphs:
            errors.append(f"release commit lacks the required co-author trailer: {short}")
        if (item["author_name"], item["author_email"]) not in allowed:
            errors.append(f"release commit author identity is not allowed: {short}")
        if (item["committer_name"], item["committer_email"]) not in allowed:
            errors.append(f"release commit committer identity is not allowed: {short}")
        nonempty = subprocess.run(
            ["git", "diff-tree", "--quiet", f"{item['commit']}^", item["commit"], "--"],
            cwd=project_root,
            check=False,
        ).returncode
        if nonempty == 0:
            errors.append(f"release commit is empty: {short}")
        author_date = datetime.fromisoformat(item["author_date"])
        commit_date = datetime.fromisoformat(item["commit_date"])
        if author_date <= previous_author:
            errors.append(f"release AuthorDate order is not strictly increasing: {short}")
        if commit_date <= previous_commit:
            errors.append(f"release CommitDate order is not strictly increasing: {short}")
        previous_author = author_date
        previous_commit = commit_date
    return errors


def validate_rewrite_map(
    project_root: Path,
    release: dict[str, Any],
) -> list[str]:
    errors: list[str] = []
    history = release.get("history", {})
    relative = history.get("rewrite_map", "")
    path = project_root / relative
    if not path.is_file():
        return ["Source Reconstruction 3.1 rewrite map is missing"]
    document = load_json(path)
    predecessor = release.get("predecessor", {}).get("commit")
    if document.get("base", {}).get("commit") != predecessor:
        errors.append("rewrite map base differs from the release predecessor")
    source_drafts = document.get("source_drafts", [])
    draft_commits: set[str] = set()
    for draft in source_drafts:
        commit = draft.get("commit", "")
        if not re.fullmatch(r"[0-9a-f]{40}", commit):
            errors.append("rewrite map source draft has an invalid commit")
            continue
        if any(
            not draft.get(field)
            for field in ("title", "author_date", "commit_date")
        ):
            errors.append(f"rewrite map source draft is incomplete: {commit[:12]}")
        draft_commits.add(commit)
    if document.get("carried_dirty_paths") != []:
        errors.append("rewrite map invents dirty paths that were not present")
    entries = document.get("reconstructed_commits", [])
    mapped_subjects: dict[str, str] = {}
    for entry in entries:
        commit = entry.get("commit")
        title = entry.get("title")
        if not title or not entry.get("scope") or not entry.get("reason"):
            errors.append(f"rewrite map entry is incomplete: {title}")
            continue
        source_commits = set(entry.get("source_commits", []))
        origin = entry.get("origin", "rewritten_draft")
        if origin == "new_work":
            if source_commits:
                errors.append(f"new work invents source attribution: {title}")
        elif origin == "rewritten_draft":
            if not source_commits or not source_commits.issubset(draft_commits):
                errors.append(f"rewrite map source attribution differs: {title}")
        else:
            errors.append(f"rewrite map origin differs: {title}")
        if commit == "pending":
            if release.get("status") == "tag-ready":
                errors.append(f"tag-ready rewrite map retains a pending commit: {title}")
            continue
        resolved = git_output(project_root, "rev-parse", commit)
        actual_title = git_output(project_root, "show", "-s", "--format=%s", resolved)
        if actual_title != title:
            errors.append(f"rewrite map title differs: {title}")
        mapped_subjects[resolved] = title
    actual = {
        item["commit"]: item["message"].splitlines()[0]
        for item in release_commits(project_root, predecessor)
    }
    for commit, title in actual.items():
        if mapped_subjects.get(commit) == title:
            continue
        if any(
            entry.get("commit") == "pending" and entry.get("title") == title
            for entry in entries
        ):
            continue
        errors.append(f"release commit is absent from the rewrite map: {commit[:12]}")
    preserved = document.get("preserved_refs", {})
    if preserved != {
        "main_unchanged_during_rewrite": True,
        "local_branches_and_tags_deleted": False,
        "published_refs_rewritten": False,
    }:
        errors.append("rewrite map ref-preservation record differs")
    return errors


def validate_evidence(
    project_root: Path, release: dict[str, Any], targets: set[str]
) -> list[str]:
    errors: list[str] = []
    for collection_name in ("delta",):
        collection = release.get(collection_name, [])
        identifiers = [item.get("id") for item in collection]
        if not identifiers or len(identifiers) != len(set(identifiers)):
            errors.append(f"{collection_name} IDs are empty or duplicated")
        for item in collection:
            if not item.get("summary") or not item.get("kind"):
                errors.append(f"{collection_name} entry is incomplete: {item.get('id')}")
            evidence = item.get("evidence", {})
            for relative in evidence.get("files", []):
                if not (project_root / relative).exists():
                    errors.append(f"delta evidence is missing: {relative}")
            for command in evidence.get("targets", []):
                if target_name(command) not in targets:
                    errors.append(f"delta target is missing: {command}")
    for identifier, requirement in release.get("requirements", {}).items():
        status = requirement.get("status")
        development_gate = (
            release.get("status") == "development"
            and identifier == "aggregate_release_gate"
            and status == "partial"
        )
        if status != "satisfied" and not development_gate:
            errors.append(f"requirement is not satisfied: {identifier}")
        evidence = requirement.get("evidence", {})
        if not evidence:
            errors.append(f"requirement lacks evidence: {identifier}")
        for relative in evidence.get("files", []):
            if not (project_root / relative).exists():
                errors.append(f"requirement evidence is missing: {relative}")
        for command in evidence.get("targets", []):
            if target_name(command) not in targets:
                errors.append(f"requirement target is missing: {command}")
    return errors


def profile_sources(project_root: Path) -> dict[str, tuple[int, str]]:
    profiles: dict[str, tuple[int, str]] = {}
    for relative in (
        "config/revision_profiles.json",
        "config/platform_profiles.json",
        "config/smb2_platform_profile.json",
    ):
        document = load_json(project_root / relative)
        entries = document.get("supported", document.get("profiles", []))
        for item in entries:
            size = item.get("rom_size", item.get("disk_size"))
            digest = item.get("rom_sha1", item.get("disk_sha1"))
            if size is not None and digest:
                profiles[item["id"]] = (size, digest)
    return profiles


def validate_profiles_and_artifacts(
    project_root: Path, release: dict[str, Any], targets: set[str]
) -> list[str]:
    errors: list[str] = []
    profiles = release.get("profiles", [])
    profile_ids = [item.get("id") for item in profiles]
    if profile_ids != EXPECTED_PROFILES:
        errors.append("accepted profile order or identity differs")
    artifacts = {item.get("id"): item for item in release.get("artifacts", [])}
    sources = profile_sources(project_root)
    for profile in profiles:
        identifier = profile.get("id")
        artifact = artifacts.get(profile.get("artifact"))
        if profile.get("status") != "supported" or profile.get("identity") != "byte-identical":
            errors.append(f"profile is not accepted as byte-identical: {identifier}")
        if not artifact or artifact.get("profile") != identifier:
            errors.append(f"profile artifact mapping differs: {identifier}")
            continue
        if (artifact.get("size"), artifact.get("sha1")) != sources.get(identifier):
            errors.append(f"profile artifact identity differs: {identifier}")
        if not SHA256_RE.fullmatch(artifact.get("sha256", "")):
            errors.append(f"profile artifact SHA-256 is invalid: {identifier}")
        if target_name(artifact.get("build_target", "")) not in targets:
            errors.append(f"profile artifact target is missing: {identifier}")
    coverage = release.get("runtime_coverage", [])
    if [item.get("profile_id") for item in coverage] != EXPECTED_PROFILES:
        errors.append("runtime coverage profile set differs")
    for item in coverage:
        if item.get("mode") != "direct" or not item.get("targets"):
            errors.append(f"profile lacks direct runtime coverage: {item.get('profile_id')}")
        for command in item.get("targets", []):
            if target_name(command) not in targets:
                errors.append(f"runtime target is missing: {command}")
    return errors


def validate_tag(
    project_root: Path, release: dict[str, Any], phase: str, check_remote: bool
) -> list[str]:
    errors: list[str] = []
    tag = release.get("tag", "")
    try:
        tag_type = git_output(project_root, "cat-file", "-t", f"refs/tags/{tag}")
        tag_object = git_output(project_root, "rev-parse", f"refs/tags/{tag}")
        peeled = git_output(project_root, "rev-list", "-n", "1", tag)
    except subprocess.CalledProcessError:
        tag_type = tag_object = peeled = ""
    if phase == "pre":
        if git_output(project_root, "status", "--porcelain", "--untracked-files=all"):
            errors.append("pre-tag audit requires a clean Git tree")
        if not git_output(project_root, "branch", "--show-current").startswith("rewrite/"):
            errors.append("pre-tag audit must run from a rewrite branch")
        subject = git_output(project_root, "log", "-1", "--format=%s")
        if subject.startswith("Complete Source Reconstruction"):
            errors.append("pre-tag HEAD retains a completion claim after review findings")
        if tag_object:
            errors.append(f"future release tag already exists locally: {tag}")
    elif phase == "post":
        if tag_type != "tag":
            errors.append("Source Reconstruction 3.1 tag is missing or not annotated")
        if peeled != git_output(project_root, "rev-parse", "HEAD"):
            errors.append("Source Reconstruction 3.1 tag does not point to HEAD")
        if release.get("release", {}).get("name", "") not in git_output(
            project_root, "for-each-ref", "--format=%(contents)", f"refs/tags/{tag}"
        ):
            errors.append("Source Reconstruction 3.1 tag lacks a release summary")
    else:
        errors.append(f"unsupported tag phase: {phase}")
    if check_remote:
        result = subprocess.run(
            ["git", "ls-remote", "--tags", "origin", f"refs/tags/{tag}", f"refs/tags/{tag}^{{}}"],
            cwd=project_root,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if result.returncode != 0:
            errors.append("cannot inspect the release tag on origin")
        else:
            refs = {
                ref: object_id
                for object_id, ref in (
                    line.split("\t", 1) for line in result.stdout.splitlines() if "\t" in line
                )
            }
            if phase == "pre" and refs:
                errors.append("future release tag already exists on origin")
            if phase == "post" and (
                refs.get(f"refs/tags/{tag}") != tag_object
                or refs.get(f"refs/tags/{tag}^{{}}") != peeled
            ):
                errors.append("local and origin release tags differ")
    return errors


def validate_source_3_1(
    project_root: Path,
    manifest_path: Path,
    require_ready: bool = False,
) -> list[str]:
    release = load_json(manifest_path)
    errors: list[str] = []
    if release.get("schema_version") != 1:
        errors.append("Source Reconstruction 3.1 manifest schema differs")
    if release.get("release_line") != "2.x":
        errors.append("Source Reconstruction 3.1 quality line differs")
    if release.get("release") != {"name": "Source Reconstruction 3.1", "version": "3.1"}:
        errors.append("Source Reconstruction 3.1 release identity differs")
    if release.get("release_kind") != "compatible_minor":
        errors.append("Source Reconstruction 3.1 release kind differs")
    if release.get("tag") != "source-reconstruction-3.1":
        errors.append("Source Reconstruction 3.1 tag differs")
    status = release.get("status")
    if status not in {"development", "tag-ready"}:
        errors.append("Source Reconstruction 3.1 status is invalid")
    if require_ready and status != "tag-ready":
        errors.append("Source Reconstruction 3.1 manifest is not tag-ready")
    if "contract" in release:
        errors.append("public manifest contains non-project contract metadata")

    predecessor = release.get("predecessor", {})
    expected_predecessor = {
        "manifest": "config/source_reconstruction_3_0.json",
        "tag": "source-reconstruction-3.0",
        "commit": "4b0d6f885bdd41bdc08139f5044aeef3f099a69d",
    }
    if predecessor != expected_predecessor:
        errors.append("Source Reconstruction 3.1 predecessor differs")
    else:
        predecessor_manifest = load_json(project_root / predecessor["manifest"])
        if predecessor_manifest.get("tag") != predecessor["tag"]:
            errors.append("predecessor manifest tag differs")
        try:
            target = git_output(
                project_root, "rev-parse", f"refs/tags/{predecessor['tag']}^{{commit}}"
            )
        except subprocess.CalledProcessError:
            errors.append("published predecessor tag is missing")
        else:
            if target != predecessor["commit"]:
                errors.append("published predecessor tag target differs")
            if subprocess.run(
                ["git", "merge-base", "--is-ancestor", predecessor["commit"], "HEAD"],
                cwd=project_root,
                check=False,
            ).returncode != 0:
                errors.append("published predecessor is not an ancestor of HEAD")

    targets = make_targets(project_root)
    errors.extend(validate_evidence(project_root, release, targets))
    errors.extend(validate_profiles_and_artifacts(project_root, release, targets))
    for relative in release.get("required_documents", []):
        if not (project_root / relative).is_file():
            errors.append(f"required 3.1 document is missing: {relative}")
    for name in release.get("required_targets", []):
        if name not in targets:
            errors.append(f"required 3.1 Make target is missing: {name}")
    toolchain = release.get("toolchain", {})
    toolchain_path = project_root / toolchain.get("manifest", "")
    if not toolchain_path.is_file():
        errors.append("Source Reconstruction 3.1 toolchain manifest is missing")
    else:
        toolchain_document = load_json(toolchain_path)
        if toolchain_document.get("release") != release.get("release", {}).get("name"):
            errors.append("Source Reconstruction 3.1 toolchain release differs")
    if toolchain.get("verification_target") not in targets:
        errors.append("Source Reconstruction 3.1 toolchain target is missing")
    gates = release.get("aggregate_gates", {})
    if gates != {
        "scaffold": "scaffold-check",
        "release": "source-3-1-check",
        "pre_tag": "source-3-1-pre-tag",
        "post_tag": "source-3-1-post-tag",
    }:
        errors.append("Source Reconstruction 3.1 aggregate gate map differs")
    errors.extend(
        validate_layout(
            project_root,
            project_root / "config" / "reconstruction" / "repository_layout.json",
        )
    )
    errors.extend(validate_public_language(project_root))
    if predecessor.get("commit"):
        errors.extend(
            validate_release_history(
                project_root, predecessor["commit"], release.get("history", {})
            )
        )
        errors.extend(validate_release_objects(project_root, predecessor["commit"]))
    errors.extend(validate_rewrite_map(project_root, release))
    errors.extend(
        f"documentation corpus: {diagnostic.message}"
        for diagnostic in lint_documentation_corpus(project_root)
    )
    errors.extend(
        f"label registry: {diagnostic.message}"
        for diagnostic in lint_label_registry_location(project_root)
    )
    constraints = release.get("historical_constraints", [])
    if not constraints or any(
        item.get("status") != "deferred" or not item.get("reason")
        for item in constraints
    ):
        errors.append("published historical constraints are not recorded")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root", type=Path, default=Path(__file__).resolve().parents[2]
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parents[2]
        / "config"
        / "source_reconstruction_3_1.json",
    )
    parser.add_argument("--require-ready", action="store_true")
    parser.add_argument("--tag-phase", choices=("pre", "post"))
    parser.add_argument("--check-remote", action="store_true")
    args = parser.parse_args()
    root = args.project_root.resolve()
    release = load_json(args.manifest.resolve())
    errors = validate_source_3_1(root, args.manifest.resolve(), args.require_ready)
    if args.tag_phase:
        errors.extend(validate_tag(root, release, args.tag_phase, args.check_remote))
    if errors:
        for error in errors:
            print(f"[ERROR] {error}")
        print(f"[FAIL] Source Reconstruction 3.1 audit found {len(errors)} error(s)")
        return 1
    print("[OK] Source Reconstruction 3.1 structure, evidence, history, and release metadata agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
