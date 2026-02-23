# Super Mario Bros Disassembly Makefile
# Builds NES ROM from assembly source using ca65/ld65 toolchain

# Detect OS
ifeq ($(OS),Windows_NT)
	# Windows
	RM = cmd /c del /Q
	CAT = cmd /c copy /b
	SHELL = cmd
else
	# Unix/Linux/Mac
	RM = rm -f
	CAT = cat
endif

# Tools
AS = ca65
LD = ld65

# Files
ASM_SRC = smbdis.asm
OBJ_FILE = smbdis.o
PRG_FILE = smb.prg
CHR_FILE = smb.chr
HDR_FILE = smb.hdr
ROM_FILE = smb.nes
LD_CONFIG = ldconfig.txt

# Targets
.PHONY: all build clean split

all: build

build: $(ROM_FILE)

# Assemble source to object file
$(OBJ_FILE): $(ASM_SRC)
	@echo Assembling $(ASM_SRC)...
	$(AS) $(ASM_SRC)

# Link object file to PRG ROM
$(PRG_FILE): $(OBJ_FILE) $(LD_CONFIG)
	@echo Linking $(OBJ_FILE)...
	$(LD) -C $(LD_CONFIG) $(OBJ_FILE)

# Create final NES ROM by concatenating header + PRG + CHR
ifeq ($(OS),Windows_NT)
$(ROM_FILE): $(PRG_FILE) $(HDR_FILE) $(CHR_FILE)
	@echo Creating NES ROM...
	@if exist $(ROM_FILE) $(RM) $(ROM_FILE) 2>nul
	$(CAT) $(HDR_FILE)+$(PRG_FILE)+$(CHR_FILE) $(ROM_FILE) >nul
	@echo Build complete: $(ROM_FILE)
else
$(ROM_FILE): $(PRG_FILE) $(HDR_FILE) $(CHR_FILE)
	@echo Creating NES ROM...
	$(CAT) $(HDR_FILE) $(PRG_FILE) $(CHR_FILE) > $(ROM_FILE)
	@echo Build complete: $(ROM_FILE)
endif

clean:
	@echo Cleaning build artifacts...
	-@$(RM) $(OBJ_FILE) 2>nul || true
	-@$(RM) $(PRG_FILE) 2>nul || true
	-@$(RM) $(ROM_FILE) 2>nul || true
	@echo Clean complete

# Extract header and CHR from original ROM
ifeq ($(OS),Windows_NT)
split:
	@echo Searching for original ROM file...
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "\
		$$roms = Get-ChildItem -Path . -Filter 'Super Mario Bros*.nes' | Where-Object { \
			$$_.Name -match 'Super Mario Bros\. \((E|JU)\).*\.nes$$' \
		}; \
		if ($$roms.Count -eq 0) { \
			Write-Host \"ERROR: No original ROM file found!\"; \
			Write-Host \"Please place one of the following files in the current directory:\"; \
			Write-Host \"  - Super Mario Bros. (E) (REV0) [!p].nes\"; \
			Write-Host \"  - Super Mario Bros. (E) (REVA) [!p].nes\"; \
			Write-Host \"  - Super Mario Bros. (JU) [!].nes\"; \
			exit 1; \
		}; \
		$$rom = $$roms[0].FullName; \
		Write-Host \"Found: $$($$roms[0].Name)\"; \
		Write-Host \"Extracting header (16 bytes)...\"; \
		$$bytes = [System.IO.File]::ReadAllBytes($$rom); \
		[System.IO.File]::WriteAllBytes('$(HDR_FILE)', $$bytes[0..15]); \
		Write-Host \"Extracting CHR ROM (8192 bytes from offset 32784)...\"; \
		[System.IO.File]::WriteAllBytes('$(CHR_FILE)', $$bytes[32784..41975]); \
		Write-Host \"Extraction complete: $(HDR_FILE), $(CHR_FILE)\""
else
split:
	@echo Searching for original ROM file...
	@rom=$$(find . -maxdepth 1 -type f -name 'Super Mario Bros*.nes' | grep -E '\((E|JU)\)' | head -n 1); \
	if [ -z "$$rom" ]; then \
		echo "ERROR: No original ROM file found!"; \
		echo "Please place one of the following files in the current directory:"; \
		echo "  - Super Mario Bros. (E) (REV0) [!p].nes"; \
		echo "  - Super Mario Bros. (E) (REVA) [!p].nes"; \
		echo "  - Super Mario Bros. (JU) [!].nes"; \
		exit 1; \
	fi; \
	echo "Found: $$(basename "$$rom")"; \
	echo "Extracting header (16 bytes)..."; \
	dd if="$$rom" of=$(HDR_FILE) bs=1 count=16 skip=0 2>/dev/null; \
	echo "Extracting CHR ROM (8192 bytes from offset 32784)..."; \
	dd if="$$rom" of=$(CHR_FILE) bs=1 count=8192 skip=32784 2>/dev/null; \
	echo "Extraction complete: $(HDR_FILE), $(CHR_FILE)"
endif
