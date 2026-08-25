# Super Mario Bros Disassembly

A comprehensive disassembly of Super Mario Bros for the Nintendo Entertainment System (NES).

## Overview

This repository contains:

- **src/main.asm** - Address-ordered entrypoint for the modular disassembly
- **src/ldconfig.txt** - Linker configuration for the ROM build
- **bin/ca65.exe** - 6502 assembly compiler from [cc65](http://www.cc65.org/)
- **bin/ld65.exe** - 6502 linker from [cc65](http://www.cc65.org/)
- **docs/6502jsm.txt** - Summary of 6502 CPU instructions
- **docs/modding_examples.md** - Example gameplay edits and patch ideas

## Project Structure

```text
smb1_src/
|-- bin/                # Local ca65/ld65 toolchain
|   |-- ca65.exe
|   `-- ld65.exe
|-- assets/
|   |-- manifest.json   # Reference identity and extracted-asset hashes
|   `-- generated/      # Ignored local header and CHR data
|-- docs/               # Local technical notes
|   |-- 6502jsm.txt
|   `-- modding_examples.md
|-- scripts/            # Cross-platform build, split, and validation logic
|-- src/                # Assembly source and linker config
|   |-- audio/          # Sound effects, music engine, and music data
|   |-- data/           # Level streams and fixed interrupt vectors
|   |-- game/           # Modes, physics, objects, enemies, and collisions
|   |-- ldconfig.txt
|   |-- main.asm
|   |-- memory/         # Hardware, RAM, and assembly-time definitions
|   |-- rendering/      # Screens, backgrounds, HUD, and actor composition
|   `-- system/         # Reset, frame control, input, and PPU I/O
|-- Makefile            # Main build entrypoint
|-- README.md
`-- .gitignore
```

## Prerequisites

The preservation profile currently targets exactly:

```text
Super Mario Bros. (JU) [!].nes
SHA-1 ea343f4e445a9050d4b4fbac2c77d0693b1d0922
```

Place a legally obtained matching ROM in the project root, then run:

```bash
make split
```

This validates the complete ROM identity before extracting:

- `assets/generated/header/smb.hdr` - 16-byte iNES header;
- `assets/generated/chr/smb.chr` - 8192-byte CHR-ROM payload.

The ROM and extracted files are ignored and are not included in the repository.
PAL revisions and ROMs with extra trailing payloads are rejected by default.

## Building

### Preservation PRG build

The reconstruction can be assembled and checked without proprietary graphics
or a ROM image:

```bash
make build-prg
make verify-prg
```

`make verify-prg` writes the PRG, labels, linker map, and debug information
under the ignored `build/native/` directory. It fails unless the 32 KiB PRG is
byte-identical to the recorded baseline in `assets/manifest.json`.

### Using Makefile

```bash
# Validate local assets and build build/native/smb.nes
make build

# Rebuild and require complete byte identity with the reference ROM
make verify

# Validate extracted assets without changing them
make check-assets

# Remove build/native safely; extracted assets remain untouched
make clean
```

The Makefile contains only thin entrypoints. ROM parsing, safe extraction,
assembly, linking, concatenation, checksum validation, and cleanup are
implemented in platform-independent Python scripts under `scripts/`.

## Modding Notes

For a few practical modification examples, see [docs/modding_examples.md](docs/modding_examples.md).

## Credits

- **Disassembly** - doppelganger (doppelheathen@gmail.com)
- **Original source** - https://gist.github.com/1wErt3r/4048722
- **ca65-adapted source and build instructions** - https://xynosan.neocities.org/smb/
- **cc65 toolchain** - http://www.cc65.org/
- **Original game** - Nintendo

## License

This is a work of reverse engineering for educational and preservation purposes. The original game is copyright Nintendo.
