# Super Mario Bros Disassembly

A comprehensive disassembly of Super Mario Bros for the Nintendo Entertainment System (NES).

The current stable reconstruction is **Preservation Source 1.0**. It rebuilds
the selected reference ROM byte-for-byte and provides semantic source
navigation, runtime evidence, and typed data round trips without tracking the
original ROM or CHR payload.

## Overview

This repository contains:

- **src/main.asm** - Address-ordered entrypoint for the modular disassembly
- **src/nrom256_prg_only.cfg** - Linker configuration for the 32 KiB PRG image
- **bin/ca65.exe** - 6502 assembly compiler from [cc65](http://www.cc65.org/)
- **bin/ld65.exe** - 6502 linker from [cc65](http://www.cc65.org/)
- **docs/6502_reference.md** - NES 6502 instructions, flags, and opcodes
- **docs/modding_examples.md** - Example gameplay edits and patch ideas
- **docs/naming.md** - Semantic symbol vocabulary and evidence rules
- **docs/player_movement.md** - Player input, physics, collision, and traces
- **docs/ram_fields.md** - Verified semantic RAM-field registry
- **docs/subsystems.md** - Address-ordered system architecture and ownership
- **docs/unknowns.md** - Stable uncertainty and evidence registry
- **docs/debugger_workflow.md** - Mesen/FCEUX symbols and source navigation
- **docs/runtime_evidence.md** - Deterministic gameplay transaction scenarios
- **docs/data_formats.md** - Typed authored-data codecs and byte round trips
- **docs/provenance/label_renames.json** - Original-to-current symbol map
- **docs/preservation_source_1_0.md** - Stable release scope and evidence boundary
- **CONTRIBUTING.md** - Safe source, data, evidence, and verification workflow

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
|   |-- 6502_reference.md
|   `-- modding_examples.md
|-- scripts/            # Cross-platform build, split, and validation logic
|-- src/                # Assembly source and linker config
|   |-- audio/          # Sound effects, music engine, and music data
|   |-- data/           # Level streams and fixed interrupt vectors
|   |-- game/           # Modes, physics, objects, enemies, and collisions
|   |-- nrom256_prg_only.cfg
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
# Check tracked text, assembly style, semantic source, and documentation
make lint

# Normalize assembly formatting and run the same checks
make format

# Run focused Python tooling tests
make test

# Generate Mesen/FCEUX symbols and validate them in live FCEUX
make symbols
make validate-symbols

# Replay and validate focused gameplay transactions
make trace-runtime

# Run the complete live debugger and emulator evidence layer
make trace

# Decode, re-encode, and compare representative authored data
make roundtrip-formats

# Run every Preservation Source 1.0 acceptance gate
make release-check

# Validate local assets and build build/native/smb.nes
make build

# Rebuild and require complete byte identity with the reference ROM
make verify

# Validate extracted assets without changing them
make check-assets

# Remove build/native safely; extracted assets remain untouched
make clean
```

The Makefile contains only thin entrypoints. Assembly-style validation, ROM
parsing, safe extraction, assembly, linking, concatenation, checksum validation,
and cleanup are implemented in platform-independent Python scripts under
`scripts/`. See [`docs/assembly_style.md`](docs/assembly_style.md) for the checked
source conventions and [`docs/naming.md`](docs/naming.md) for the semantic symbol
vocabulary. See [`docs/debugger_workflow.md`](docs/debugger_workflow.md) for
interactive source navigation and [`docs/runtime_evidence.md`](docs/runtime_evidence.md)
for reproducible emulator evidence.
The reversible data contracts are documented in
[`docs/data_formats.md`](docs/data_formats.md).
Contribution rules and the stable-release boundary are documented in
[`CONTRIBUTING.md`](CONTRIBUTING.md) and
[`docs/preservation_source_1_0.md`](docs/preservation_source_1_0.md).

## Modding Notes

For a few practical modification examples, see [docs/modding_examples.md](docs/modding_examples.md).

## Credits

- **Disassembly** - doppelganger (doppelheathen@gmail.com)
- **Original source** - https://gist.github.com/1wErt3r/4048722
- **ca65-adapted source and build instructions** - https://xynosan.neocities.org/smb/
- **cc65 toolchain** - http://www.cc65.org/
- **Runtime input movie** - DJ Incendration,
  [fixture provenance](movies/README.md),
  [TASVideos user file 68410246126700593](https://tasvideos.org/UserFiles/Info/68410246126700593)
- **Original game** - Nintendo

## License

This is a work of reverse engineering for educational and preservation purposes. The original game is copyright Nintendo.
