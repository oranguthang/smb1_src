# Thin workflow entrypoints; platform-specific logic lives in Python.
PYTHON ?= python
PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ORIGINAL_ROM ?= $(PROJECT_DIR)Super Mario Bros. (JU) [!].nes
ASSET_MANIFEST ?= $(PROJECT_DIR)assets/manifest.json
GENERATED_ASSET_DIR ?= $(PROJECT_DIR)assets/generated
GENERATED_HEADER ?= $(GENERATED_ASSET_DIR)/header/smb.hdr
GENERATED_CHR ?= $(GENERATED_ASSET_DIR)/chr/smb.chr

NATIVE_SOURCE ?= $(PROJECT_DIR)src/main.asm
NATIVE_CFG ?= $(PROJECT_DIR)src/nrom256_prg_only.cfg
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
DEBUG_RUNTIME_LUA ?= $(PROJECT_DIR)scripts/workflow/validate_debug_symbols.lua
DEBUG_RUNTIME_RESULT ?= $(NATIVE_BUILD_DIR)/debug_symbols_runtime.txt
RUNTIME_MOVIE ?= $(PROJECT_DIR)movies/smb1_any_percent.fm2
RUNTIME_SCENARIOS ?= $(PROJECT_DIR)scenarios/runtime_scenarios.json
RUNTIME_TRACE_LUA ?= $(PROJECT_DIR)scripts/workflow/capture_runtime_scenario.lua
RUNTIME_TRACE_DIR ?= $(PROJECT_DIR)build/runtime
DATA_FORMAT_MANIFEST ?= $(PROJECT_DIR)config/data_formats.json
DATA_FORMAT_SUMMARY ?= $(PROJECT_DIR)build/data_formats.json
RELEASE_MANIFEST ?= $(PROJECT_DIR)config/preservation_source_1_0.json
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
EXPANDED_CFG ?= $(PROJECT_DIR)src/expanded/cnrom_prg_only.cfg
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
else
REVISION_REFERENCE ?= $(PROJECT_DIR)$(PROFILE).nes
endif

.DEFAULT_GOAL := build

.PHONY: build verify build-prg verify-prg build-hack verify-hack validate-hack build-expanded verify-expanded validate-expanded export-content validate-content build-content split-revision-assets build-revision verify-revision validate-revision verify-revisions validate-revisions symbols validate-symbols trace trace-runtime validate-runtime roundtrip-formats release-audit release-check split check-assets lint format test trace-player clean _require-assets

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

export-content: build-prg
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" export \
		--formats "$(DATA_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--labels "$(NATIVE_LABELS)" \
		--prg "$(NATIVE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		$(CONTENT_STUDIO_ARG)

validate-content: build-prg
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" validate \
		--formats "$(DATA_FORMAT_MANIFEST)" \
		--studios "$(CONTENT_STUDIO_MANIFEST)" \
		--labels "$(NATIVE_LABELS)" \
		--prg "$(NATIVE_PRG)" \
		--workspace "$(CONTENT_WORKSPACE)" \
		--report "$(CONTENT_REPORT)" \
		$(CONTENT_STUDIO_ARG)

build-content: build
	$(PYTHON) "$(PROJECT_DIR)scripts/content_studio.py" build \
		--formats "$(DATA_FORMAT_MANIFEST)" \
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
		--prg-only --verify
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

validate-revisions:
	$(MAKE) validate-revision PROFILE=ju
	$(MAKE) validate-revision PROFILE=pc10

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

split:
	$(PYTHON) "$(PROJECT_DIR)scripts/split_assets.py" \
		--rom "$(ORIGINAL_ROM)" \
		--manifest "$(ASSET_MANIFEST)" \
		--output-dir "$(GENERATED_ASSET_DIR)"

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
