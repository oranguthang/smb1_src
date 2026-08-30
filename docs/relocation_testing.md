# Relocation Testing

The relocation workflow proves that semantic references survive controlled
address movement. It never changes the preservation source or its byte-identical
output. Generated entrypoints, source overrides, ROMs, symbols, traces, and
summaries stay under ignored `build/relocation/` paths.

## Canonical Layout

The 32 KiB NROM program has no general free tail. The canonical test therefore
uses two independently checked budgets:

| Region | Insertions | Absorbed original bytes | Fixed successor |
| --- | ---: | --- | --- |
| Game and rendering | 6 | `$F2CA..$F2CF`, source-declared unused space | Audio at `$F2D0` |
| Audio | 3 | `$FEFD..$FEFF`, unread victory-stream tail | Synthesis tables at `$FF00` |

The Sound Studio decoder establishes that victory music lasts 384 frames and
reads square 2 through `$FEDC`, square 1 through `$FEEC`, and triangle through
`$FEFD`, with all end addresses exclusive. The three `$FF` bytes beginning at
`$FEFD` are therefore outside every decoded channel. Runtime validation adds
execution traps at all nine inserted addresses and replays every deterministic
scenario, including the complete 17,862-frame movie.

The generated linker contract divides the CPU window into game, audio, fixed
synthesis-table, and vector regions. `$FF00..$FFF9` remains byte-identical. The
vector slots remain at `$FFFA..$FFFF`, while their operands must follow the
relocated NMI and RESET labels; requiring the original operands would defeat
the relocation proof.

## Commands

Run the static build and layout proof with:

```bash
make test-relocation
```

This command:

- rebuilds the canonical preservation ROM first;
- generates source overrides without modifying `src/`;
- assembles a distinct 32 KiB relocation candidate;
- verifies every absorbed byte and inserted `$EA` probe;
- checks the exact cumulative shift of every active debug label;
- verifies the fixed synthesis tables and relocated vectors;
- writes a machine-readable summary beside the candidate ROM.

Run the complete debugger and emulator gate with:

```bash
make validate-relocation
```

The accepted canonical candidate moves 1,999 of 2,006 active labels through
nine independent insertion boundaries. Candidate-native Mesen/FCEUX artifacts
resolve 2,751 symbols and pass the live NMI debugger check. All twelve runtime
scenarios retain their expected event frames, controlled-patch boundaries, and
final states, and no probe address executes.

## Revision Matrix

Run every cartridge revision layout with:

```bash
make test-relocation-revisions
make validate-relocation-revisions
```

| Profile | Probes | Shifted labels | Runtime evidence |
| --- | ---: | ---: | --- |
| JU | 9 | 1,999 of 2,006 | Debugger plus all 12 deterministic scenarios |
| PlayChoice-10 | 9 | 1,999 of 2,006 | Debugger plus all 12 scenarios in the complete container |
| PAL Rev A | 2 | 1,997 | PAL-mode debugger and active World 1-1 gate |

The PlayChoice-10 profile independently assembles through its own revision ID.
Its PRG is byte-identical to JU before relocation and produces the same
relocated PRG, while its private 8 KiB platform payload is retained unchanged in
the candidate container.

PAL does not borrow the six-byte JU gap. Its two probes move the complete
program in two cumulative regions and consume only `$FEFE..$FEFF`, after the
PAL decoder has independently shown every victory-music channel ending by
`$FEFE`. The PAL linker keeps synthesis data at `$FF00`; live checks explicitly
select FCEUX PAL timing.

The manifests under `config/relocation/` own insertion anchors, absorbed ranges,
fixed ranges, minimum label coverage, and runtime inputs. Changes to an anchor
or source boundary must fail closed when the expected token, byte range,
decoded music end, label delta, or runtime behavior differs.

## Platform Layouts

Run the accepted platform matrix with:

```bash
make test-platform-relocations
make validate-relocation-platforms
```

| Profile | Probes | Shifted labels | Fixed successor | Runtime evidence |
| --- | ---: | ---: | --- | --- |
| Vs. SMB | 5 | 2,107 | Synthesis tables at `$FF00` | Focused arcade startup state and execute traps |
| FDS SMB | 3 | 1,999 | Synthesis tables at `$DF00` | Focused disk startup state and execute traps |
| ANN | 6 | 1,839 | Save byte and audio at `$D2E3` | Focused title state and execute traps across all program payloads |

Vs. SMB consumes only `$FEFB..$FEFF`, after its distinct game-over stream is
decoded through the exclusive end `$FEFB`. The proof exposed absolute aliases
in the Vs. title and victory modules; these now name their semantic engine
entry points while the preservation image remains byte-identical. The direct
FCEUX read of the memory-mapped Vs. timer-mode register at `$6603` is
cycle-sensitive, so the relocation snapshot excludes only that register and
still checks every stable RAM field plus every execute trap.

FDS SMB consumes the same three decoder-proven victory-tail bytes as JU, but
at `$DEFD..$DEFF` in its `$6000..$DFFF` load window. Candidate construction
replaces only the verified `SMMAIN` disk-file records and preserves all other
bytes of the reference disk side.

ANN moves 1,839 labels inside `NSMMAIN` through a six-byte origin shift while
the initialized save byte and `$D2E3..$DFF9` audio ABI remain fixed. Its
two-phase build derives 26 imported addresses from candidate debug labels,
rebuilds `NSMDATA2`, `NSMDATA3`, and `NSMDATA4` at their original load
addresses, and replaces all four program payloads in the candidate FDS. The
generated interface also verifies every baseline address before accepting the
candidate. Main-resident title and portrait aliases follow semantic labels;
addresses belonging to dynamically loaded payloads remain fixed by design.
The focused FCEUX title gate passes with execute traps on every inserted byte.

## SMB2 Sibling Layout

Run the independent later-engine proof with:

```bash
make test-smb2-relocation
make validate-smb2-relocation
```

`SM2MAIN` has 83 source-declared unused bytes at `$D24C..$D29E`, immediately
before the separately loaded save byte. The generated candidate consumes eight
of them with probes at major responsibility boundaries and keeps the save byte
plus audio ABI at `$D29F..$DFF9` fixed. NMI, RESET, and IRQ vector slots stay at
`$DFFA..$DFFF`, and their operands follow their shifted semantic handlers.

The candidate moves 1,860 main labels and checks 316 overlay labels at their
unchanged load addresses. Because all four programs assemble together,
cross-program references in `SM2DATA2`, `SM2DATA3`, and `SM2DATA4` follow the
shifted `SM2MAIN`; requiring all four candidate hashes to change guards that
property. Runtime validation boots the candidate, exercises all three FDS
overlay-load paths, and compares a 360-frame World 1-1 transaction against the
byte-identical baseline. Execute traps cover every inserted probe throughout.
