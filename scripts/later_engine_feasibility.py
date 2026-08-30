#!/usr/bin/env python3
"""Measure FDS payload relationships without exporting private ROM bytes."""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
from pathlib import Path
from typing import Any

from platform_profiles import FdsFileRecord, parse_fds_side


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def load_manifest(path: Path) -> dict[str, Any]:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1:
        raise ValueError("unsupported later-engine feasibility schema")
    references = document.get("references")
    if not isinstance(references, list) or len(references) < 2:
        raise ValueError("later-engine feasibility requires at least two references")
    identifiers = [reference.get("id") for reference in references]
    if len(set(identifiers)) != len(identifiers) or document.get("subject") not in identifiers:
        raise ValueError("invalid later-engine reference identifiers")
    if not set(document.get("comparisons", ())) < set(identifiers):
        raise ValueError("invalid later-engine comparison set")
    return document


def load_reference(project_root: Path, contract: dict[str, Any]) -> tuple[bytes, list[FdsFileRecord]]:
    path = project_root / str(contract["path"])
    data = path.read_bytes()
    if len(data) != int(contract["size"]) or sha1(data) != contract["sha1"]:
        raise ValueError(f"private reference does not match: {contract['id']}")
    return data, parse_fds_side(data)


def record_name(record: FdsFileRecord) -> str:
    raw = record.name.rstrip(b"\x00 ")
    if raw and all(0x20 <= value <= 0x7e for value in raw):
        return raw.decode("ascii")
    return raw.hex()


def record_document(record: FdsFileRecord, payload: bytes) -> dict[str, Any]:
    return {
        "file_number": record.file_number,
        "file_id": record.file_id,
        "name": record_name(record),
        "load_address": record.load_address,
        "size": record.size,
        "file_type": record.file_type,
        "sha1": sha1(payload),
    }


def record_payload(image: bytes, record: FdsFileRecord) -> bytes:
    return image[record.data_offset : record.data_offset + record.size]


def compare_bytes(baseline: bytes, subject: bytes) -> dict[str, Any]:
    matcher = difflib.SequenceMatcher(None, baseline, subject, autojunk=True)
    blocks = [block for block in matcher.get_matching_blocks() if block.size]
    matching = sum(block.size for block in blocks)
    return {
        "matching_bytes": matching,
        "subject_coverage": round(matching / len(subject), 6) if subject else 1.0,
        "baseline_coverage": round(matching / len(baseline), 6) if baseline else 1.0,
        "longest_matching_run": max((block.size for block in blocks), default=0),
        "exact": baseline == subject,
    }


def same_address_comparison(
    baseline_record: FdsFileRecord,
    baseline: bytes,
    subject_record: FdsFileRecord,
    subject: bytes,
) -> dict[str, Any]:
    start = max(baseline_record.load_address, subject_record.load_address)
    end = min(
        baseline_record.load_address + len(baseline),
        subject_record.load_address + len(subject),
    )
    if end <= start:
        return {"overlap_bytes": 0, "equal_bytes": 0, "equal_ratio": 0.0}
    baseline_start = start - baseline_record.load_address
    subject_start = start - subject_record.load_address
    size = end - start
    equal = sum(
        left == right
        for left, right in zip(
            baseline[baseline_start : baseline_start + size],
            subject[subject_start : subject_start + size],
        )
    )
    return {
        "overlap_bytes": size,
        "equal_bytes": equal,
        "equal_ratio": round(equal / size, 6),
    }


def compare_records(
    baseline_image: bytes,
    baseline_records: list[FdsFileRecord],
    subject_image: bytes,
    subject_records: list[FdsFileRecord],
) -> list[dict[str, Any]]:
    results = []
    for subject_record in subject_records:
        subject_payload = record_payload(subject_image, subject_record)
        candidates = []
        for baseline_record in baseline_records:
            if baseline_record.file_type != subject_record.file_type:
                continue
            baseline_payload = record_payload(baseline_image, baseline_record)
            comparison = compare_bytes(baseline_payload, subject_payload)
            candidates.append({
                "record": record_document(baseline_record, baseline_payload),
                **comparison,
                "same_address": same_address_comparison(
                    baseline_record,
                    baseline_payload,
                    subject_record,
                    subject_payload,
                ),
            })
        best = max(
            candidates,
            key=lambda item: (
                item["matching_bytes"],
                item["same_address"]["equal_bytes"],
                item["longest_matching_run"],
            ),
        )
        same_file_id = next(
            (
                candidate for candidate in candidates
                if candidate["record"]["file_id"] == subject_record.file_id
            ),
            None,
        )
        results.append({
            "subject_record": record_document(subject_record, subject_payload),
            "best_baseline_match": best,
            "same_file_id_match": same_file_id,
        })
    return results


def build_report(project_root: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    loaded = {
        contract["id"]: (*load_reference(project_root, contract), contract)
        for contract in manifest["references"]
    }
    subject_id = manifest["subject"]
    subject_image, subject_records, _contract = loaded[subject_id]
    references = {}
    for identifier, (image, records, contract) in loaded.items():
        references[identifier] = {
            "path": contract["path"],
            "size": len(image),
            "sha1": sha1(image),
            "files": [
                record_document(record, record_payload(image, record))
                for record in records
            ],
        }
    comparisons = {}
    for baseline_id in manifest["comparisons"]:
        baseline_image, baseline_records, _contract = loaded[baseline_id]
        records = compare_records(
            baseline_image,
            baseline_records,
            subject_image,
            subject_records,
        )
        comparisons[baseline_id] = {
            "subject_bytes": sum(item["subject_record"]["size"] for item in records),
            "best_match_bytes": sum(
                item["best_baseline_match"]["matching_bytes"] for item in records
            ),
            "exact_record_matches": sum(
                item["best_baseline_match"]["exact"] for item in records
            ),
            "same_file_id_subject_bytes": sum(
                item["subject_record"]["size"]
                for item in records
                if item["same_file_id_match"] is not None
            ),
            "same_file_id_matching_bytes": sum(
                item["same_file_id_match"]["matching_bytes"]
                for item in records
                if item["same_file_id_match"] is not None
            ),
            "same_file_id_exact_records": sum(
                item["same_file_id_match"]["exact"]
                for item in records
                if item["same_file_id_match"] is not None
            ),
            "records": records,
        }
    report = {
        "schema_version": 1,
        "subject": subject_id,
        "decision": manifest.get("decision"),
        "references": references,
        "comparisons": comparisons,
    }
    for baseline_id, expected in manifest.get("expected_comparisons", {}).items():
        if baseline_id not in comparisons:
            raise ValueError(f"unknown expected comparison: {baseline_id}")
        actual = comparisons[baseline_id]
        for field, value in expected.items():
            if actual.get(field) != value:
                raise ValueError(
                    f"later-engine comparison differs: {baseline_id}/{field}"
                )
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    report = build_report(args.project_root, load_manifest(args.manifest))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for baseline, comparison in report["comparisons"].items():
        print(
            f"[OK] {baseline} -> {report['subject']}: "
            f"{comparison['best_match_bytes']}/{comparison['subject_bytes']} "
            f"best-match bytes; "
            f"{comparison['same_file_id_matching_bytes']}/"
            f"{comparison['same_file_id_subject_bytes']} same-ID bytes; "
            f"{comparison['same_file_id_exact_records']} exact same-ID records"
        )
    print(f"[OK] Later-engine feasibility report: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
