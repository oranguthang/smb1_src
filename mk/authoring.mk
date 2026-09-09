# Profile-aware content codecs, Studios, and playtests.
CONTENT_STUDIO_MANIFEST ?= $(PROJECT_DIR)config/authoring/content_studios.json
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
CONTENT_RUN_ROM = $(if $(filter vs_smb,$(CONTENT_PROFILE)),$(CONTENT_BUILD_DIR)/smb.playtest.nes,$(CONTENT_ROM))
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
	--payload NSMDATA3=$(ANN_ENDING_BUILD_DIR)/payload.bin \
	--payload NSMDATA4=$(ANN_HARD_COURSES_BUILD_DIR)/payload.bin \
	--payload-labels NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.lbl \
	--payload-labels NSMDATA3=$(ANN_ENDING_BUILD_DIR)/payload.lbl \
	--payload-labels NSMDATA4=$(ANN_HARD_COURSES_BUILD_DIR)/payload.lbl
STUDIO_CONTENT_PAYLOAD_ARGS = \
	--content-payload NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.bin \
	--content-payload NSMDATA3=$(ANN_ENDING_BUILD_DIR)/payload.bin \
	--content-payload NSMDATA4=$(ANN_HARD_COURSES_BUILD_DIR)/payload.bin \
	--content-payload-labels NSMDATA2=$(ANN_SUPPLEMENTAL_COURSES_BUILD_DIR)/payload.lbl \
	--content-payload-labels NSMDATA3=$(ANN_ENDING_BUILD_DIR)/payload.lbl \
	--content-payload-labels NSMDATA4=$(ANN_HARD_COURSES_BUILD_DIR)/payload.lbl
else ifeq ($(CONTENT_PROFILE),smb2_jp_fds)
CONTENT_BASE_DIR = $(SMB2_SOURCE_BUILD_DIR)
CONTENT_BASE_PRG = $(CONTENT_BASE_DIR)/SM2MAIN.bin
CONTENT_BASE_LABELS = $(CONTENT_BASE_DIR)/smb2.lbl
CONTENT_CHR = $(SMB2_ASSET_DIR)/smb2_jp_fds/template.fds
CONTENT_ROM = $(CONTENT_BUILD_DIR)/smb2.fds
CONTENT_LOAD_ADDRESS = 0x6000
CONTENT_PREPARE_COMMAND = $(MAKE) build-smb2
CONTENT_CONTAINER_ARGS = --template "$(SMB2_ASSET_DIR)/smb2_jp_fds/template.fds"
CONTENT_PAYLOAD_ARGS = \
	--payload SM2DATA2=$(CONTENT_BASE_DIR)/SM2DATA2.bin \
	--payload SM2DATA3=$(CONTENT_BASE_DIR)/SM2DATA3.bin \
	--payload SM2DATA4=$(CONTENT_BASE_DIR)/SM2DATA4.bin
STUDIO_CONTENT_PAYLOAD_ARGS = \
	--content-payload SM2DATA2=$(CONTENT_BASE_DIR)/SM2DATA2.bin \
	--content-payload SM2DATA3=$(CONTENT_BASE_DIR)/SM2DATA3.bin \
	--content-payload SM2DATA4=$(CONTENT_BASE_DIR)/SM2DATA4.bin
endif
prepare-content-profile:
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.content_profiles check \
		--manifest "$(CONTENT_PROFILE_MANIFEST)" \
		--profile "$(CONTENT_PROFILE)" \
		$(CONTENT_STUDIO_ARG)
	$(CONTENT_PREPARE_COMMAND)

init-content: prepare-content-profile
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.content_studio init \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.content_studio export \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.content_studio validate \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.content_studio build \
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
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.world_studio $(STUDIO_COMMON_ARGS) --check
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.level_studio $(STUDIO_COMMON_ARGS) \
		--content-image "$(CONTENT_ROM)" --check
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.graphics_studio $(STUDIO_COMMON_ARGS) --check
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.sound_studio $(STUDIO_COMMON_ARGS) \
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
	$(MAKE) check-content-profile CONTENT_PROFILE=smb2_jp_fds

run-content: build-content
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.emulator_image \
		--profiles "$(CONTENT_PROFILE_MANIFEST)" \
		--profile "$(CONTENT_PROFILE)" \
		--input "$(CONTENT_ROM)" \
		--output "$(CONTENT_RUN_ROM)"
	"$(FCEUX_EXE)" "$(CONTENT_RUN_ROM)"

world-studio:
	$(MAKE) init-content STUDIO=world
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.world_studio $(STUDIO_COMMON_ARGS)

level-studio:
	$(MAKE) init-content STUDIO=world
	$(MAKE) init-content STUDIO=level
	$(MAKE) init-content STUDIO=graphics
	$(MAKE) init-content STUDIO=sound
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.level_studio $(STUDIO_COMMON_ARGS) \
		--content-image "$(CONTENT_ROM)" $(LEVEL_STUDIO_ARGS)

smoke-level-playtest:
	$(MAKE) level-studio CONTENT_PROFILE=$(CONTENT_PROFILE) \
		LEVEL_STUDIO_ARGS="$(PLAYTEST_BANK_ARG) $(PLAYTEST_AREA_ARG) --smoke-playtest $(PLAYTEST_THEME)"

graphics-studio:
	$(MAKE) init-content STUDIO=graphics
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.graphics_studio $(STUDIO_COMMON_ARGS)

sound-studio:
	$(MAKE) init-content STUDIO=sound
	$(PYTHON) "$(PROJECT_DIR)scripts/run.py" authoring.sound_studio $(STUDIO_COMMON_ARGS) \
		--prg "$(CONTENT_BASE_PRG)" --load-address "$(CONTENT_LOAD_ADDRESS)"

world-editor: world-studio
level-editor: level-studio
graphics-editor: graphics-studio
sound-editor: sound-studio
