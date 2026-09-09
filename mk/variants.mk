# Fixed-layout, expanded, and ANN payload variants.
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
ANN_SUPPLEMENTAL_ASSET_DIR ?= $(PROJECT_DIR)assets/generated/platforms/ann_fds/source
ANN_ENDING_SOURCE ?= $(PROJECT_DIR)src/revisions/ann/ending.asm
ANN_ENDING_CFG ?= $(PROJECT_DIR)config/linker/ann/ending.cfg
ANN_ENDING_BUILD_DIR ?= $(PROJECT_DIR)build/platforms/ann_ending
ANN_HARD_COURSES_SOURCE ?= $(PROJECT_DIR)src/revisions/ann/hard_courses.asm
ANN_HARD_COURSES_CFG ?= $(PROJECT_DIR)config/linker/ann/hard_courses.cfg
ANN_HARD_COURSES_BUILD_DIR ?= $(PROJECT_DIR)build/platforms/ann_hard_courses
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
build-hack: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_native \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.fixed_variant \
		--manifest "$(FIXED_VARIANT_MANIFEST)" \
		--variant "$(FIXED_VARIANT)" \
		--baseline-prg "$(NATIVE_PRG)" \
		--candidate-prg "$(HACK_PRG)" \
		--baseline-rom "$(NATIVE_ROM)" \
		--candidate-rom "$(HACK_ROM)"

validate-hack: verify-hack
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.validate_fixed_variant \
		--manifest "$(FIXED_VARIANT_MANIFEST)" \
		--variant "$(FIXED_VARIANT)" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(HACK_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(HACK_RUNTIME_LUA)" \
		--result "$(HACK_RUNTIME_RESULT)"

build-expanded: _require-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_native \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.expanded_rom \
		--manifest "$(EXPANDED_MANIFEST)" \
		--prg "$(EXPANDED_PRG)" \
		--chr "$(GENERATED_CHR)" \
		--output "$(EXPANDED_ROM)"

verify-expanded: build-expanded
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.expanded_rom \
		--manifest "$(EXPANDED_MANIFEST)" \
		--prg "$(EXPANDED_PRG)" \
		--chr "$(GENERATED_CHR)" \
		--output "$(EXPANDED_ROM)" \
		--verify

validate-expanded: verify-expanded
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" runtime.validate_expanded_runtime \
		--manifest "$(EXPANDED_MANIFEST)" \
		--fceux "$(FCEUX_EXE)" \
		--rom "$(EXPANDED_ROM)" \
		--movie "$(RUNTIME_MOVIE)" \
		--lua "$(EXPANDED_RUNTIME_LUA)" \
		--result "$(EXPANDED_RUNTIME_RESULT)"

verify-ann-audio:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_asm_range \
		--source "$(ANN_AUDIO_SOURCE)" \
		--config "$(ANN_AUDIO_CFG)" \
		--object "$(ANN_AUDIO_BUILD_DIR)/audio.o" \
		--output "$(ANN_AUDIO_BUILD_DIR)/audio.bin" \
		--labels "$(ANN_AUDIO_BUILD_DIR)/audio.lbl" \
		--map "$(ANN_AUDIO_BUILD_DIR)/audio.map"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.verify_platform_range \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_AUDIO_BUILD_DIR)/audio.bin" \
		--load-address 0x6000 \
		--start 0xD2E4 \
		--end 0xDFFA

verify-ann-tail-core:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_asm_range \
		--source "$(ANN_TAIL_CORE_SOURCE)" \
		--config "$(ANN_TAIL_CORE_CFG)" \
		--object "$(ANN_TAIL_BUILD_DIR)/core.o" \
		--output "$(ANN_TAIL_BUILD_DIR)/core.bin" \
		--labels "$(ANN_TAIL_BUILD_DIR)/core.lbl" \
		--map "$(ANN_TAIL_BUILD_DIR)/core.map"
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.verify_platform_range \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_TAIL_BUILD_DIR)/core.bin" \
		--load-address 0x6000 \
		--start 0xBFBF \
		--end 0xE000

build-ann-payloads: build-ann-supplemental-courses build-ann-ending build-ann-hard-courses

prepare-ann-supplemental-assets:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.prepare_ann_supplemental \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--output-dir "$(ANN_SUPPLEMENTAL_ASSET_DIR)"

build-ann-supplemental-courses: prepare-ann-supplemental-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_asm_range \
		--source "$(ANN_SUPPLEMENTAL_COURSES_SOURCE)" \
		--config "$(ANN_SUPPLEMENTAL_COURSES_CFG)" \
		--bin-include-dir "$(ANN_SUPPLEMENTAL_ASSET_DIR)" \
		--object "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.o" \
		--output "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin" \
		--labels "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.lbl" \
		--map "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.map"

verify-ann-supplemental-courses: build-ann-supplemental-courses
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.verify_platform_range \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin" \
		--payload NSMDATA2 \
		--load-address 0xC470 \
		--start 0xC470 \
		--end 0xD270

build-ann-ending: prepare-ann-supplemental-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_asm_range \
		--source "$(ANN_ENDING_SOURCE)" \
		--config "$(ANN_ENDING_CFG)" \
		--object "$(ANN_ENDING_BUILD_DIR)/payload.o" \
		--output "$(ANN_ENDING_BUILD_DIR)/payload.bin" \
		--labels "$(ANN_ENDING_BUILD_DIR)/payload.lbl" \
		--map "$(ANN_ENDING_BUILD_DIR)/payload.map"

verify-ann-ending: build-ann-ending
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.verify_platform_range \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_ENDING_BUILD_DIR)/payload.bin" \
		--payload NSMDATA3 \
		--load-address 0xC5D0 \
		--start 0xC5D0 \
		--end 0xD2E2

build-ann-hard-courses: prepare-ann-supplemental-assets
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" build.build_asm_range \
		--source "$(ANN_HARD_COURSES_SOURCE)" \
		--config "$(ANN_HARD_COURSES_CFG)" \
		--object "$(ANN_HARD_COURSES_BUILD_DIR)/payload.o" \
		--output "$(ANN_HARD_COURSES_BUILD_DIR)/payload.bin" \
		--labels "$(ANN_HARD_COURSES_BUILD_DIR)/payload.lbl" \
		--map "$(ANN_HARD_COURSES_BUILD_DIR)/payload.map"

verify-ann-hard-courses: build-ann-hard-courses
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" validation.verify_platform_range \
		--manifest "$(PLATFORM_MANIFEST)" \
		--profile ann_fds \
		--reference "$(ANN_REFERENCE)" \
		--candidate "$(ANN_HARD_COURSES_BUILD_DIR)/payload.bin" \
		--payload NSMDATA4 \
		--load-address 0xC296 \
		--start 0xC296 \
		--end 0xD086
