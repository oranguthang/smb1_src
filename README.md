# Super Mario Bros Disassembly

A comprehensive disassembly of Super Mario Bros for the Nintendo Entertainment System (NES).

## Overview

This repository contains:

- **smbdis.asm** - Complete Super Mario Bros disassembly by doppelganger
- **ca65** - 6502 assembly compiler from [cc65](http://www.cc65.org/)
- **ld65** - 6502 linker from [cc65](http://www.cc65.org/)
- **6502jsm.txt** - Summary of 6502 CPU instructions

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
   ca65 smbdis.asm
   ```

2. Link the object file:
   ```bash
   ld65 -C ldconfig.txt smbdis.o
   ```

3. Create the final NES ROM:
   ```bash
   copy /b smb.hdr+smb.prg+smb.chr smb.nes
   ```

The resulting `smb.nes` file can be run in any NES emulator.

## Modifying the Game

### Changing Mario's Physics

Mario's physics are controlled by data tables starting around line 6016:

```asm
JumpMForceData:
      .byte $20, $20, $1e, $28, $28, $0d, $04

FallMForceData:
      .byte $70, $70, $60, $90, $90, $0a, $09

PlayerYSpdData:
      .byte $fc, $fc, $fc, $fb, $fb, $fe, $ff

InitMForceData:
      .byte $00, $00, $00, $00, $00, $80, $00

MaxLeftXSpdData:
      .byte $d8, $e8, $f0

MaxRightXSpdData:
      .byte $28, $18, $10
      .byte $0c ;used for pipe intros

FrictionData:
      .byte $e4, $98, $d0
```

- **JumpMForceData** - Controls jump arc decay when moving upward. Larger values = shorter jumps
- **FallMForceData** - Controls fall speed. Larger values = faster falling
- **PlayerYSpdData** - Initial jump force (negative signed value) based on running speed. Values below $fa result in very high jumps
- **MaxLeftXSpdData** / **MaxRightXSpdData** - Running, walking, and water-walking speeds
- **FrictionData** - Friction applied at different speeds (fastest to slowest)

### Enabling Mid-Air Jumping

Around lines 6076-6077, replace:

```asm
lda SwimmingFlag           ;if swimming flag not set, jump to do something else
beq NoJump                 ;to prevent midair jumping, otherwise continue
```

With:

```asm
nop
nop
nop
nop
nop
```

This allows Mario to jump unlimited times in mid-air (like in the Air hack).

**Note:** You need exactly 5 `nop` instructions to match the byte count of the original code (lda = 3 bytes, beq = 2 bytes).

### Creating Reviving Goombas

Around line 11495, modify:

```asm
RevivalRateData:
      .byte $10, $0b
```

The first value determines how long a stomped enemy takes to change state. Set it to $0d or lower to make Goombas revive after being stomped. (The second value is used in Second Quest.)

## Credits

- **Disassembly** - doppelganger (doppelheathen@gmail.com)
- **Original source** - https://gist.github.com/1wErt3r/4048722
- **ca65-adapted source and build instructions** - https://xynosan.neocities.org/smb/
- **cc65 toolchain** - http://www.cc65.org/
- **Original game** - Nintendo

## License

This is a work of reverse engineering for educational and preservation purposes. The original game is copyright Nintendo.
