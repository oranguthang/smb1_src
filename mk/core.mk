# Canonical build, shared paths, assets, lint, tests, and cleanup.
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
DEBUG_BREAKPOINTS ?= $(PROJECT_DIR)config/debugger/breakpoints.json
DEBUG_WATCHES ?= $(PROJECT_DIR)config/debugger/watches.json
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
SCORING_RUNTIME_SCENARIOS ?= $(PROJECT_DIR)scenarios/scoring_runtime_scenarios.json
SCORING_RUNTIME_TRACE_LUA ?= $(PROJECT_DIR)scripts/workflow/capture_scoring_transaction.lua
SCORING_RUNTIME_TRACE_DIR ?= $(PROJECT_DIR)build/evidence/scoring
DATA_FORMAT_MANIFEST ?= $(PROJECT_DIR)config/authoring/data_formats.json
DATA_FORMAT_SUMMARY ?= $(PROJECT_DIR)build/data_formats.json
CONTENT_FORMAT_MANIFEST ?= $(PROJECT_DIR)config/authoring/content_formats_3.json
CONTENT_PROFILE_MANIFEST ?= $(PROJECT_DIR)config/authoring/content_authoring_profiles.json

help:
	@echo Core: build verify lint format test release-check source-2-check
	@echo Profiles: verify-revisions validate-revisions verify-platforms validate-platforms
	@echo Authoring: list-content-profiles check-content-profiles world-studio level-studio graphics-studio sound-studio
	@echo Evidence: trace semantic-evidence validate-relocation-revisions
	@echo Advanced: source-3-check verify-smb2 validate-smb2-relocation
build: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_native \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_native \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_native \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_native \
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

split:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.split_assets \
		--rom "$(ORIGINAL_ROM)" \
		--manifest "$(ASSET_MANIFEST)" \
		--output-dir "$(GENERATED_ASSET_DIR)"

split-all:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.run_make_matrix \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.check_assets \
		--manifest "$(ASSET_MANIFEST)" \
		--asset-dir "$(GENERATED_ASSET_DIR)"

lint:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.asm_style "$(PROJECT_DIR)src"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.lint_source "$(PROJECT_DIR)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.lint_project "$(PROJECT_DIR)"

format:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.asm_style --fix "$(PROJECT_DIR)src"
	$(MAKE) lint

test:
	$(PYTHON) -m unittest discover -s "$(PROJECT_DIR)tests" -t "$(PROJECT_DIR)" -p "test_*.py"

trace-player:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.player_physics

_require-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.check_assets \
		--manifest "$(ASSET_MANIFEST)" \
		--asset-dir "$(GENERATED_ASSET_DIR)"

clean:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.clean_artifacts \
		--project-root "$(PROJECT_DIR)" \
		--path "$(NATIVE_BUILD_DIR)"
