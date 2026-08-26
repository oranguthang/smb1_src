# ADR 0001: Expand Graphics with CNROM Before PRG Banking

- Status: Accepted
- Date: 2026-08-26
- Decision owner: Source Reconstruction 2.0

## Context

The canonical program fills all 32 KiB of the NROM-256 CPU window. Unlike the
Pac-Man reconstruction, it has no unused upper PRG half into which code can be
moved without changing existing addresses. Its reset vector targets $8000, its
NMI handler begins at $8082, and the fixed $C000..$FFFF half contains no proven
block large enough for reset, NMI, IRQ, and bank-call trampolines.

Expansion must leave the default Mapper 0 build untouched. It must also avoid a
design which happens to start in one emulator but depends on an undefined
power-on bank on cartridges.

## Options

### Reclaim bytes under Mapper 0

Known residual bytes can support very small fixed-layout changes, but they do
not create a general content bank. Reclaiming inferred dead code would weaken
the preservation evidence boundary and still leave the ROM at its mapper limit.

### Switch PRG banks

UxROM, MMC1, and MMC3 offer substantial PRG capacity. They also make at least
part of $8000..$BFFF switchable. SMB places reset, NMI, and early boot code in
that range, while the upper fixed bank is full. A robust conversion therefore
requires a reviewed relocation of interrupt-safe common code and mapper
register handling; merely relying on an emulator's initial bank is rejected.

### Switch CHR banks with CNROM

CNROM keeps the complete 32 KiB PRG continuously mapped at $8000..$FFFF and adds
8 KiB CHR banks selected through Mapper 3. The original vectors, NMI behavior,
fixed operands, vertical mirroring, and CHR-ROM rendering model remain valid.
Both initial banks can contain the canonical CHR, making every possible
power-on bank visually equivalent before explicit switching is introduced.

Bus-conflict-safe switching remains a requirement for a future graphics
variant. The present architecture intentionally performs no mapper writes.

### Convert to CHR-RAM

CHR-RAM would permit dynamic uploads but adds initialization time, mutable
graphics state, and broader source changes. It is unnecessary for the first
reversible graphics expansion.

## Decision

Adopt CNROM as the first expanded-ROM profile. Build it through a separate
entrypoint, linker configuration, manifest, output directory, and iNES header.
Require the entire PRG to equal the canonical PRG, allow no fixed-range patches,
and initialize both CHR banks from the locally extracted canonical CHR.

The acceptance gates mechanically verify the mapper header, complete PRG,
vectors as part of that PRG, every CHR-bank hash, and an FCEUX World 1-1 startup
observation. The default make build and make verify remain Mapper 0.

## Consequences

The project gains isolated mapper-backed ROM capacity for graphics without
pretending that safe PRG banking has been solved. Initial expanded output is
behaviorally equivalent, not yet a visible hack. A future CNROM content variant
may replace bank 1 and add a bus-conflict-reviewed selection routine through the
fixed-layout patch manifest. PRG expansion requires a new ADR and explicit
interrupt/common-code relocation evidence.
