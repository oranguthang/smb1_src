# Relocation profile selection and validation workflows.
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
test-relocation:
	$(MAKE) $(RELOCATION_VERIFY_TARGET)
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.relocation_test \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.debug_symbols \
		--debug "$(RELOCATION_DEBUG)" \
		--map "$(RELOCATION_MAP)" \
		--labels "$(RELOCATION_LABELS)" \
		--rom "$(RELOCATION_ROM)" \
		--fceux-output-dir "$(RELOCATION_BUILD_DIR)" \
		--breakpoints "$(DEBUG_BREAKPOINTS)" \
		--watches "$(DEBUG_WATCHES)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_debug_runtime \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(RELOCATION_ROM)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)" \
		--lua "$(DEBUG_RUNTIME_LUA)" \
		--result "$(RELOCATION_DEBUG_RESULT)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.run_runtime_scenarios \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(RELOCATION_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(RUNTIME_TRACE_LUA)" \
		--scenarios "$(RELOCATION_SCENARIOS)" \
		--output-dir "$(RELOCATION_TRACE_DIR)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_runtime_scenarios \
		--scenarios "$(RELOCATION_SCENARIOS)" \
		--trace-dir "$(RELOCATION_TRACE_DIR)"

validate-revision-relocation: test-relocation
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.debug_symbols \
		--debug "$(RELOCATION_DEBUG)" \
		--map "$(RELOCATION_MAP)" \
		--labels "$(RELOCATION_LABELS)" \
		--rom "$(RELOCATION_ROM)" \
		--fceux-output-dir "$(RELOCATION_BUILD_DIR)" \
		--breakpoints "$(DEBUG_BREAKPOINTS)" \
		--watches "$(DEBUG_WATCHES)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_debug_runtime \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(RELOCATION_ROM)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)" \
		--lua "$(DEBUG_RUNTIME_LUA)" \
		--result "$(RELOCATION_DEBUG_RESULT)" \
		$(RELOCATION_PAL_ARG)
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_revision_runtime \
		--manifest "$(REVISION_MANIFEST)" \
		--profile "$(RELOCATION_PROFILE)" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(RELOCATION_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(EXPANDED_RUNTIME_LUA)" \
		--result "$(RELOCATION_REVISION_RESULT)" \
		--forbidden-manifest "$(RELOCATION_SCENARIOS)"

validate-platform-relocation: test-relocation
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.debug_symbols \
		--debug "$(RELOCATION_DEBUG)" \
		--map "$(RELOCATION_MAP)" \
		--labels "$(RELOCATION_LABELS)" \
		--rom "$(RELOCATION_ROM)" \
		--fceux-output-dir "$(RELOCATION_BUILD_DIR)" \
		--breakpoints "$(DEBUG_BREAKPOINTS)" \
		--watches "$(DEBUG_WATCHES)" \
		--summary "$(RELOCATION_DEBUG_SUMMARY)" \
		$(RELOCATION_DEBUG_CONTAINER_ARG)
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_platform_runtime \
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
