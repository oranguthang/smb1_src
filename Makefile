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
DATA_FORMAT_MANIFEST ?= $(PROJECT_DIR)config/data_formats.json
DATA_FORMAT_SUMMARY ?= $(PROJECT_DIR)build/data_formats.json
CONTENT_FORMAT_MANIFEST ?= $(PROJECT_DIR)config/content_formats.json
RELEASE_MANIFEST ?= $(PROJECT_DIR)config/preservation_source_1_0.json
SOURCE_2_MANIFEST ?= $(PROJECT_DIR)config/source_reconstruction_2_0.json
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
CONTENT_WORKSPACE ?= $(PROJECT_DIR)content/workspace
CONTENT_BUILD_DIR ?= $(PROJECT_DIR)build/content
CONTENT_PRG ?= $(CONTENT_BUILD_DIR)/smb.prg
CONTENT_ROM ?= $(CONTENT_BUILD_DIR)/smb.nes
CONTENT_REPORT ?= $(CONTENT_BUILD_DIR)/diff_report.json
CONTENT_STUDIO_ARG := $(if $(STUDIO),--studio "$(STUDIO)",)
STUDIO_COMMON_ARGS = \
	--formats "$(CONTENT_FORMAT_MANIFEST)" \
	--studios "$(CONTENT_STUDIO_MANIFEST)" \
	--workspace "$(CONTENT_WORKSPACE)" \
	--labels "$(NATIVE_LABELS)" \
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

.DEFAULT_GOAL := build

.PHONY: build verify verify-all build-prg verify-prg build-hack verify-hack validate-hack build-expanded verify-expanded validate-expanded init-content export-content validate-content build-content run-content check-studios world-studio level-studio graphics-studio sound-studio world-editor level-editor graphics-editor sound-editor split-revision-assets build-revision verify-revision validate-revision verify-revisions validate-revisions split-platform-assets build-platform verify-platform validate-platform verify-platforms validate-platforms build-ann-payloads build-ann-supplemental-courses build-ann-ending-audio build-ann-extended-courses verify-ann-audio verify-ann-tail-core verify-ann-supplemental-courses verify-ann-ending-audio verify-ann-extended-courses symbols validate-symbols trace trace-runtime validate-runtime roundtrip-formats release-audit release-check source-2-audit source-2-release-audit source-2-check split split-all check-assets lint format test trace-player clean _require-assets

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

init-content: build-prg
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" init \
		--formats "$(CONTENT_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--labels "$(NATIVE_LABELS)" \
		--prg "$(NATIVE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--chr "$(GENERATED_CHR)" \
		$(CONTENT_STUDIO_ARG)

export-content: build-prg
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" export \
		--formats "$(CONTENT_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--labels "$(NATIVE_LABELS)" \
		--prg "$(NATIVE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--chr "$(GENERATED_CHR)" \
		$(CONTENT_STUDIO_ARG)

validate-content: build-prg
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" validate \
		--formats "$(CONTENT_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--labels "$(NATIVE_LABELS)" \
		--prg "$(NATIVE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--chr "$(GENERATED_CHR)" \
		--report "$(CONTENT_REPORT)" \
		$(CONTENT_STUDIO_ARG)

build-content: build
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" build \
		--formats "$(CONTENT_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--labels "$(NATIVE_LABELS)" \
		--prg "$(NATIVE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--header "$(GENERATED_HEADER)" \
		--chr "$(GENERATED_CHR)" \
		--output-prg "$(CONTENT_PRG)" \
		--output-rom "$(CONTENT_ROM)" \
		--report "$(CONTENT_REPORT)" \
		$(CONTENT_STUDIO_ARG)

check-studios: init-content
	$(PYTHON) "$(PROJECT_DIR)scripts/world_studio.py" $(STUDIO_COMMON_ARGS) --check
	$(PYTHON) "$(PROJECT_DIR)scripts/level_studio.py" $(STUDIO_COMMON_ARGS) --check
	$(PYTHON) "$(PROJECT_DIR)scripts/graphics_studio.py" $(STUDIO_COMMON_ARGS) --check
	$(PYTHON) "$(PROJECT_DIR)scripts/sound_studio.py" $(STUDIO_COMMON_ARGS) --prg "$(NATIVE_PRG)" --check

run-content: build-content
	"$(FCEUX_EXE)" "$(CONTENT_ROM)"

world-studio:
	$(MAKE) init-content STUDIO=world
	$(PYTHON) "$(PROJECT_DIR)scripts/world_studio.py" $(STUDIO_COMMON_ARGS)

level-studio:
	$(MAKE) init-content STUDIO=level
	$(MAKE) init-content STUDIO=graphics
	$(PYTHON) "$(PROJECT_DIR)scripts/level_studio.py" $(STUDIO_COMMON_ARGS)

graphics-studio:
	$(MAKE) init-content STUDIO=graphics
	$(PYTHON) "$(PROJECT_DIR)scripts/graphics_studio.py" $(STUDIO_COMMON_ARGS)

sound-studio:
	$(MAKE) init-content STUDIO=sound
	$(PYTHON) "$(PROJECT_DIR)scripts/sound_studio.py" $(STUDIO_COMMON_ARGS) --prg "$(NATIVE_PRG)"

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
