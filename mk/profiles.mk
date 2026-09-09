# Revision and platform profile configuration and workflows.
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
PLATFORM_BIN_INCLUDE_ARGS =
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
PLATFORM_BIN_INCLUDE_ARGS = --bin-include-dir "$(ANN_SUPPLEMENTAL_ASSET_DIR)"
PLATFORM_PAYLOAD_ARGS = \
	--payload NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin \
	--payload NSMDATA3=$(ANN_ENDING_BUILD_DIR)/payload.bin \
	--payload NSMDATA4=$(ANN_HARD_COURSES_BUILD_DIR)/payload.bin
else
PLATFORM_SOURCE ?= $(PROJECT_DIR)src/platforms/$(PLATFORM).asm
PLATFORM_CFG ?= $(NATIVE_CFG)
PLATFORM_REFERENCE ?= $(PROJECT_DIR)$(PLATFORM)
PLATFORM_OUTPUT ?= $(PLATFORM_BUILD_DIR)/smb.nes
endif
split-revision-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.revision_profiles split \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(PROFILE)" \
		--reference-rom "$(REVISION_REFERENCE)" \
		--asset-dir "$(REVISION_ASSET_DIR)"

build-revision: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_native \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.revision_profiles build \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(PROFILE)" \
		--asset-dir "$(REVISION_ASSET_DIR)" \
		--header "$(GENERATED_HEADER)" \
		--prg "$(REVISION_PRG)" \
		--chr "$(GENERATED_CHR)" \
		--output "$(REVISION_ROM)"

verify-revision: build-revision
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.revision_profiles verify \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(PROFILE)" \
		--reference-rom "$(REVISION_REFERENCE)" \
		--asset-dir "$(REVISION_ASSET_DIR)" \
		--header "$(GENERATED_HEADER)" \
		--prg "$(REVISION_PRG)" \
		--chr "$(GENERATED_CHR)" \
		--output "$(REVISION_ROM)"

validate-revision: verify-revision
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_revision_runtime \
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

ifeq ($(PLATFORM),ann_fds)
build-platform: build-ann-payloads
endif

build-platform:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_native \
		--source "$(PLATFORM_SOURCE)" \
		--config "$(PLATFORM_CFG)" \
		--manifest "$(ASSET_MANIFEST)" \
		--object "$(PLATFORM_OBJ)" \
		--prg "$(PLATFORM_PRG)" \
		--labels "$(PLATFORM_LABELS)" \
		--map "$(PLATFORM_MAP)" \
		--debug-info "$(PLATFORM_DEBUG)" \
		--output-rom "$(PLATFORM_OUTPUT)" \
		$(PLATFORM_BIN_INCLUDE_ARGS) \
		--prg-only
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.platform_profiles build \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile "$(PLATFORM)" \
		--asset-dir "$(PLATFORM_ASSET_DIR)" \
		--prg "$(PLATFORM_PRG)" \
		$(PLATFORM_PAYLOAD_ARGS) \
		--output "$(PLATFORM_OUTPUT)"

verify-platform: build-platform
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.platform_profiles verify \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile "$(PLATFORM)" \
		--reference "$(PLATFORM_REFERENCE)" \
		--asset-dir "$(PLATFORM_ASSET_DIR)" \
		--prg "$(PLATFORM_PRG)" \
		$(PLATFORM_PAYLOAD_ARGS) \
		--output "$(PLATFORM_OUTPUT)"

validate-platform: verify-platform
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_platform_runtime \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.run_make_matrix \
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

validate-platforms:
	$(MAKE) validate-platform PLATFORM=vs_smb
	$(MAKE) validate-platform PLATFORM=fds_smb
	$(MAKE) validate-platform PLATFORM=ann_fds
