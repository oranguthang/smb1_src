# Thin workflow entrypoints; platform-specific logic lives in Python.
PYTHON ?= python
PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ORIGINAL_ROM ?= $(PROJECT_DIR)Super Mario Bros. (JU) [!].nes
ASSET_MANIFEST ?= $(PROJECT_DIR)assets/manifest.json
GENERATED_ASSET_DIR ?= $(PROJECT_DIR)assets/generated
GENERATED_HEADER ?= $(GENERATED_ASSET_DIR)/header/smb.hdr
GENERATED_CHR ?= $(GENERATED_ASSET_DIR)/chr/smb.chr

NATIVE_SOURCE ?= $(PROJECT_DIR)src/main.asm
NATIVE_CFG ?= $(PROJECT_DIR)config/linker/nrom256_prg_only.cfg
NATIVE_BUILD_DIR ?= $(PROJECT_DIR)build/native
NATIVE_OBJ ?= $(NATIVE_BUILD_DIR)/smbdis.o
NATIVE_PRG ?= $(NATIVE_BUILD_DIR)/smb.prg
NATIVE_LABELS ?= $(NATIVE_BUILD_DIR)/smb.lbl
NATIVE_MAP ?= $(NATIVE_BUILD_DIR)/smb.map
NATIVE_DEBUG ?= $(NATIVE_BUILD_DIR)/smb.dbg
NATIVE_ROM ?= $(NATIVE_BUILD_DIR)/smb.nes
DEBUG_BREAKPOINTS ?= $(PROJECT_DIR)config/debugger_breakpoints.json
DEBUG_WATCHES ?= $(PROJECT_DIR)config/debugger_watches.json
DEBUG_SUMMARY ?= $(NATIVE_BUILD_DIR)/debug_symbols.json
FCEUX_SYMBOL_DIR ?= $(NATIVE_BUILD_DIR)
FCEUX_EXE ?= $(PROJECT_DIR)../fceux_automation/vc/x64/Release/fceux64.exe
FDS_BIOS ?= $(dir $(FCEUX_EXE))disksys.rom
DEBUG_RUNTIME_LUA ?= $(PROJECT_DIR)scripts/workflow/validate_debug_symbols.lua
DEBUG_RUNTIME_RESULT ?= $(NATIVE_BUILD_DIR)/debug_symbols_runtime.txt
RUNTIME_MOVIE ?= $(PROJECT_DIR)movies/smb1_any_percent.fm2
RUNTIME_SCENARIOS ?= $(PROJECT_DIR)scenarios/runtime_scenarios.json
RUNTIME_TRACE_LUA ?= $(PROJECT_DIR)scripts/workflow/capture_runtime_scenario.lua
RUNTIME_TRACE_DIR ?= $(PROJECT_DIR)build/runtime
SEMANTIC_RUNTIME_SCENARIOS ?= $(PROJECT_DIR)scenarios/semantic_runtime_scenarios.json
SEMANTIC_RUNTIME_TRACE_DIR ?= $(PROJECT_DIR)build/evidence/runtime
DATA_FORMAT_MANIFEST ?= $(PROJECT_DIR)config/data_formats.json
DATA_FORMAT_SUMMARY ?= $(PROJECT_DIR)build/data_formats.json
CONTENT_FORMAT_MANIFEST ?= $(PROJECT_DIR)config/content_formats_3.json
CONTENT_PROFILE_MANIFEST ?= $(PROJECT_DIR)config/content_authoring_profiles.json
RELEASE_MANIFEST ?= $(PROJECT_DIR)config/preservation_source_1_0.json
SOURCE_2_MANIFEST ?= $(PROJECT_DIR)config/source_reconstruction_2_0.json
SOURCE_3_MANIFEST ?= $(PROJECT_DIR)config/source_reconstruction_3_0.json
LATER_ENGINE_MANIFEST ?= $(PROJECT_DIR)config/later_engine_feasibility.json
LATER_ENGINE_REPORT ?= $(PROJECT_DIR)build/evidence/later_engine_feasibility.json
SMB2_RECONSTRUCTION_MANIFEST ?= $(PROJECT_DIR)config/smb2_reconstruction.json
SMB2_PLATFORM_MANIFEST ?= $(PROJECT_DIR)config/smb2_platform_profile.json
SMB2_REFERENCE ?= $(PROJECT_DIR)Super Mario Brothers 2 (Japan).fds
SMB2_ASSET_DIR ?= $(GENERATED_ASSET_DIR)/smb2
SMB2_BUILD_DIR ?= $(PROJECT_DIR)build/smb2/identity
SMB2_IDENTITY_IMAGE ?= $(SMB2_BUILD_DIR)/smb2.fds
SMB2_SOURCE_BUILD_DIR ?= $(PROJECT_DIR)build/smb2/source
SMB2_SOURCE_IMAGE ?= $(SMB2_SOURCE_BUILD_DIR)/smb2.fds
ENEMY_STREAM_EVIDENCE_MANIFEST ?= $(PROJECT_DIR)config/semantic_evidence/enemy_streams.json
ENEMY_STREAM_EVIDENCE_REPORT ?= $(PROJECT_DIR)build/evidence/enemy_streams.json
UNREACHABLE_CODE_EVIDENCE_MANIFEST ?= $(PROJECT_DIR)config/semantic_evidence/unreachable_code.json
UNREACHABLE_CODE_EVIDENCE_REPORT ?= $(PROJECT_DIR)build/evidence/unreachable_code.json
RELOCATION_PROFILE ?= ju
RELOCATION_MANIFEST ?= $(PROJECT_DIR)config/relocation/$(RELOCATION_PROFILE).json
RELOCATION_BUILD_DIR ?= $(PROJECT_DIR)build/relocation/$(RELOCATION_PROFILE)/candidate
RELOCATION_BASE_DIR ?= $(PROJECT_DIR)build/revisions/$(RELOCATION_PROFILE)
RELOCATION_BASE_PRG ?= $(RELOCATION_BASE_DIR)/smb.prg
RELOCATION_BASE_LABELS ?= $(RELOCATION_BASE_DIR)/smb.lbl
RELOCATION_BASE_DEBUG ?= $(RELOCATION_BASE_DIR)/smb.dbg
RELOCATION_PRG ?= $(RELOCATION_BUILD_DIR)/smb.prg
RELOCATION_LABELS ?= $(RELOCATION_BUILD_DIR)/smb.lbl
RELOCATION_MAP ?= $(RELOCATION_BUILD_DIR)/smb.map
RELOCATION_DEBUG ?= $(RELOCATION_BUILD_DIR)/smb.dbg
RELOCATION_ROM ?= $(RELOCATION_BUILD_DIR)/smb.nes
RELOCATION_SCENARIOS ?= $(RELOCATION_BUILD_DIR)/runtime_scenarios.json
RELOCATION_DEBUG_SUMMARY ?= $(RELOCATION_BUILD_DIR)/debug_symbols.json
RELOCATION_DEBUG_RESULT ?= $(RELOCATION_BUILD_DIR)/debug_symbols_runtime.txt
RELOCATION_TRACE_DIR ?= $(PROJECT_DIR)build/relocation/$(RELOCATION_PROFILE)/runtime
RELOCATION_REVISION_RESULT ?= $(RELOCATION_BUILD_DIR)/revision_runtime.txt
RELOCATION_PLATFORM_RESULT ?= $(RELOCATION_BUILD_DIR)/platform_runtime.txt
RELOCATION_PAL_ARG := $(if $(filter pal,$(RELOCATION_PROFILE)),--pal,)
RELOCATION_DEBUG_CONTAINER_ARG := $(if $(filter fds_smb ann_fds,$(RELOCATION_PROFILE)),--non-ines-container,)
ifeq ($(RELOCATION_PROFILE),pc10)
RELOCATION_REFERENCE ?= $(PROJECT_DIR)Super Mario Bros. (PC10).nes
RELOCATION_VERIFY_TARGET = verify-revision PROFILE=pc10
else ifeq ($(RELOCATION_PROFILE),pal)
RELOCATION_REFERENCE ?= $(PROJECT_DIR)Super Mario Bros. (E) (REV0) [!p].nes
RELOCATION_VERIFY_TARGET = verify-revision PROFILE=pal
else ifeq ($(RELOCATION_PROFILE),vs_smb)
RELOCATION_BASE_DIR = $(PROJECT_DIR)build/platforms/vs_smb
RELOCATION_REFERENCE ?= $(PROJECT_DIR)VS. Super Mario Bros. (VS).nes
RELOCATION_VERIFY_TARGET = verify-platform PLATFORM=vs_smb
else ifeq ($(RELOCATION_PROFILE),fds_smb)
RELOCATION_BASE_DIR = $(PROJECT_DIR)build/platforms/fds_smb
RELOCATION_REFERENCE ?= $(PROJECT_DIR)Super Mario Brothers (Japan).fds
RELOCATION_ROM = $(RELOCATION_BUILD_DIR)/smb.fds
RELOCATION_VERIFY_TARGET = verify-platform PLATFORM=fds_smb
else ifeq ($(RELOCATION_PROFILE),ann_fds)
RELOCATION_BASE_DIR = $(PROJECT_DIR)build/platforms/ann_fds
RELOCATION_REFERENCE ?= $(PROJECT_DIR)All Night Nippon Super Mario Brothers (Japan) (Promotion Card).fds
RELOCATION_ROM = $(RELOCATION_BUILD_DIR)/smb.fds
RELOCATION_VERIFY_TARGET = verify-platform PLATFORM=ann_fds
else
RELOCATION_REFERENCE ?= $(ORIGINAL_ROM)
RELOCATION_VERIFY_TARGET = verify-revision PROFILE=ju
endif
ANN_REFERENCE ?= $(PROJECT_DIR)All Night Nippon Super Mario Brothers (Japan) (Promotion Card).fds
ANN_TAIL_BUILD_DIR ?= $(PROJECT_DIR)build/platforms/ann_tail
ANN_TAIL_CORE_SOURCE ?= $(PROJECT_DIR)src/revisions/ann/tail_core.asm
ANN_TAIL_CORE_CFG ?= $(PROJECT_DIR)config/linker/ann/tail_core.cfg
ANN_AUDIO_SOURCE ?= $(PROJECT_DIR)src/revisions/ann/audio_tail.asm
ANN_AUDIO_CFG ?= $(PROJECT_DIR)config/linker/ann/audio_tail.cfg
ANN_AUDIO_BUILD_DIR ?= $(PROJECT_DIR)build/platforms/ann_audio
ANN_SUPPLEMENTAL_COURSES_SOURCE ?= $(PROJECT_DIR)src/revisions/ann/supplemental_courses.asm
ANN_SUPPLEMENTAL_COURSES_CFG ?= $(PROJECT_DIR)config/linker/ann/supplemental_courses.cfg
ANN_SUPPLEMENTAL_COURSES_BUILD_DIR ?= $(PROJECT_DIR)build/platforms/ann_supplemental_courses
ANN_ENDING_AUDIO_SOURCE ?= $(PROJECT_DIR)src/revisions/ann/ending_audio.asm
ANN_ENDING_AUDIO_CFG ?= $(PROJECT_DIR)config/linker/ann/ending_audio.cfg
ANN_ENDING_AUDIO_BUILD_DIR ?= $(PROJECT_DIR)build/platforms/ann_ending_audio
ANN_EXTENDED_COURSES_SOURCE ?= $(PROJECT_DIR)src/revisions/ann/extended_courses.asm
ANN_EXTENDED_COURSES_CFG ?= $(PROJECT_DIR)config/linker/ann/extended_courses.cfg
ANN_EXTENDED_COURSES_BUILD_DIR ?= $(PROJECT_DIR)build/platforms/ann_extended_courses
FIXED_VARIANT ?= five_lives
FIXED_VARIANT_MANIFEST ?= $(PROJECT_DIR)config/fixed_layout_variants.json
HACK_SOURCE ?= $(PROJECT_DIR)src/variants/five_lives.asm
HACK_BUILD_DIR ?= $(PROJECT_DIR)build/variants/$(FIXED_VARIANT)
HACK_OBJ ?= $(HACK_BUILD_DIR)/smb.o
HACK_PRG ?= $(HACK_BUILD_DIR)/smb.prg
HACK_LABELS ?= $(HACK_BUILD_DIR)/smb.lbl
HACK_MAP ?= $(HACK_BUILD_DIR)/smb.map
HACK_DEBUG ?= $(HACK_BUILD_DIR)/smb.dbg
HACK_ROM ?= $(HACK_BUILD_DIR)/smb.nes
HACK_RUNTIME_LUA ?= $(PROJECT_DIR)scripts/workflow/validate_fixed_variant.lua
HACK_RUNTIME_RESULT ?= $(HACK_BUILD_DIR)/runtime.txt
EXPANDED_MANIFEST ?= $(PROJECT_DIR)config/expanded_rom.json
EXPANDED_SOURCE ?= $(PROJECT_DIR)src/expanded/cnrom.asm
EXPANDED_CFG ?= $(PROJECT_DIR)config/linker/expanded/cnrom_prg_only.cfg
EXPANDED_BUILD_DIR ?= $(PROJECT_DIR)build/expanded/cnrom_chr_16k
EXPANDED_OBJ ?= $(EXPANDED_BUILD_DIR)/smb.o
EXPANDED_PRG ?= $(EXPANDED_BUILD_DIR)/smb.prg
EXPANDED_LABELS ?= $(EXPANDED_BUILD_DIR)/smb.lbl
EXPANDED_MAP ?= $(EXPANDED_BUILD_DIR)/smb.map
EXPANDED_DEBUG ?= $(EXPANDED_BUILD_DIR)/smb.dbg
EXPANDED_ROM ?= $(EXPANDED_BUILD_DIR)/smb.nes
EXPANDED_RUNTIME_LUA ?= $(PROJECT_DIR)scripts/workflow/validate_expanded_runtime.lua
EXPANDED_RUNTIME_RESULT ?= $(EXPANDED_BUILD_DIR)/runtime.txt
CONTENT_STUDIO_MANIFEST ?= $(PROJECT_DIR)config/content_studios.json
CONTENT_PROFILE ?= ju
CONTENT_WORKSPACE ?= $(PROJECT_DIR)content/workspace/$(CONTENT_PROFILE)
CONTENT_BUILD_DIR ?= $(PROJECT_DIR)build/content/$(CONTENT_PROFILE)
CONTENT_PRG ?= $(CONTENT_BUILD_DIR)/smb.prg
CONTENT_ROM ?= $(CONTENT_BUILD_DIR)/smb.nes
CONTENT_REPORT ?= $(CONTENT_BUILD_DIR)/diff_report.json
CONTENT_ROUNDTRIP_DIR ?= $(PROJECT_DIR)build/content_roundtrip/$(CONTENT_PROFILE)
CONTENT_BASE_DIR ?= $(PROJECT_DIR)build/revisions/$(CONTENT_PROFILE)
CONTENT_BASE_PRG ?= $(CONTENT_BASE_DIR)/smb.prg
CONTENT_BASE_LABELS ?= $(CONTENT_BASE_DIR)/smb.lbl
CONTENT_HEADER ?= $(GENERATED_HEADER)
CONTENT_CHR ?= $(GENERATED_CHR)
CONTENT_EXTRA ?= $(REVISION_ASSET_DIR)/$(CONTENT_PROFILE)/platform.extra
CONTENT_EXTRA_ARG = $(if $(filter pc10,$(CONTENT_PROFILE)),--extra "$(CONTENT_EXTRA)",)
LEVEL_STUDIO_ARGS ?=
PLAYTEST_BANK ?=
PLAYTEST_BANK_ARG = $(if $(PLAYTEST_BANK),--course-bank $(PLAYTEST_BANK),)
PLAYTEST_AREA ?=
PLAYTEST_AREA_ARG = $(if $(PLAYTEST_AREA),--area $(PLAYTEST_AREA),)
PLAYTEST_THEME ?= Day
CONTENT_LOAD_ADDRESS = 0x8000
CONTENT_PREPARE_COMMAND = $(MAKE) build-revision PROFILE=$(CONTENT_PROFILE)
CONTENT_CONTAINER_ARGS = --header "$(CONTENT_HEADER)" $(CONTENT_EXTRA_ARG)
CONTENT_PAYLOAD_ARGS =
STUDIO_CONTENT_PAYLOAD_ARGS =
CONTENT_STUDIO_ARG := $(if $(STUDIO),--studio "$(STUDIO)",)
STUDIO_COMMON_ARGS = \
	--formats "$(CONTENT_FORMAT_MANIFEST)" \
	--studios "$(CONTENT_STUDIO_MANIFEST)" \
	--profiles "$(CONTENT_PROFILE_MANIFEST)" \
	--profile "$(CONTENT_PROFILE)" \
	--workspace "$(CONTENT_WORKSPACE)" \
	--labels "$(CONTENT_BASE_LABELS)" \
	--content-prg "$(CONTENT_BASE_PRG)" \
	--content-chr "$(CONTENT_CHR)" \
	$(STUDIO_CONTENT_PAYLOAD_ARGS) \
	--project-root "$(PROJECT_DIR)"
PROFILE ?= pc10
REVISION_MANIFEST ?= $(PROJECT_DIR)config/revision_profiles.json
REVISION_SOURCE ?= $(PROJECT_DIR)src/revisions/$(PROFILE).asm
REVISION_BUILD_DIR ?= $(PROJECT_DIR)build/revisions/$(PROFILE)
REVISION_OBJ ?= $(REVISION_BUILD_DIR)/smb.o
REVISION_PRG ?= $(REVISION_BUILD_DIR)/smb.prg
REVISION_LABELS ?= $(REVISION_BUILD_DIR)/smb.lbl
REVISION_MAP ?= $(REVISION_BUILD_DIR)/smb.map
REVISION_DEBUG ?= $(REVISION_BUILD_DIR)/smb.dbg
REVISION_ROM ?= $(REVISION_BUILD_DIR)/smb.nes
REVISION_ASSET_DIR ?= $(GENERATED_ASSET_DIR)/revisions
REVISION_RUNTIME_RESULT ?= $(REVISION_BUILD_DIR)/runtime.txt
ifeq ($(PROFILE),pc10)
REVISION_REFERENCE ?= $(PROJECT_DIR)Super Mario Bros. (PC10).nes
else ifeq ($(PROFILE),ju)
REVISION_REFERENCE ?= $(PROJECT_DIR)Super Mario Bros. (JU) [!].nes
else ifeq ($(PROFILE),pal)
REVISION_REFERENCE ?= $(PROJECT_DIR)Super Mario Bros. (E) (REV0) [!p].nes
else
REVISION_REFERENCE ?= $(PROJECT_DIR)$(PROFILE).nes
endif
PLATFORM ?= vs_smb
PLATFORM_MANIFEST ?= $(PROJECT_DIR)config/platform_profiles.json
PLATFORM_ASSET_DIR ?= $(GENERATED_ASSET_DIR)/platforms
PLATFORM_BUILD_DIR ?= $(PROJECT_DIR)build/platforms/$(PLATFORM)
PLATFORM_OBJ ?= $(PLATFORM_BUILD_DIR)/smb.o
PLATFORM_PRG ?= $(PLATFORM_BUILD_DIR)/smb.prg
PLATFORM_LABELS ?= $(PLATFORM_BUILD_DIR)/smb.lbl
PLATFORM_MAP ?= $(PLATFORM_BUILD_DIR)/smb.map
PLATFORM_DEBUG ?= $(PLATFORM_BUILD_DIR)/smb.dbg
PLATFORM_RUNTIME_RESULT ?= $(PLATFORM_BUILD_DIR)/runtime.txt
PLATFORM_RUNTIME_LUA ?= $(PROJECT_DIR)scripts/workflow/validate_platform_runtime.lua
ifeq ($(PLATFORM),vs_smb)
PLATFORM_SOURCE ?= $(PROJECT_DIR)src/revisions/vs.asm
PLATFORM_CFG ?= $(NATIVE_CFG)
PLATFORM_REFERENCE ?= $(PROJECT_DIR)VS. Super Mario Bros. (VS).nes
PLATFORM_OUTPUT ?= $(PLATFORM_BUILD_DIR)/smb.nes
else ifeq ($(PLATFORM),fds_smb)
PLATFORM_SOURCE ?= $(PROJECT_DIR)src/revisions/fds_smb.asm
PLATFORM_CFG ?= $(PROJECT_DIR)config/linker/fds_prg.cfg
PLATFORM_REFERENCE ?= $(PROJECT_DIR)Super Mario Brothers (Japan).fds
PLATFORM_OUTPUT ?= $(PLATFORM_BUILD_DIR)/smb.fds
else ifeq ($(PLATFORM),ann_fds)
PLATFORM_SOURCE ?= $(PROJECT_DIR)src/revisions/ann/main.asm
PLATFORM_CFG ?= $(PROJECT_DIR)config/linker/fds_prg.cfg
PLATFORM_REFERENCE ?= $(PROJECT_DIR)All Night Nippon Super Mario Brothers (Japan) (Promotion Card).fds
PLATFORM_OUTPUT ?= $(PLATFORM_BUILD_DIR)/smb.fds
PLATFORM_PAYLOAD_ARGS = \
	--payload NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin \
	--payload NSMDATA3=$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.bin \
	--payload NSMDATA4=$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.bin
else
PLATFORM_SOURCE ?= $(PROJECT_DIR)src/platforms/$(PLATFORM).asm
PLATFORM_CFG ?= $(NATIVE_CFG)
PLATFORM_REFERENCE ?= $(PROJECT_DIR)$(PLATFORM)
PLATFORM_OUTPUT ?= $(PLATFORM_BUILD_DIR)/smb.nes
endif

ifeq ($(CONTENT_PROFILE),fds_smb)
CONTENT_BASE_DIR = $(PROJECT_DIR)build/platforms/fds_smb
CONTENT_BASE_PRG = $(CONTENT_BASE_DIR)/smb.prg
CONTENT_BASE_LABELS = $(CONTENT_BASE_DIR)/smb.lbl
CONTENT_ROM = $(CONTENT_BUILD_DIR)/smb.fds
CONTENT_LOAD_ADDRESS = 0x6000
CONTENT_PREPARE_COMMAND = $(MAKE) build-platform PLATFORM=fds_smb
CONTENT_CONTAINER_ARGS = --template "$(PLATFORM_ASSET_DIR)/fds_smb/template.fds"
else ifeq ($(CONTENT_PROFILE),vs_smb)
CONTENT_BASE_DIR = $(PROJECT_DIR)build/platforms/vs_smb
CONTENT_BASE_PRG = $(CONTENT_BASE_DIR)/smb.prg
CONTENT_BASE_LABELS = $(CONTENT_BASE_DIR)/smb.lbl
CONTENT_HEADER = $(PLATFORM_ASSET_DIR)/vs_smb/header.bin
CONTENT_CHR = $(PLATFORM_ASSET_DIR)/vs_smb/chr.bin
CONTENT_ROM = $(CONTENT_BUILD_DIR)/smb.nes
CONTENT_PREPARE_COMMAND = $(MAKE) build-platform PLATFORM=vs_smb
CONTENT_CONTAINER_ARGS = --header "$(CONTENT_HEADER)"
else ifeq ($(CONTENT_PROFILE),ann_fds)
CONTENT_BASE_DIR = $(PROJECT_DIR)build/platforms/ann_fds
CONTENT_BASE_PRG = $(CONTENT_BASE_DIR)/smb.prg
CONTENT_BASE_LABELS = $(CONTENT_BASE_DIR)/smb.lbl
CONTENT_CHR = $(PLATFORM_ASSET_DIR)/ann_fds/template.fds
CONTENT_ROM = $(CONTENT_BUILD_DIR)/smb.fds
CONTENT_LOAD_ADDRESS = 0x6000
CONTENT_PREPARE_COMMAND = $(MAKE) build-platform PLATFORM=ann_fds
CONTENT_CONTAINER_ARGS = --template "$(PLATFORM_ASSET_DIR)/ann_fds/template.fds"
CONTENT_PAYLOAD_ARGS = \
	--payload NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin \
	--payload NSMDATA3=$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.bin \
	--payload NSMDATA4=$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.bin \
	--payload-labels NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.lbl \
	--payload-labels NSMDATA3=$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.lbl \
	--payload-labels NSMDATA4=$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.lbl
STUDIO_CONTENT_PAYLOAD_ARGS = \
	--content-payload NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin \
	--content-payload NSMDATA3=$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.bin \
	--content-payload NSMDATA4=$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.bin \
	--content-payload-labels NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.lbl \
	--content-payload-labels NSMDATA3=$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.lbl \
	--content-payload-labels NSMDATA4=$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.lbl
endif

.DEFAULT_GOAL := build

.PHONY: build verify verify-all build-prg verify-prg build-hack verify-hack validate-hack build-expanded verify-expanded validate-expanded prepare-content-profile init-content export-content validate-content build-content run-content check-studios check-content-profile check-content-profiles world-studio level-studio smoke-level-playtest graphics-studio sound-studio world-editor level-editor graphics-editor sound-editor list-content-profiles content-profile-audit split-revision-assets build-revision verify-revision validate-revision verify-revisions validate-revisions split-platform-assets build-platform verify-platform validate-platform verify-platforms validate-platforms split-smb2-assets build-smb2-identity verify-smb2-identity build-smb2-source verify-smb2-source build-smb2 verify-smb2 build-ann-payloads build-ann-supplemental-courses build-ann-ending-audio build-ann-extended-courses verify-ann-audio verify-ann-tail-core verify-ann-supplemental-courses verify-ann-ending-audio verify-ann-extended-courses symbols validate-symbols trace trace-runtime validate-runtime roundtrip-formats release-audit release-check source-2-audit source-2-release-audit source-2-check source-3-audit semantic-evidence audit-enemy-streams audit-unreachable-code trace-semantic-runtime validate-semantic-runtime later-engine-feasibility test-relocation test-relocation-revisions test-platform-relocations test-ann-main-relocation validate-relocation validate-revision-relocation validate-platform-relocation validate-relocation-revisions validate-relocation-platforms split split-all check-assets lint format test trace-player clean _require-assets

build: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/build_native.py" \
		--source "$(NATIVE_SOURCE)" \
		--config "$(NATIVE_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--original-rom "$(ORIGINAL_ROM)" \
		--header "$(GENERATED_HEADER)" \
		--chr "$(GENERATED_CHR)" \
		--object "$(NATIVE_OBJ)" \
		--prg "$(NATIVE_PRG)" \
		--labels "$(NATIVE_LABELS)" \
		--map "$(NATIVE_MAP)" \
		--debug-info "$(NATIVE_DEBUG)" \
		--output-rom "$(NATIVE_ROM)"

verify: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/build_native.py" \
		--source "$(NATIVE_SOURCE)" \
		--config "$(NATIVE_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--original-rom "$(ORIGINAL_ROM)" \
		--header "$(GENERATED_HEADER)" \
		--chr "$(GENERATED_CHR)" \
		--object "$(NATIVE_OBJ)" \
		--prg "$(NATIVE_PRG)" \
		--labels "$(NATIVE_LABELS)" \
		--map "$(NATIVE_MAP)" \
		--debug-info "$(NATIVE_DEBUG)" \
		--output-rom "$(NATIVE_ROM)" \
		--verify

build-prg:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_native.py" \
		--source "$(NATIVE_SOURCE)" \
		--config "$(NATIVE_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--object "$(NATIVE_OBJ)" \
		--prg "$(NATIVE_PRG)" \
		--labels "$(NATIVE_LABELS)" \
		--map "$(NATIVE_MAP)" \
		--debug-info "$(NATIVE_DEBUG)" \
		--output-rom "$(NATIVE_ROM)" \
		--prg-only

verify-prg:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_native.py" \
		--source "$(NATIVE_SOURCE)" \
		--config "$(NATIVE_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--object "$(NATIVE_OBJ)" \
		--prg "$(NATIVE_PRG)" \
		--labels "$(NATIVE_LABELS)" \
		--map "$(NATIVE_MAP)" \
		--debug-info "$(NATIVE_DEBUG)" \
		--output-rom "$(NATIVE_ROM)" \
		--prg-only --verify

build-hack: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/build_native.py" \
		--source "$(HACK_SOURCE)" \
		--config "$(NATIVE_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--original-rom "$(ORIGINAL_ROM)" \
		--header "$(GENERATED_HEADER)" \
		--chr "$(GENERATED_CHR)" \
		--object "$(HACK_OBJ)" \
		--prg "$(HACK_PRG)" \
		--labels "$(HACK_LABELS)" \
		--map "$(HACK_MAP)" \
		--debug-info "$(HACK_DEBUG)" \
		--output-rom "$(HACK_ROM)"

verify-hack: build build-hack
	$(PYTHON) "$(PROJECT_DIR)scripts/fixed_variant.py" \
		--manifest "$(FIXED_VARIANT_MANIFEST)" \
		--variant "$(FIXED_VARIANT)" \
		--baseline-prg "$(NATIVE_PRG)" \
		--candidate-prg "$(HACK_PRG)" \
		--baseline-rom "$(NATIVE_ROM)" \
		--candidate-rom "$(HACK_ROM)"

validate-hack: verify-hack
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_fixed_variant.py" \
		--manifest "$(FIXED_VARIANT_MANIFEST)" \
		--variant "$(FIXED_VARIANT)" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(HACK_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(HACK_RUNTIME_LUA)" \
		--result "$(HACK_RUNTIME_RESULT)"

build-expanded: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/build_native.py" \
		--source "$(EXPANDED_SOURCE)" \
		--config "$(EXPANDED_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--object "$(EXPANDED_OBJ)" \
		--prg "$(EXPANDED_PRG)" \
		--labels "$(EXPANDED_LABELS)" \
		--map "$(EXPANDED_MAP)" \
		--debug-info "$(EXPANDED_DEBUG)" \
		--output-rom "$(EXPANDED_ROM)" \
		--prg-only --verify
	$(PYTHON) "$(PROJECT_DIR)scripts/expanded_rom.py" \
		--manifest "$(EXPANDED_MANIFEST)" \
		--prg "$(EXPANDED_PRG)" \
		--chr "$(GENERATED_CHR)" \
		--output "$(EXPANDED_ROM)"

verify-expanded: build-expanded
	$(PYTHON) "$(PROJECT_DIR)scripts/expanded_rom.py" \
		--manifest "$(EXPANDED_MANIFEST)" \
		--prg "$(EXPANDED_PRG)" \
		--chr "$(GENERATED_CHR)" \
		--output "$(EXPANDED_ROM)" \
		--verify

validate-expanded: verify-expanded
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_expanded_runtime.py" \
		--manifest "$(EXPANDED_MANIFEST)" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(EXPANDED_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(EXPANDED_RUNTIME_LUA)" \
		--result "$(EXPANDED_RUNTIME_RESULT)"

prepare-content-profile:
	$(PYTHON) "$(PROJECT_DIR)scripts/content_profiles.py" check \
		--manifest "$(CONTENT_PROFILE_MANIFEST)" \
		--profile "$(CONTENT_PROFILE)" \
		$(CONTENT_STUDIO_ARG)
	$(CONTENT_PREPARE_COMMAND)

init-content: prepare-content-profile
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" init \
		--formats "$(CONTENT_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--profiles "$(CONTENT_PROFILE_MANIFEST)" \
		--profile "$(CONTENT_PROFILE)" \
		--labels "$(CONTENT_BASE_LABELS)" \
		--prg "$(CONTENT_BASE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--chr "$(CONTENT_CHR)" \
		$(CONTENT_PAYLOAD_ARGS) \
		$(CONTENT_STUDIO_ARG)

export-content: prepare-content-profile
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" export \
		--formats "$(CONTENT_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--profiles "$(CONTENT_PROFILE_MANIFEST)" \
		--profile "$(CONTENT_PROFILE)" \
		--labels "$(CONTENT_BASE_LABELS)" \
		--prg "$(CONTENT_BASE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--chr "$(CONTENT_CHR)" \
		$(CONTENT_PAYLOAD_ARGS) \
		$(CONTENT_STUDIO_ARG)

validate-content: prepare-content-profile
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" validate \
		--formats "$(CONTENT_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--profiles "$(CONTENT_PROFILE_MANIFEST)" \
		--profile "$(CONTENT_PROFILE)" \
		--labels "$(CONTENT_BASE_LABELS)" \
		--prg "$(CONTENT_BASE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--chr "$(CONTENT_CHR)" \
		$(CONTENT_PAYLOAD_ARGS) \
		--report "$(CONTENT_REPORT)" \
		$(CONTENT_STUDIO_ARG)

build-content: prepare-content-profile
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" build \
		--formats "$(CONTENT_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--profiles "$(CONTENT_PROFILE_MANIFEST)" \
		--profile "$(CONTENT_PROFILE)" \
		--labels "$(CONTENT_BASE_LABELS)" \
		--prg "$(CONTENT_BASE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--chr "$(CONTENT_CHR)" \
		$(CONTENT_PAYLOAD_ARGS) \
		$(CONTENT_CONTAINER_ARGS) \
		--output-prg "$(CONTENT_PRG)" \
		--output-rom "$(CONTENT_ROM)" \
		--report "$(CONTENT_REPORT)" \
		$(CONTENT_STUDIO_ARG)

check-studios: init-content
	$(PYTHON) "$(PROJECT_DIR)scripts/world_studio.py" $(STUDIO_COMMON_ARGS) --check
	$(PYTHON) "$(PROJECT_DIR)scripts/level_studio.py" $(STUDIO_COMMON_ARGS) \
		--content-image "$(CONTENT_ROM)" --check
	$(PYTHON) "$(PROJECT_DIR)scripts/graphics_studio.py" $(STUDIO_COMMON_ARGS) --check
	$(PYTHON) "$(PROJECT_DIR)scripts/sound_studio.py" $(STUDIO_COMMON_ARGS) \
		--prg "$(CONTENT_BASE_PRG)" --load-address "$(CONTENT_LOAD_ADDRESS)" --check

check-content-profile:
	$(MAKE) export-content \
		CONTENT_PROFILE=$(CONTENT_PROFILE) \
		CONTENT_WORKSPACE=$(CONTENT_ROUNDTRIP_DIR)/workspace
	$(MAKE) check-studios \
		CONTENT_PROFILE=$(CONTENT_PROFILE) \
		CONTENT_WORKSPACE=$(CONTENT_ROUNDTRIP_DIR)/workspace
	$(MAKE) build-content \
		CONTENT_PROFILE=$(CONTENT_PROFILE) \
		CONTENT_WORKSPACE=$(CONTENT_ROUNDTRIP_DIR)/workspace \
		CONTENT_BUILD_DIR=$(CONTENT_ROUNDTRIP_DIR)/output

check-content-profiles:
	$(MAKE) check-content-profile CONTENT_PROFILE=ju
	$(MAKE) check-content-profile CONTENT_PROFILE=pc10
	$(MAKE) check-content-profile CONTENT_PROFILE=pal
	$(MAKE) check-content-profile CONTENT_PROFILE=vs_smb
	$(MAKE) check-content-profile CONTENT_PROFILE=fds_smb
	$(MAKE) check-content-profile CONTENT_PROFILE=ann_fds

run-content: build-content
	"$(FCEUX_EXE)" "$(CONTENT_ROM)"

world-studio:
	$(MAKE) init-content STUDIO=world
	$(PYTHON) "$(PROJECT_DIR)scripts/world_studio.py" $(STUDIO_COMMON_ARGS)

level-studio:
	$(MAKE) init-content STUDIO=world
	$(MAKE) init-content STUDIO=level
	$(MAKE) init-content STUDIO=graphics
	$(PYTHON) "$(PROJECT_DIR)scripts/level_studio.py" $(STUDIO_COMMON_ARGS) \
		--content-image "$(CONTENT_ROM)" $(LEVEL_STUDIO_ARGS)

smoke-level-playtest:
	$(MAKE) level-studio CONTENT_PROFILE=$(CONTENT_PROFILE) \
		LEVEL_STUDIO_ARGS="$(PLAYTEST_BANK_ARG) $(PLAYTEST_AREA_ARG) --smoke-playtest $(PLAYTEST_THEME)"

graphics-studio:
	$(MAKE) init-content STUDIO=graphics
	$(PYTHON) "$(PROJECT_DIR)scripts/graphics_studio.py" $(STUDIO_COMMON_ARGS)

sound-studio:
	$(MAKE) init-content STUDIO=sound
	$(PYTHON) "$(PROJECT_DIR)scripts/sound_studio.py" $(STUDIO_COMMON_ARGS) \
		--prg "$(CONTENT_BASE_PRG)" --load-address "$(CONTENT_LOAD_ADDRESS)"

world-editor: world-studio
level-editor: level-studio
graphics-editor: graphics-studio
sound-editor: sound-studio

split-revision-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/revision_profiles.py" split \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(PROFILE)" \
		--reference-rom "$(REVISION_REFERENCE)" \
		--asset-dir "$(REVISION_ASSET_DIR)"

build-revision: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/build_native.py" \
		--source "$(REVISION_SOURCE)" \
		--config "$(NATIVE_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--object "$(REVISION_OBJ)" \
		--prg "$(REVISION_PRG)" \
		--labels "$(REVISION_LABELS)" \
		--map "$(REVISION_MAP)" \
		--debug-info "$(REVISION_DEBUG)" \
		--output-rom "$(REVISION_ROM)" \
		--prg-only
	$(PYTHON) "$(PROJECT_DIR)scripts/revision_profiles.py" build \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(PROFILE)" \
		--asset-dir "$(REVISION_ASSET_DIR)" \
		--header "$(GENERATED_HEADER)" \
		--prg "$(REVISION_PRG)" \
		--chr "$(GENERATED_CHR)" \
		--output "$(REVISION_ROM)"

verify-revision: build-revision
	$(PYTHON) "$(PROJECT_DIR)scripts/revision_profiles.py" verify \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(PROFILE)" \
		--reference-rom "$(REVISION_REFERENCE)" \
		--asset-dir "$(REVISION_ASSET_DIR)" \
		--header "$(GENERATED_HEADER)" \
		--prg "$(REVISION_PRG)" \
		--chr "$(GENERATED_CHR)" \
		--output "$(REVISION_ROM)"

validate-revision: verify-revision
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_revision_runtime.py" \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(PROFILE)" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(REVISION_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(EXPANDED_RUNTIME_LUA)" \
		--result "$(REVISION_RUNTIME_RESULT)"

verify-revisions:
	$(MAKE) verify-revision PROFILE=ju
	$(MAKE) verify-revision PROFILE=pc10
	$(MAKE) verify-revision PROFILE=pal

validate-revisions:
	$(MAKE) validate-revision PROFILE=ju
	$(MAKE) validate-revision PROFILE=pc10
	$(MAKE) validate-revision PROFILE=pal

split-platform-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/platform_profiles.py" split \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile "$(PLATFORM)" \
		--reference "$(PLATFORM_REFERENCE)" \
		--asset-dir "$(PLATFORM_ASSET_DIR)"

split-smb2-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/platform_profiles.py" split \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--reference "$(SMB2_REFERENCE)" \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--retain-primary

build-smb2-identity:
	$(PYTHON) "$(PROJECT_DIR)scripts/platform_profiles.py" build \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--output "$(SMB2_IDENTITY_IMAGE)"

verify-smb2-identity: build-smb2-identity
	$(PYTHON) "$(PROJECT_DIR)scripts/platform_profiles.py" verify \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--reference "$(SMB2_REFERENCE)" \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--output "$(SMB2_IDENTITY_IMAGE)"

build-smb2-source:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_smb2_source.py" \
		--manifest "$(SMB2_RECONSTRUCTION_MANIFEST)" \
		--output-dir "$(SMB2_SOURCE_BUILD_DIR)"

verify-smb2-source:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_smb2_source.py" \
		--manifest "$(SMB2_RECONSTRUCTION_MANIFEST)" \
		--output-dir "$(SMB2_SOURCE_BUILD_DIR)" \
		--verify

build-smb2: build-smb2-source
	$(PYTHON) "$(PROJECT_DIR)scripts/platform_profiles.py" build \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--prg "$(SMB2_SOURCE_BUILD_DIR)/SM2MAIN.bin" \
		--payload "SM2DATA2=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA2.bin" \
		--payload "SM2DATA3=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA3.bin" \
		--payload "SM2DATA4=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA4.bin" \
		--output "$(SMB2_SOURCE_IMAGE)"

verify-smb2: verify-smb2-source
	$(PYTHON) "$(PROJECT_DIR)scripts/platform_profiles.py" verify \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--reference "$(SMB2_REFERENCE)" \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--prg "$(SMB2_SOURCE_BUILD_DIR)/SM2MAIN.bin" \
		--payload "SM2DATA2=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA2.bin" \
		--payload "SM2DATA3=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA3.bin" \
		--payload "SM2DATA4=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA4.bin" \
		--output "$(SMB2_SOURCE_IMAGE)"

ifeq ($(PLATFORM),ann_fds)
build-platform: build-ann-payloads
endif

build-platform:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_native.py" \
		--source "$(PLATFORM_SOURCE)" \
		--config "$(PLATFORM_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--object "$(PLATFORM_OBJ)" \
		--prg "$(PLATFORM_PRG)" \
		--labels "$(PLATFORM_LABELS)" \
		--map "$(PLATFORM_MAP)" \
		--debug-info "$(PLATFORM_DEBUG)" \
		--output-rom "$(PLATFORM_OUTPUT)" \
		--prg-only
	$(PYTHON) "$(PROJECT_DIR)scripts/platform_profiles.py" build \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile "$(PLATFORM)" \
		--asset-dir "$(PLATFORM_ASSET_DIR)" \
		--prg "$(PLATFORM_PRG)" \
		$(PLATFORM_PAYLOAD_ARGS) \
		--output "$(PLATFORM_OUTPUT)"

verify-platform: build-platform
	$(PYTHON) "$(PROJECT_DIR)scripts/platform_profiles.py" verify \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile "$(PLATFORM)" \
		--reference "$(PLATFORM_REFERENCE)" \
		--asset-dir "$(PLATFORM_ASSET_DIR)" \
		--prg "$(PLATFORM_PRG)" \
		$(PLATFORM_PAYLOAD_ARGS) \
		--output "$(PLATFORM_OUTPUT)"

validate-platform: verify-platform
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_platform_runtime.py" \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile "$(PLATFORM)" \
		--fceux "$(FCEUX_EXE)" \
		--fds-bios "$(FDS_BIOS)" \
		--image "$(PLATFORM_OUTPUT)" \
		--lua "$(PLATFORM_RUNTIME_LUA)" \
		--result "$(PLATFORM_RUNTIME_RESULT)"

verify-platforms:
	$(MAKE) verify-platform PLATFORM=vs_smb
	$(MAKE) verify-platform PLATFORM=fds_smb
	$(MAKE) verify-platform PLATFORM=ann_fds

verify-all:
	$(PYTHON) "$(PROJECT_DIR)scripts/run_make_matrix.py" \
		--project-dir "$(PROJECT_DIR)" \
		--make "$(MAKE)" \
		--title "ROM verification matrix" \
		--step "verify" \
		--step "verify-revision PROFILE=ju" \
		--step "verify-revision PROFILE=pc10" \
		--step "verify-revision PROFILE=pal" \
		--step "verify-platform PLATFORM=vs_smb" \
		--step "verify-platform PLATFORM=fds_smb" \
		--step "verify-platform PLATFORM=ann_fds"

verify-ann-audio:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_asm_range.py" \
		--source "$(ANN_AUDIO_SOURCE)" \
		--config "$(ANN_AUDIO_CFG)" \
		--object "$(ANN_AUDIO_BUILD_DIR)/audio.o" \
		--output "$(ANN_AUDIO_BUILD_DIR)/audio.bin" \
		--labels "$(ANN_AUDIO_BUILD_DIR)/audio.lbl" \
		--map "$(ANN_AUDIO_BUILD_DIR)/audio.map"
	$(PYTHON) "$(PROJECT_DIR)scripts/verify_platform_range.py" \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_AUDIO_BUILD_DIR)/audio.bin" \
		--load-address 0x6000 \
		--start 0xD2E4 \
		--end 0xDFFA

verify-ann-tail-core:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_asm_range.py" \
		--source "$(ANN_TAIL_CORE_SOURCE)" \
		--config "$(ANN_TAIL_CORE_CFG)" \
		--object "$(ANN_TAIL_BUILD_DIR)/core.o" \
		--output "$(ANN_TAIL_BUILD_DIR)/core.bin" \
		--labels "$(ANN_TAIL_BUILD_DIR)/core.lbl" \
		--map "$(ANN_TAIL_BUILD_DIR)/core.map"
	$(PYTHON) "$(PROJECT_DIR)scripts/verify_platform_range.py" \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_TAIL_BUILD_DIR)/core.bin" \
		--load-address 0x6000 \
		--start 0xBFBF \
		--end 0xE000

build-ann-payloads: build-ann-supplemental-courses build-ann-ending-audio build-ann-extended-courses

build-ann-supplemental-courses:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_asm_range.py" \
		--source "$(ANN_SUPPLEMENTAL_COURSES_SOURCE)" \
		--config "$(ANN_SUPPLEMENTAL_COURSES_CFG)" \
		--object "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.o" \
		--output "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin" \
		--labels "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.lbl" \
		--map "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.map"

verify-ann-supplemental-courses: build-ann-supplemental-courses
	$(PYTHON) "$(PROJECT_DIR)scripts/verify_platform_range.py" \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin" \
		--payload NSMDATA2 \
		--load-address 0xC470 \
		--start 0xC470 \
		--end 0xD270

build-ann-ending-audio:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_asm_range.py" \
		--source "$(ANN_ENDING_AUDIO_SOURCE)" \
		--config "$(ANN_ENDING_AUDIO_CFG)" \
		--object "$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.o" \
		--output "$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.bin" \
		--labels "$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.lbl" \
		--map "$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.map"

verify-ann-ending-audio: build-ann-ending-audio
	$(PYTHON) "$(PROJECT_DIR)scripts/verify_platform_range.py" \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_ENDING_AUDIO_BUILD_DIR)/payload.bin" \
		--payload NSMDATA3 \
		--load-address 0xC5D0 \
		--start 0xC5D0 \
		--end 0xD2E2

build-ann-extended-courses:
	$(PYTHON) "$(PROJECT_DIR)scripts/build_asm_range.py" \
		--source "$(ANN_EXTENDED_COURSES_SOURCE)" \
		--config "$(ANN_EXTENDED_COURSES_CFG)" \
		--object "$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.o" \
		--output "$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.bin" \
		--labels "$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.lbl" \
		--map "$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.map"

verify-ann-extended-courses: build-ann-extended-courses
	$(PYTHON) "$(PROJECT_DIR)scripts/verify_platform_range.py" \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_EXTENDED_COURSES_BUILD_DIR)/payload.bin" \
		--payload NSMDATA4 \
		--load-address 0xC296 \
		--start 0xC296 \
		--end 0xD086

validate-platforms:
	$(MAKE) validate-platform PLATFORM=vs_smb
	$(MAKE) validate-platform PLATFORM=fds_smb
	$(MAKE) validate-platform PLATFORM=ann_fds

symbols: build
	$(PYTHON) "$(PROJECT_DIR)scripts/debug_symbols.py" \
		--debug "$(NATIVE_DEBUG)" \
		--map "$(NATIVE_MAP)" \
		--labels "$(NATIVE_LABELS)" \
		--rom "$(NATIVE_ROM)" \
		--fceux-output-dir "$(FCEUX_SYMBOL_DIR)" \
		--breakpoints "$(DEBUG_BREAKPOINTS)" \
		--watches "$(DEBUG_WATCHES)" \
		--summary "$(DEBUG_SUMMARY)"

validate-symbols: symbols
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_debug_runtime.py" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(NATIVE_ROM)" \
		--summary "$(DEBUG_SUMMARY)" \
		--lua "$(DEBUG_RUNTIME_LUA)" \
		--result "$(DEBUG_RUNTIME_RESULT)"

trace-runtime: symbols
	$(PYTHON) "$(PROJECT_DIR)scripts/run_runtime_scenarios.py" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(NATIVE_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(RUNTIME_TRACE_LUA)" \
		--scenarios "$(RUNTIME_SCENARIOS)" \
		--output-dir "$(RUNTIME_TRACE_DIR)"
	$(MAKE) validate-runtime

validate-runtime:
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_runtime_scenarios.py" \
		--scenarios "$(RUNTIME_SCENARIOS)" \
		--trace-dir "$(RUNTIME_TRACE_DIR)"

trace: validate-symbols trace-runtime

roundtrip-formats: build-prg
	$(PYTHON) "$(PROJECT_DIR)scripts/data_formats.py" \
		--manifest "$(DATA_FORMAT_MANIFEST)" \
		--labels "$(NATIVE_LABELS)" \
		--prg "$(NATIVE_PRG)" \
		--project-root "$(PROJECT_DIR)" \
		--summary "$(DATA_FORMAT_SUMMARY)"

release-audit:
	$(PYTHON) "$(PROJECT_DIR)scripts/release_audit.py" \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(RELEASE_MANIFEST)"

release-check:
	$(MAKE) lint
	$(MAKE) test
	$(MAKE) roundtrip-formats
	$(MAKE) verify
	$(MAKE) trace
	$(MAKE) release-audit

source-2-audit:
	$(PYTHON) "$(PROJECT_DIR)scripts/source_2_audit.py" \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(SOURCE_2_MANIFEST)"

source-2-release-audit:
	$(PYTHON) "$(PROJECT_DIR)scripts/source_2_audit.py" \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(SOURCE_2_MANIFEST)" \
		--require-ready

source-2-check:
	$(MAKE) release-check
	$(MAKE) validate-hack
	$(MAKE) validate-expanded
	$(MAKE) check-studios
	$(MAKE) validate-revisions
	$(MAKE) validate-platforms
	$(MAKE) source-2-release-audit

source-3-audit:
	$(PYTHON) "$(PROJECT_DIR)scripts/source_3_audit.py" \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(SOURCE_3_MANIFEST)"

list-content-profiles:
	$(PYTHON) "$(PROJECT_DIR)scripts/content_profiles.py" list \
		--manifest "$(CONTENT_PROFILE_MANIFEST)"

content-profile-audit:
	$(PYTHON) "$(PROJECT_DIR)scripts/content_profiles.py" audit \
		--manifest "$(CONTENT_PROFILE_MANIFEST)"

semantic-evidence: audit-enemy-streams audit-unreachable-code trace-semantic-runtime

later-engine-feasibility:
	$(PYTHON) "$(PROJECT_DIR)scripts/later_engine_feasibility.py" \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(LATER_ENGINE_MANIFEST)" \
		--output "$(LATER_ENGINE_REPORT)"

trace-semantic-runtime: symbols
	$(PYTHON) "$(PROJECT_DIR)scripts/run_runtime_scenarios.py" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(NATIVE_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(RUNTIME_TRACE_LUA)" \
		--scenarios "$(SEMANTIC_RUNTIME_SCENARIOS)" \
		--output-dir "$(SEMANTIC_RUNTIME_TRACE_DIR)"
	$(MAKE) validate-semantic-runtime

validate-semantic-runtime:
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_runtime_scenarios.py" \
		--scenarios "$(SEMANTIC_RUNTIME_SCENARIOS)" \
		--trace-dir "$(SEMANTIC_RUNTIME_TRACE_DIR)"

audit-unreachable-code: verify
	$(PYTHON) "$(PROJECT_DIR)scripts/audit_unreachable_code.py" \
		--manifest "$(UNREACHABLE_CODE_EVIDENCE_MANIFEST)" \
		--debug "$(NATIVE_DEBUG)" \
		--prg "$(NATIVE_PRG)" \
		--output "$(UNREACHABLE_CODE_EVIDENCE_REPORT)"

audit-enemy-streams:
	$(MAKE) verify-revision PROFILE=ju
	$(MAKE) verify-revision PROFILE=pc10
	$(MAKE) verify-revision PROFILE=pal
	$(MAKE) verify-platform PLATFORM=vs_smb
	$(MAKE) verify-platform PLATFORM=fds_smb
	$(MAKE) verify-platform PLATFORM=ann_fds
	$(PYTHON) "$(PROJECT_DIR)scripts/audit_enemy_streams.py" \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(ENEMY_STREAM_EVIDENCE_MANIFEST)" \
		--output "$(ENEMY_STREAM_EVIDENCE_REPORT)"

test-relocation:
	$(MAKE) $(RELOCATION_VERIFY_TARGET)
	$(PYTHON) "$(PROJECT_DIR)scripts/relocation_test.py" \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(RELOCATION_MANIFEST)" \
		--base-prg "$(RELOCATION_BASE_PRG)" \
		--base-labels "$(RELOCATION_BASE_LABELS)" \
		--base-debug "$(RELOCATION_BASE_DEBUG)" \
		--original-rom "$(RELOCATION_REFERENCE)"

test-relocation-revisions:
	$(MAKE) test-relocation RELOCATION_PROFILE=ju
	$(MAKE) test-relocation RELOCATION_PROFILE=pc10
	$(MAKE) test-relocation RELOCATION_PROFILE=pal

test-platform-relocations:
	$(MAKE) test-relocation RELOCATION_PROFILE=vs_smb
	$(MAKE) test-relocation RELOCATION_PROFILE=fds_smb
	$(MAKE) test-relocation RELOCATION_PROFILE=ann_fds

test-ann-main-relocation:
	$(MAKE) test-relocation RELOCATION_PROFILE=ann_fds

validate-relocation: test-relocation
	$(PYTHON) "$(PROJECT_DIR)scripts/debug_symbols.py" \
		--debug "$(RELOCATION_DEBUG)" \
		--map "$(RELOCATION_MAP)" \
		--labels "$(RELOCATION_LABELS)" \
		--rom "$(RELOCATION_ROM)" \
		--fceux-output-dir "$(RELOCATION_BUILD_DIR)" \
		--breakpoints "$(DEBUG_BREAKPOINTS)" \
		--watches "$(DEBUG_WATCHES)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)"
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_debug_runtime.py" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(RELOCATION_ROM)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)" \
		--lua "$(DEBUG_RUNTIME_LUA)" \
		--result "$(RELOCATION_DEBUG_RESULT)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run_runtime_scenarios.py" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(RELOCATION_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(RUNTIME_TRACE_LUA)" \
		--scenarios "$(RELOCATION_SCENARIOS)" \
		--output-dir "$(RELOCATION_TRACE_DIR)"
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_runtime_scenarios.py" \
		--scenarios "$(RELOCATION_SCENARIOS)" \
		--trace-dir "$(RELOCATION_TRACE_DIR)"

validate-revision-relocation: test-relocation
	$(PYTHON) "$(PROJECT_DIR)scripts/debug_symbols.py" \
		--debug "$(RELOCATION_DEBUG)" \
		--map "$(RELOCATION_MAP)" \
		--labels "$(RELOCATION_LABELS)" \
		--rom "$(RELOCATION_ROM)" \
		--fceux-output-dir "$(RELOCATION_BUILD_DIR)" \
		--breakpoints "$(DEBUG_BREAKPOINTS)" \
		--watches "$(DEBUG_WATCHES)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)"
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_debug_runtime.py" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(RELOCATION_ROM)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)" \
		--lua "$(DEBUG_RUNTIME_LUA)" \
		--result "$(RELOCATION_DEBUG_RESULT)" \
		$(RELOCATION_PAL_ARG)
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_revision_runtime.py" \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(RELOCATION_PROFILE)" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(RELOCATION_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(EXPANDED_RUNTIME_LUA)" \
		--result "$(RELOCATION_REVISION_RESULT)" \
		--forbidden-manifest "$(RELOCATION_SCENARIOS)"

validate-platform-relocation: test-relocation
	$(PYTHON) "$(PROJECT_DIR)scripts/debug_symbols.py" \
		--debug "$(RELOCATION_DEBUG)" \
		--map "$(RELOCATION_MAP)" \
		--labels "$(RELOCATION_LABELS)" \
		--rom "$(RELOCATION_ROM)" \
		--fceux-output-dir "$(RELOCATION_BUILD_DIR)" \
		--breakpoints "$(DEBUG_BREAKPOINTS)" \
		--watches "$(DEBUG_WATCHES)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)" \
		$(RELOCATION_DEBUG_CONTAINER_ARG)
	$(PYTHON) "$(PROJECT_DIR)scripts/validate_platform_runtime.py" \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile "$(RELOCATION_PROFILE)" \
		--fceux "$(FCEUX_EXE)" \
		--fds-bios "$(FDS_BIOS)" \
		--image "$(RELOCATION_ROM)" \
		--lua "$(PLATFORM_RUNTIME_LUA)" \
		--result "$(RELOCATION_PLATFORM_RESULT)" \
		--forbidden-manifest "$(RELOCATION_SCENARIOS)"

validate-relocation-revisions:
	$(MAKE) validate-relocation RELOCATION_PROFILE=ju
	$(MAKE) validate-relocation RELOCATION_PROFILE=pc10
	$(MAKE) validate-revision-relocation RELOCATION_PROFILE=pal

validate-relocation-platforms:
	$(MAKE) validate-platform-relocation RELOCATION_PROFILE=vs_smb
	$(MAKE) validate-platform-relocation RELOCATION_PROFILE=fds_smb
	$(MAKE) validate-platform-relocation RELOCATION_PROFILE=ann_fds

split:
	$(PYTHON) "$(PROJECT_DIR)scripts/split_assets.py" \
		--rom "$(ORIGINAL_ROM)" \
		--manifest "$(ASSET_MANIFEST)" \
		--output-dir "$(GENERATED_ASSET_DIR)"

split-all:
	$(PYTHON) "$(PROJECT_DIR)scripts/run_make_matrix.py" \
		--project-dir "$(PROJECT_DIR)" \
		--make "$(MAKE)" \
		--title "ROM asset split matrix" \
		--step "split" \
		--step "split-revision-assets PROFILE=pc10" \
		--step "split-revision-assets PROFILE=pal" \
		--step "split-platform-assets PLATFORM=vs_smb" \
		--step "split-platform-assets PLATFORM=fds_smb" \
		--step "split-platform-assets PLATFORM=ann_fds"

check-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/check_assets.py" \
		--manifest "$(ASSET_MANIFEST)" \
		--asset-dir "$(GENERATED_ASSET_DIR)"

lint:
	$(PYTHON) "$(PROJECT_DIR)scripts/asm_style.py" "$(PROJECT_DIR)src"
	$(PYTHON) "$(PROJECT_DIR)scripts/lint_source.py" "$(PROJECT_DIR)"
	$(PYTHON) "$(PROJECT_DIR)scripts/lint_project.py" "$(PROJECT_DIR)"

format:
	$(PYTHON) "$(PROJECT_DIR)scripts/asm_style.py" --fix "$(PROJECT_DIR)src"

test:
	$(PYTHON) -m unittest discover -s "$(PROJECT_DIR)tests" -p "test_*.py"

trace-player:
	$(PYTHON) "$(PROJECT_DIR)scripts/player_physics.py"

_require-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/check_assets.py" \
		--manifest "$(ASSET_MANIFEST)" \
		--asset-dir "$(GENERATED_ASSET_DIR)"

clean:
	$(PYTHON) "$(PROJECT_DIR)scripts/clean_artifacts.py" \
		--project-root "$(PROJECT_DIR)" \
		--path "$(NATIVE_BUILD_DIR)"
