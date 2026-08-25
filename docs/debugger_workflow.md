# Debugger Symbols and Source Navigation

The native preservation build emits debugger artifacts from the same ca65
translation unit that reproduces the reference ROM. Generate the complete set
with:

```bash
make symbols
```

All generated files remain ignored under `build/native/`:

- `smb.nes` is the byte-identical preservation ROM;
- `smb.dbg` contains ld65 symbols, source files, line records, and spans for
  Mesen;
- `smb.map` is the verbose linker map;
- `smb.lbl` contains VICE-format linker labels;
- `smb.nes.0.nl` and `smb.nes.ram.nl` contain FCEUX ROM and RAM labels;
- `debug_symbols.json` resolves the tracked breakpoint and watch groups against
  the current build.

## Mesen

Keep `smb.dbg` beside `smb.nes` with the same basename and open the rebuilt ROM
in Mesen. Source View can then map an instruction back to its module and line
under `src/`. Regenerate the artifacts after moving the checkout or changing
source line positions because ca65 records the source paths present at build
time.

The linker writes a bare 32 KiB PRG while the debugger opens the final iNES
image. `scripts/debug_symbols.py` retargets every output segment to `smb.nes`
and adds the 16-byte iNES header to its file offset. This prevents source spans
from pointing 16 bytes before the corresponding ROM instruction.

## FCEUX

FCEUX loads `.nl` files placed beside the ROM. The ROM label file exposes one
preferred semantic name per CPU address; the RAM file exposes `ram_` and `zp_`
aliases suitable for watches. Run this live proof with the local automation
build:

```bash
make validate-symbols
```

The check resolves eight representative ROM/RAM symbols through the FCEUX Lua
debugger API and installs an execution hook on `vec_nmi_handler`. Success proves
that the emulator reached the named entry during natural boot, rather than only
checking text-file syntax.

## Breakpoints and Watches

`config/debugger_breakpoints.json` groups frame/mode, player, gameplay
transaction, object, and audio entry points. `config/debugger_watches.json`
groups mode state, controller/player motion, progress, objects, rendering, and
audio RAM. Entries use source symbols, never copied numeric addresses.

After `make symbols`, read `build/native/debug_symbols.json` for the current
resolved addresses and descriptions. The generator rejects missing symbols and
also follows representative definition records back to the exact source file
and label line, catching stale debug data.

## Validation Layers

```bash
make test              # Debug parser/config unit tests plus all existing tests
make symbols           # Artifact, segment-offset, and source-line validation
make validate-symbols  # Live FCEUX lookup and named NMI execution hook
make verify             # Authoritative byte-identity gate
```

Mesen remains the preferred interactive source debugger. FCEUX supplies the
repeatable runtime proof and deterministic Lua/movie automation.
