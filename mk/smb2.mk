# Later-engine analysis and the independent SMB2 reconstruction.
LATER_ENGINE_MANIFEST ?= $(PROJECT_DIR)config/reconstruction/later_engine_feasibility.json
LATER_ENGINE_REPORT ?= $(PROJECT_DIR)build/evidence/later_engine_feasibility.json
LATER_ENGINE_OVERLAP_MANIFEST ?= $(PROJECT_DIR)config/reconstruction/later_engine_source_overlap.json
LATER_ENGINE_OVERLAP_REPORT ?= $(PROJECT_DIR)build/evidence/later_engine_source_overlap.json
SMB2_RECONSTRUCTION_MANIFEST ?= $(PROJECT_DIR)config/reconstruction/smb2.json
SMB2_PLATFORM_MANIFEST ?= $(PROJECT_DIR)config/smb2_platform_profile.json
SMB2_REFERENCE ?= $(PROJECT_DIR)Super Mario Brothers 2 (Japan).fds
SMB2_ASSET_DIR ?= $(GENERATED_ASSET_DIR)/smb2
SMB2_BUILD_DIR ?= $(PROJECT_DIR)build/smb2/identity
SMB2_IDENTITY_IMAGE ?= $(SMB2_BUILD_DIR)/smb2.fds
SMB2_SOURCE_BUILD_DIR ?= $(PROJECT_DIR)build/smb2/source
SMB2_SOURCE_IMAGE ?= $(SMB2_SOURCE_BUILD_DIR)/smb2.fds
SMB2_RUNTIME_RESULT ?= $(SMB2_SOURCE_BUILD_DIR)/runtime.txt
SMB2_RUNTIME_LUA ?= $(PROJECT_DIR)scripts/workflow/validate_platform_runtime.lua
SMB2_OVERLAY_RESULT_DIR ?= $(SMB2_SOURCE_BUILD_DIR)/overlay_runtime
SMB2_OVERLAY_RUNTIME_LUA ?= $(PROJECT_DIR)scripts/workflow/validate_smb2_overlay_runtime.lua
SMB2_GAMEPLAY_RESULT_DIR ?= $(SMB2_SOURCE_BUILD_DIR)/gameplay_runtime
SMB2_GAMEPLAY_RUNTIME_LUA ?= $(PROJECT_DIR)scripts/workflow/validate_smb2_gameplay_runtime.lua
SMB2_RELOCATION_MANIFEST ?= $(PROJECT_DIR)config/relocation/smb2_jp_fds.json
SMB2_RELOCATION_BUILD_DIR ?= $(PROJECT_DIR)build/relocation/smb2_jp_fds/candidate
SMB2_RELOCATION_IMAGE ?= $(SMB2_RELOCATION_BUILD_DIR)/smb2.fds
SMB2_RELOCATION_SCENARIOS ?= $(SMB2_RELOCATION_BUILD_DIR)/runtime_scenarios.json
SMB2_RELOCATION_SUMMARY ?= $(SMB2_RELOCATION_BUILD_DIR)/relocation_summary.json
SMB2_RELOCATION_RUNTIME_RESULT ?= $(SMB2_RELOCATION_BUILD_DIR)/runtime.txt
SMB2_RELOCATION_OVERLAY_RESULT_DIR ?= $(SMB2_RELOCATION_BUILD_DIR)/overlay_runtime
SMB2_RELOCATION_GAMEPLAY_RESULT_DIR ?= $(SMB2_RELOCATION_BUILD_DIR)/gameplay_runtime
split-platform-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.platform_profiles split \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile "$(PLATFORM)" \
		--reference "$(PLATFORM_REFERENCE)" \
		--asset-dir "$(PLATFORM_ASSET_DIR)"

split-smb2-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.platform_profiles split \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--reference "$(SMB2_REFERENCE)" \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--retain-primary

build-smb2-identity:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.platform_profiles build \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--output "$(SMB2_IDENTITY_IMAGE)"

verify-smb2-identity: build-smb2-identity
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.platform_profiles verify \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--reference "$(SMB2_REFERENCE)" \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--output "$(SMB2_IDENTITY_IMAGE)"

build-smb2-source:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_smb2_source \
		--manifest "$(SMB2_RECONSTRUCTION_MANIFEST)" \
		--output-dir "$(SMB2_SOURCE_BUILD_DIR)"

verify-smb2-source:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_smb2_source \
		--manifest "$(SMB2_RECONSTRUCTION_MANIFEST)" \
		--output-dir "$(SMB2_SOURCE_BUILD_DIR)" \
		--verify

build-smb2: build-smb2-source
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.platform_profiles build \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--prg "$(SMB2_SOURCE_BUILD_DIR)/SM2MAIN.bin" \
		--payload "SM2DATA2=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA2.bin" \
		--payload "SM2DATA3=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA3.bin" \
		--payload "SM2DATA4=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA4.bin" \
		--output "$(SMB2_SOURCE_IMAGE)"

verify-smb2: verify-smb2-source
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.platform_profiles verify \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--reference "$(SMB2_REFERENCE)" \
		--asset-dir "$(SMB2_ASSET_DIR)" \
		--prg "$(SMB2_SOURCE_BUILD_DIR)/SM2MAIN.bin" \
		--payload "SM2DATA2=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA2.bin" \
		--payload "SM2DATA3=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA3.bin" \
		--payload "SM2DATA4=$(SMB2_SOURCE_BUILD_DIR)/SM2DATA4.bin" \
		--output "$(SMB2_SOURCE_IMAGE)"

validate-smb2-runtime: verify-smb2
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_platform_runtime \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--fceux "$(FCEUX_EXE)" \
		--fds-bios "$(FDS_BIOS)" \
		--image "$(SMB2_SOURCE_IMAGE)" \
		--lua "$(SMB2_RUNTIME_LUA)" \
		--result "$(SMB2_RUNTIME_RESULT)"

validate-smb2-overlays: verify-smb2
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_smb2_overlays \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--fceux "$(FCEUX_EXE)" \
		--fds-bios "$(FDS_BIOS)" \
		--image "$(SMB2_SOURCE_IMAGE)" \
		--payload-dir "$(SMB2_SOURCE_BUILD_DIR)" \
		--lua "$(SMB2_OVERLAY_RUNTIME_LUA)" \
		--result-dir "$(SMB2_OVERLAY_RESULT_DIR)"

validate-smb2-gameplay: verify-smb2
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_smb2_gameplay \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--fceux "$(FCEUX_EXE)" \
		--fds-bios "$(FDS_BIOS)" \
		--baseline-image "$(SMB2_SOURCE_IMAGE)" \
		--lua "$(SMB2_GAMEPLAY_RUNTIME_LUA)" \
		--result-dir "$(SMB2_GAMEPLAY_RESULT_DIR)"

test-smb2-relocation: verify-smb2
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.smb2_relocation_test \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(SMB2_RELOCATION_MANIFEST)" \
		--baseline-dir "$(SMB2_SOURCE_BUILD_DIR)" \
		--original-image "$(SMB2_REFERENCE)"

validate-smb2-relocation: test-smb2-relocation
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_platform_runtime \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--fceux "$(FCEUX_EXE)" \
		--fds-bios "$(FDS_BIOS)" \
		--image "$(SMB2_RELOCATION_IMAGE)" \
		--lua "$(SMB2_RUNTIME_LUA)" \
		--result "$(SMB2_RELOCATION_RUNTIME_RESULT)" \
		--forbidden-manifest "$(SMB2_RELOCATION_SCENARIOS)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_smb2_overlays \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--fceux "$(FCEUX_EXE)" \
		--fds-bios "$(FDS_BIOS)" \
		--image "$(SMB2_RELOCATION_IMAGE)" \
		--payload-dir "$(SMB2_RELOCATION_BUILD_DIR)" \
		--lua "$(SMB2_OVERLAY_RUNTIME_LUA)" \
		--result-dir "$(SMB2_RELOCATION_OVERLAY_RESULT_DIR)" \
		--forbidden-manifest "$(SMB2_RELOCATION_SCENARIOS)" \
		--relocation-summary "$(SMB2_RELOCATION_SUMMARY)"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_smb2_gameplay \
		--manifest "$(SMB2_PLATFORM_MANIFEST)" \
		--profile smb2_jp_fds \
		--fceux "$(FCEUX_EXE)" \
		--fds-bios "$(FDS_BIOS)" \
		--baseline-image "$(SMB2_SOURCE_IMAGE)" \
		--candidate-image "$(SMB2_RELOCATION_IMAGE)" \
		--lua "$(SMB2_GAMEPLAY_RUNTIME_LUA)" \
		--result-dir "$(SMB2_RELOCATION_GAMEPLAY_RESULT_DIR)" \
		--forbidden-manifest "$(SMB2_RELOCATION_SCENARIOS)"

later-engine-feasibility:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" workflow.later_engine_feasibility \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(LATER_ENGINE_MANIFEST)" \
		--output "$(LATER_ENGINE_REPORT)"

later-engine-source-overlap:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" workflow.compare_assembly_sources \
		--project-root "$(PROJECT_DIR)" \
		--manifest "$(LATER_ENGINE_OVERLAP_MANIFEST)" \
		--assembler "$(PROJECT_DIR)bin/ca65.exe" \
		--output "$(LATER_ENGINE_OVERLAP_REPORT)"
