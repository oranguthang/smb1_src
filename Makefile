# Stable project interface; implementation is grouped by workflow under mk/.
PYTHON ?= python
PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := build

.PHONY: help build verify verify-all build-prg verify-prg build-hack verify-hack validate-hack build-expanded verify-expanded validate-expanded prepare-content-profile init-content export-content validate-content build-content run-content check-studios check-content-profile check-content-profiles world-studio level-studio smoke-level-playtest graphics-studio sound-studio world-editor level-editor graphics-editor sound-editor list-content-profiles content-profile-audit split-revision-assets build-revision verify-revision validate-revision verify-revisions validate-revisions split-platform-assets build-platform verify-platform validate-platform verify-platforms validate-platforms split-smb2-assets build-smb2-identity verify-smb2-identity build-smb2-source verify-smb2-source build-smb2 verify-smb2 validate-smb2-runtime validate-smb2-overlays validate-smb2-gameplay test-smb2-relocation validate-smb2-relocation prepare-ann-supplemental-assets build-ann-payloads build-ann-supplemental-courses build-ann-ending build-ann-hard-courses verify-ann-audio verify-ann-tail-core verify-ann-supplemental-courses verify-ann-ending verify-ann-hard-courses symbols validate-symbols trace trace-runtime validate-runtime roundtrip-formats release-audit release-check source-2-audit source-2-release-audit source-2-check source-3-audit source-3-release-audit check-source-3-toolchain source-3-tag-audit source-3-pre-tag source-3-post-tag source-3-check scaffold-check source-2-minor-check source-3-1-audit source-3-1-release-audit check-source-3-1-toolchain source-3-1-tag-audit source-3-1-pre-tag source-3-1-post-tag source-3-1-check semantic-evidence audit-enemy-streams audit-unreachable-code trace-semantic-runtime validate-semantic-runtime trace-scoring-runtime validate-scoring-runtime later-engine-feasibility later-engine-source-overlap test-relocation test-relocation-revisions test-platform-relocations test-ann-main-relocation validate-relocation validate-revision-relocation validate-platform-relocation validate-relocation-revisions validate-relocation-platforms split split-all check-assets lint format test trace-player clean _require-assets

include mk/core.mk
include mk/releases.mk
include mk/smb2.mk
include mk/evidence.mk
include mk/relocation.mk
include mk/variants.mk
include mk/profiles.mk
include mk/authoring.mk
include mk/runtime.mk
