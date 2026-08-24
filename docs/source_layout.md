# Source Layout

This document tracks the address-ordered modularization of the native SMB1 PRG.
Module boundaries must preserve the original byte order and are accepted only
after `make verify-prg` succeeds.

## Granularity Policy

The project follows the same middle-grained organization used by the Pac-Man
reconstruction. A module owns a coherent subsystem, its closely related helper
routines, and the data those routines consume. Small routines are not split
into separate files merely to mirror a call graph or satisfy a line limit.

Typical modules should be a few hundred lines. The 200-500 line range is a
useful target when natural boundaries permit it; 700 lines is a soft upper
limit, not a mandate to fragment cohesive code.

## Current Address Map

| File | CPU range | Lines | Responsibility |
| --- | --- | ---: | --- |
| `src/memory/hardware.inc` | no emitted bytes | 23 | NES hardware registers |
| `src/memory/ram.inc` | no emitted bytes | 459 | Zero-page and RAM aliases |
| `src/memory/constants.inc` | no emitted bytes | 157 | Sound, music, object, input, and mode constants |
| `src/system/boot_and_frame.asm` | `$8000-$8230` | 282 | Reset, NMI frame driver, timers, pause, sprite shuffling, and mode dispatch |
| `src/main.asm` | `$8231-$FFFF` plus includes | 15,433 | Temporary address-ordered remainder awaiting extraction |

## Verification Baseline

- PRG size: 32,768 bytes
- PRG SHA-1: `fefa1097449a3a11ebf8c6199e905996c5dc8fbd`
- CHR size: 8,192 bytes
- CHR SHA-1: `394badaf0b0bdd0ea279a1bca89a9d9ddc00b1b5`
- Full ROM SHA-1: `ea343f4e445a9050d4b4fbac2c77d0693b1d0922`
- PRG-only verification command: `make verify-prg`
- Full byte-identity verification command: `make verify`

## Next Extraction Slice

The next slice begins at `$8231` with title-screen mode handling. It should
extract title/demo flow, victory flow, and screen/HUD routines into a small
number of cohesive modules. Tables remain with their owning code, and every
boundary will be chosen at a complete procedure or owned-data boundary.
