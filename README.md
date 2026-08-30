# Super Mario Bros Disassembly

A comprehensive disassembly of Super Mario Bros for the Nintendo Entertainment System (NES).

The current tag-ready release candidate is **Source Reconstruction 3.0**. It
retains the byte-identical Preservation Source 1.0 baseline and complete Source
Reconstruction 2.0 contract while adding relocation proofs, deeper semantic
evidence, seven-profile content authoring, and a separate source reconstruction
of Japanese SMB2 / The Lost Levels. Original ROMs, disk images, CHR payloads,
and extracted content remain private ignored inputs.

The immutable `source-reconstruction-1.0` and `source-reconstruction-2.0` tags
preserve their original release contracts. Source Reconstruction 3.0 keeps
every earlier acceptance gate and layers its new contracts on top.

The complete `make source-3-check` gate qualifies the 3.0 candidate without
changing either stable predecessor tag or the default byte-identical build. See
[`docs/source_reconstruction_3_0.md`](docs/source_reconstruction_3_0.md).

## Overview

This repository contains:

- **src/main.asm** - Address-ordered entrypoint for the modular disassembly
- **config/linker/** - Linker contracts for native, expanded, FDS, and ANN payloads
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
- **docs/source_reconstruction_2_0.md** - Aggregate 2.0 scope and acceptance gate
- **docs/source_reconstruction_3_0.md** - Active 3.0 milestones and boundaries
- **docs/relocation_testing.md** - Generated address-shift and runtime proof
- **CONTRIBUTING.md** - Safe source, data, evidence, and verification workflow

## Project Structure

```text
smb1_src/
|-- bin/                # Local ca65/ld65 toolchain
|   |-- ca65.exe
|   `-- ld65.exe
|-- assets/
|   |-- manifest.json   # Reference identity and extracted-asset hashes
|   `-- generated/      # Ignored local container, graphics, and content assets
|-- config/
|   `-- linker/         # Native, expanded, FDS, and ANN linker contracts
|-- docs/               # Local technical notes
|   |-- 6502_reference.md
|   `-- modding_examples.md
|-- scripts/            # Cross-platform build, split, and validation logic
|-- src/                # Assembly source
|   |-- audio/          # Sound effects, music engine, and music data
|   |-- data/           # Level streams and fixed interrupt vectors
|   |-- game/           # Modes, physics, objects, enemies, and collisions
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
- `assets/generated/chr/smb.chr` - 8192-byte CHR-ROM payload;
- two typed course packs containing the enemy and area-object streams;
- one bounded music-data pack containing streams, lookup tables, and envelopes;
- one bounded area-palette pack shared by the console and disk profiles;
- one bounded 2x2 metatile graphics pack.

The ROM and extracted files are ignored and are not included in the repository.
PAL revisions and ROMs with extra trailing payloads are rejected by default.

## Building

### Preservation PRG build

After the one-time `make split`, the reconstruction can be assembled and
checked without retaining the ROM image:

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

# Run Preservation Source 1.0 plus every Source Reconstruction 2.0 gate
make source-2-check

# Audit the Source Reconstruction 3.0 boundary and milestone state
make source-3-audit

# Run the complete Source Reconstruction 3.0 release gate
make source-3-check

# Rebuild SMB2 / The Lost Levels and verify the complete FDS side
make verify-smb2

# Prove SMB2 startup and all three normal FDS overlay-load paths
make validate-smb2-runtime
make validate-smb2-overlays

# Exercise World 1-1 and prove all four programs survive controlled relocation
make validate-smb2-gameplay
make validate-smb2-relocation

# Build and statically validate the generated canonical relocation candidate
make test-relocation

# Run debugger and complete runtime evidence against the relocation candidate
make validate-relocation

# Build and validate the JU, PlayChoice-10, and PAL relocation matrix
make test-relocation-revisions
make validate-relocation-revisions

# Build and validate the isolated fixed-layout demonstrator
make validate-hack

# Build and validate the isolated CNROM profile
make validate-expanded

# Export, validate, and build ignored codec-backed content workspaces
make init-content
make export-content
make validate-content
make build-content

# Open the four local Tkinter authoring programs
make world-studio
make level-studio
make graphics-studio
make sound-studio

# Build and run the ignored edited-content ROM
make run-content

# Validate every studio input without opening a window
make check-studios

# Verify and run all supported official profiles
make verify-revisions
make validate-revisions

# Extract private assets for every supported ROM and verify the complete matrix
make split-all
make verify-all

# Extract private Vs. container assets once, then verify its full image and runtime
make split-platform-assets PLATFORM=vs_smb
make verify-platform PLATFORM=vs_smb
make validate-platform PLATFORM=vs_smb

# Extract the private FDS template once, then verify the exact rebuilt disk side
make split-platform-assets PLATFORM=fds_smb
make verify-platform PLATFORM=fds_smb

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
