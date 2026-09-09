# Isolated Build Variants

Variant builds exercise intentional changes outside the byte-identical
preservation contract. They use separate entrypoints, manifests, output
directories, and verification commands so no variant can silently replace the
canonical Mapper 0 build.

## Fixed-Layout Variant

Fixed-layout variants are explicit, reviewable modifications of the canonical
32 KiB PRG. They retain the NROM-256 layout, original header, and original CHR,
but they are never accepted by the preservation `make verify` contract.

The first demonstrator is `five_lives`. Its separate entrypoint defines
`con_initial_lives` as `$04`; the stored value counts spare lives, so the game
starts with five total lives. The preservation entrypoint defines no variant
flag and retains the original `$02` default.

Use the three independent acceptance layers:

```text
make build-hack
make verify-hack
make validate-hack
```

`build-hack` writes only beneath `build/variants/five_lives`. `verify-hack`
compares both PRG and complete ROM against the preservation build and accepts
only the byte declared in `config/fixed_layout_variants.json`. It therefore also
proves that header and CHR data are unchanged. `validate-hack` plays the tracked
FM2 in FCEUX and observes `ram_numberof_lives` immediately after primary game
setup, proving that the declared operand has the intended runtime effect.

Future fixed-layout variants must use their own source entrypoint and output
directory, declare every changed byte with its original value and reason, and
add a focused runtime observation. They may change constants or tables, or use
space separately proven unused; they must not add feature flags to
`src/main.asm`.

## Expanded-ROM Variant

The `make build-expanded` command produces
`build/expanded/cnrom_chr_16k/smb.nes`, an iNES Mapper 3 image with the exact
canonical 32 KiB PRG and two 8 KiB CHR banks. Both banks initially contain the
validated local canonical CHR, so the image is safe regardless of the mapper's
power-on CHR-bank value.

The `make verify-expanded` command enforces the reviewed layout in
`config/expanded_rom.json`: Mapper 3, vertical mirroring, no PRG differences,
and exact hashes for both CHR banks. Comparing the entire CPU window also
validates vectors, interrupt code, reset code, and every fixed operand.

The `make validate-expanded` command plays the tracked FM2 and observes active
World 1-1 RAM state in FCEUX. The expanded build has its own entrypoint, linker
configuration, manifest, and output directory. It does not alter or replace the
default Mapper 0 preservation build.

### Expanded-ROM Architecture Decision

This accepted decision was recorded on 2026-08-26 for the 2.0 source baseline.

The canonical program fills the complete 32 KiB NROM-256 CPU window. Its reset
vector targets `$8000`, its NMI handler begins at `$8082`, and the fixed
`$C000..$FFFF` half contains no proven block large enough for reset, NMI, IRQ,
and bank-call trampolines. Expansion must leave the default Mapper 0 build
untouched and must not depend on an emulator-specific power-on bank.

Reclaiming residual Mapper 0 bytes can support small fixed-layout changes but
cannot provide a general content bank. Treating inferred dead code as free space
would weaken the preservation boundary while leaving the ROM at its mapper
limit. UxROM, MMC1, and MMC3 provide PRG capacity, but make at least part of
`$8000..$BFFF` switchable while SMB keeps reset, NMI, and early boot code there.
Safe PRG banking therefore requires reviewed relocation of interrupt-safe common
code and mapper-register handling. CHR-RAM was also rejected for the first
expansion because it adds initialization time and mutable graphics state without
being necessary for reversible graphics capacity.

CNROM is the accepted first expanded profile because it keeps the entire 32 KiB
PRG continuously mapped at `$8000..$FFFF` while adding switchable 8 KiB CHR
banks. The original vectors, interrupt behavior, fixed operands, vertical
mirroring, and CHR-ROM rendering model remain valid. Both initial banks contain
the canonical CHR, making every possible power-on bank visually equivalent.
The current profile intentionally performs no mapper writes; any future visible
graphics variant must add bus-conflict-safe switching.

The separate entrypoint, linker configuration, manifest, output directory, and
iNES header isolate this decision from preservation builds. Acceptance verifies
the mapper header, complete canonical PRG, vectors through that PRG comparison,
every CHR-bank hash, and an FCEUX World 1-1 startup observation. The result adds
graphics capacity without claiming that safe PRG banking is solved. A future
CNROM content variant may replace bank 1 and add reviewed selection logic through
the fixed-layout patch contract; PRG expansion requires a separate architecture
decision and explicit interrupt/common-code relocation evidence.
