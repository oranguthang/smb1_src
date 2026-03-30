# Super Mario Bros Disassembly

A comprehensive disassembly of Super Mario Bros for the Nintendo Entertainment System (NES).

## Overview

This repository contains:

- **src/smbdis.asm** - Complete Super Mario Bros disassembly by doppelganger
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
|-- docs/               # Local technical notes
|   |-- 6502jsm.txt
|   `-- modding_examples.md
|-- src/                # Assembly source and linker config
|   |-- ldconfig.txt
|   `-- smbdis.asm
|-- Makefile            # Main build entrypoint
|-- README.md
`-- .gitignore
```

## Prerequisites

To build the ROM, you need to extract the header and CHR ROM data from an original Super Mario Bros ROM file. Place one of the following ROM files in the project directory:

- `Super Mario Bros. (E) (REV0) [!p].nes`
- `Super Mario Bros. (E) (REVA) [!p].nes`
- `Super Mario Bros. (JU) [!].nes`

Then run:

```bash
make split
```

This will extract:
- **smb.hdr** - iNES ROM header (16 bytes)
- **smb.chr** - Character ROM data (8192 bytes, graphics)

**Note:** These files are not included in the repository due to copyright concerns. The `split` command extracts them from your legally owned ROM file.

## Building

### Using Makefile

```bash
# Build the ROM
make build

# Clean build artifacts
make clean

# Build everything (same as build)
make all
```

### Manual build steps

1. Assemble the source:
   ```bash
   bin/ca65.exe -o smbdis.o src/smbdis.asm
   ```

2. Link the object file:
   ```bash
   bin/ld65.exe -C src/ldconfig.txt smbdis.o
   ```

3. Create the final NES ROM:
   ```bash
   copy /b smb.hdr+smb.prg+smb.chr smb.nes
   ```

The resulting `smb.nes` file can be run in any NES emulator.

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
