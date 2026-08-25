# Super Mario Bros. NES Source Reconstruction Roadmap

## Project Goal

Turn the existing reassemblable Super Mario Bros. listing into a readable,
documented, native 6502/ca65 source tree that explains the game as an engineered
system while preserving an exact original ROM build.

The preservation build must remain the default and permanent reference. ROM
hacks, expanded layouts, editable assets, and tooling must be isolated from it
and must never weaken its byte-identity gate.

This project is not a C rewrite. The original 6502 instruction stream, memory
layout, timing behavior, and data formats remain the source of truth.

## Preservation Contract

The first technical milestone is to identify the exact reference ROM reproduced
by the current listing. The likely baseline must not be accepted from a filename
or assumption alone. It must be established by assembling the current source and
comparing the complete PRG and ROM bytes against locally supplied references.

Once established, the repository will record:

- the canonical revision name and expected filename;
- full-ROM, PRG-ROM, and CHR-ROM SHA-1 hashes;
- mapper, mirroring, trainer, PRG, and CHR properties from the iNES header;
- the exact ca65/ld65 build command and tool versions;
- the first differing file and CPU address on verification failure.

`make verify` is the authoritative preservation gate. Annotation,
renaming, module splitting, macros, and documentation work must never alter the
produced bytes.

## Current Baseline

- The original `src/smbdis.asm` contained one address-ordered source file of
  16,351 lines. `src/main.asm` is now a 73-line address-ordered module index.
- The PRG is split across 38 cohesive ASM modules. Excluding the entrypoint and
  fixed ten-line vector block, module sizes range from 136 to 694 lines after
  label-per-line formatting.
- Hardware definitions, RAM aliases, constants, code, and data were separated
  without renaming symbols or changing emitted bytes.
- The linker fixes the `PRG` segment at `$8000..$FFF9` and the six-byte
  `VECTORS` segment at `$FFFA..$FFFF`; together they form the 32 KiB PRG image.
- `make verify-prg` builds the native source under `build/native/`, emits labels,
  a linker map, and debug data, and validates PRG SHA-1
  `fefa1097449a3a11ebf8c6199e905996c5dc8fbd`.
- The user-supplied `Super Mario Bros. (JU) [!].nes` reference has been
  validated as mapper 0 with vertical mirroring, 32 KiB PRG, and 8 KiB CHR.
- `make verify` reproduces its complete ROM SHA-1
  `ea343f4e445a9050d4b4fbac2c77d0693b1d0922` byte-for-byte.
- `make lint` enforces the documented ca65 whitespace, layout, comment-spacing,
  mnemonic-case, directive-case, semantic-prefix, module-size, and direct
  `JSR`/`sub_` consistency rules. The checkers have focused unit tests; runtime
  scenarios are not yet present.
- All 516 RAM and assembly-time constant definitions use explicit `ram_` and
  `con_` prefixes. All 295 callable labels use `sub_`, have a direct `JSR`
  caller, and are protected by the semantic lint gate.
- No original `.nes`, `.chr`, or `.hdr` file is tracked in the current Git
  history.
- Repository text normalization is enforced by `.gitattributes`.

## Source and Proprietary Asset Policy

Original ROM images and raw CHR pattern data are private local inputs. They must
not be committed to Git.

The canonical asset flow will be:

1. The user supplies a legally obtained reference ROM outside version control.
2. `make split` validates its identity against the tracked manifest.
3. The extractor writes ignored files under `assets/generated/`.
4. `make build` consumes those files but never extracts or overwrites them.
5. `make verify` compares the complete generated ROM with the reference.

The 8 KiB CHR-ROM bitmap payload belongs in `assets/generated/chr/` and is
validated and appended by the native build script. The repository may contain
its expected size, address range, and cryptographic digest, but not its bytes.

Graphics-related PRG data is not the same thing as CHR pattern data. Palette
tables, metatile composition, sprite tile indexes, animation mappings, PPU
command streams, level data, and other understood program data remain in
annotated ca65 source. They are necessary to reconstruct and explain the PRG and
must not be extracted merely because they influence graphics.

Opaque PRG payloads may be extracted only when all of the following are true:

- the data is an authored binary asset rather than program logic or a meaningful
  editable table;
- its boundaries and checksum are proven;
- labels and pointer relationships remain visible in source;
- extraction and rebuilding are deterministic;
- the preservation build remains byte-identical.

## Target Source Layout

`src/main.asm` will be the canonical module index. Its includes will follow CPU
address order exactly. Cross-file branches and labels may remain global because
the native source will continue to assemble as one ca65 translation unit.

```text
src/
  main.asm
  memory/
    hardware.inc
    ram.inc
    constants.inc
    revisions.inc
  macros/
  system/
  game/
    player/
    enemies/
    collisions/
    level/
    objects/
  rendering/
    actors/
    hud/
  audio/
  data/
```

Prefer one coherent responsibility per file. Aim for roughly 200-500 lines when
a natural boundary exists and treat 700 lines as a soft upper limit. Do not split
a procedure or separate a small table from the code that owns it merely to meet
a line-count target.

## Address-Ordered Module Groups

The modular split preserved every existing symbol and byte. Its broad source
groups were:

| Current source range | Initial responsibility |
| --- | --- |
| Definitions through `DIRECTIVES` | Hardware, RAM, and constants |
| `vec_reset_handler` through `sub_sprite_shuffler` | Reset, NMI, frame processing, pause |
| `sub_oper_mode_execution_tree` through screen text | Modes, title, victory, HUD |
| `RenderAreaGraphics` through score output | Background, VRAM, PPU helpers |
| `InitializeGame` through game-over flow | Game and area initialization |
| `sub_area_parser_task_handler` through level data | Area parser, objects, level streams |
| `GameMode` through player physics | Game core, scrolling, player control |
| Fireballs through shared movement | Gameplay objects and common physics |
| `sub_enemies_and_loops_core` through enemy initialization | Enemy stream parser and setup |
| `RunEnemyObjectsCore` through platform runtime | Enemy and platform behavior |
| Fireball/enemy collision through block-buffer collision | Collision systems |
| `sub_draw_vine` through sprite/offscreen helpers | OAM, actors, and animation |
| `sub_sound_engine` through music data | Audio engine and streams |
| Interrupt vectors | Fixed vectors |

These groups guided the final boundaries recorded in `docs/source_layout.md`.
Every boundary falls between complete procedures or owned data blocks and is
backed by linker addresses and full-ROM byte verification.

## Naming and Evidence Rules

Symbols should describe program roles rather than ROM addresses. The intended
control-flow vocabulary is:

| Prefix | Meaning |
| --- | --- |
| `sub_` | Directly callable `JSR` subroutine returning with `RTS` |
| `handler_` | Entry selected by a dispatcher or jump table |
| `loc_` | Shared entry reached with `JMP` or deliberate fall-through |
| `bra_` | Internal conditional branch target |
| `vec_` | CPU interrupt/reset vector entry |
| `tbl_` | Indexed table or lookup data |
| `ram_` | Persistent or domain-specific RAM field |
| `zp_` | Neutral zero-page workspace |
| `con_` | Verified assembly-time constant |
| `unused_` | Code or data proven unreachable for the reference revision |

Existing semantic names will be retained until their replacements are supported
by static analysis or runtime evidence. Renaming is incremental and each batch
must pass `make verify`.

Source and documentation use explicit reverse-engineering evidence tags:

- `!(OBS)` - directly observed in code, ROM data, a trace, or emulator state;
- `!(ASSUME)` - supported working interpretation that is not yet proven;
- `!(WHY?)` - mechanics are known but purpose remains unclear;
- `!(UNKNOWN)` - behavior, state, or data format is not understood;
- `!(BUG?)` - suspected original-game bug requiring evidence;
- `!(UNUSED)` - code or data proven unreachable for the selected revision.

Material uncertainty belongs in `docs/unknowns.md` with a stable identifier,
current evidence, confidence, and the smallest experiment that could resolve it.

## Procedure Documentation Standard

Substantial routines should converge on concise verified contracts:

```asm
; Update horizontal player movement for the current frame.
;
; Inputs:
;   ram_player_x_speed - signed current horizontal speed
;
; Outputs:
;   Player page and pixel coordinates may be updated.
;
; Clobbers:
;   A, X, Y
;
; Invariants:
;   Fractional movement is accumulated before the integer position update.
sub_update_player_horizontal_movement:
```

Do not invent inputs, outputs, clobbers, or invariants to complete the template.

## Milestones

### 0. Repository Hygiene and Reference Selection - Complete

- Add an explicit LF text policy and normalize the current line-ending-only
  working-tree changes separately from source reconstruction.
- Audit all reachable Git objects for accidentally tracked ROM, CHR, header, or
  extracted asset payloads.
- Identify the exact reference ROM reproduced by the current listing.
- Record reference hashes and cartridge properties.
- Preserve the unmodified monolithic source as the comparison baseline.

Exit criterion: the repository has a clean, reviewable baseline and one proven
reference identity.

### 1. Reproducible Native Build and Byte-Identity Gate - Complete

- Replace root-level build artifacts with an ignored `build/` directory.
- Add a platform-independent native build script around ca65 and ld65.
- Emit PRG, ROM, labels, map, and debug information.
- Add a tracked `assets/manifest.json` and validated explicit extraction.
- Make `build` non-destructive and make `verify` compare complete bytes.
- Report hashes and the first differing file/CPU address on failure.

Exit criterion: `make verify` reproduces the selected reference ROM exactly.

### 2. Reproducible Modular Baseline - Complete

- Introduce `src/main.asm` as an address-ordered include index.
- Move definitions into `src/memory/` without renaming them.
- Split the monolithic PRG into subsystem modules at procedure/data boundaries.
- Keep every intermediate change byte-identical.
- Document the final CPU-address-to-file map in `docs/source_layout.md`.

Exit criterion: the modular tree builds the exact same ROM and no ordinary ASM
module exceeds the agreed size budget.

### 3. Mechanical Cleanup and Semantic Naming - Complete

- Separate hardware registers, RAM fields, constants, and ROM data symbols.
  The physical files exist, sound-engine RAM aliases have been moved out of
  `constants.inc`, and RAM/constants use explicit semantic prefixes.
- Adopt the control-flow and data-prefix vocabulary incrementally.
  Callable routines, player movement control flow, shared movement entries, and
  their indexed tables now use the documented vocabulary. Existing descriptive
  local labels remain valid until their subsystem evidence supports refinement.
- Remove address-derived active symbol names where they exist.
  Semantic lint rejects new lowercase address-derived identifiers.
- Normalize whitespace and source formatting with mechanically checkable rules.
  The initial assembly formatter and lint gate are complete.
- Introduce only small domain macros that preserve instruction order,
  addressing mode, flags, cycles, and emitted bytes.
  No macro was introduced without a repeated domain operation that justified
  the additional abstraction.

Exit criterion: symbols communicate verified roles and every rename/macro batch
passes byte verification.

### 4. Player Movement Reference Documentation - Complete

Use player movement and physics as the first complete documentation standard:

- controller sampling and A/B edge handling;
- walking, running, crouching, skidding, and friction;
- jump initiation, variable jump height, falling, and swimming;
- climbing, pipes, automatic movement, injury, and death states;
- page/pixel/fractional coordinate updates;
- player-to-background collision ownership.

Produce procedure contracts, a subsystem narrative, RAM aliases, tuning-table
formats, and deterministic jump/movement traces.

The reference pass is recorded in `docs/player_movement.md` and
`docs/ram_fields.md`. `make trace-player` parses the source tables and emits a
tested deterministic 6502 fixed-point jump trace. Emulator-backed comparison is
owned by milestone 6 rather than being implied by the static model.

### 5. Systematic Subsystem Documentation - Complete

Apply the same evidence standard in this order:

1. reset, NMI, frame scheduling, controller input, and PPU buffering;
2. title, attract/demo, game, victory, and game-over mode transitions;
3. scrolling, screen setup, status display, and area rendering;
4. area-object and enemy-object stream parsing;
5. blocks, coins, power-ups, fireballs, vines, flagpole, and scoring;
6. enemy initialization, movement, state transitions, and special actors;
7. player/enemy/platform/background collision systems;
8. sprite composition, animation, OAM allocation, and offscreen handling;
9. sound effects, music selection, channel arbitration, and stream decoding;
10. level, graphics-mapping, music, padding, and vector data.

Each pass updates source contracts, subsystem documentation, the unknowns
registry, and the relevant runtime evidence without changing the reference ROM.

`docs/subsystems.md` records the address-ordered ownership and principal
contracts for all ten groups. Source contracts cover the frame scheduler, area
and enemy parsing, background composition, bounding boxes, player rendering,
and audio arbitration. `docs/unknowns.md` provides stable evidence IDs for
unresolved or proven-residual behavior; emulator experiments remain milestone 6.

### 6. Debugger Symbols and Runtime Evidence - Planned

- Convert ld65 labels/debug data into Mesen and FCEUX-friendly artifacts.
- Provide named breakpoint groups and standard RAM watch lists.
- Connect runtime addresses back to semantic source locations.
- Add focused FM2/Lua scenarios for title boot, starting World 1-1, walking,
  jumping, block impact, coin collection, power-up collection, enemy stomp,
  pipe entry, death/respawn, and flagpole completion.
- Retain a longer deterministic movie as a broad frame/memory regression gate.
- Record controlled patches explicitly and never treat them as natural evidence.

Exit criterion: a contributor can stop on a named routine, inspect meaningful
state, and reproduce the main gameplay transactions.

### 7. Automated Source and Documentation Validation - In Progress

Add layered checks:

```text
make lint       # fast text, source, naming, and documentation invariants
make test       # focused tooling and codec unit tests
make verify     # authoritative byte-identical preservation gate
make trace      # slower emulator-backed behavioral evidence
```

Lint rules should be introduced only when precise enough to avoid false
positives. They may cover line endings, trailing whitespace, module size,
symbol vocabulary, direct `JSR` targets, raw hardware operands, evidence tags,
documentation links, and Python syntax.

The initial assembly-style gate now covers printable-ASCII source text, line
endings, final newlines, tabs, trailing whitespace, blank-line runs, label
layout, nested indentation, mnemonic/directive case, operand spacing, and
comment spacing. It also rejects leading blank lines, terminal comment periods,
and non-ASCII comment text with a manual English-rewrite diagnostic. Distinguishing
English from another language written entirely in unaccented Latin characters
remains a review requirement rather than a probabilistic heuristic.

### 8. Decode and Round-Trip Data Formats - Planned

Specify and test reversible decoders/encoders for useful authored formats:

- world, area, and entrance pointer tables;
- area-object and enemy-object streams;
- metatile and palette mappings;
- PPU update packets and status/text blocks;
- player/enemy sprite mappings and animation tables;
- music headers, note streams, envelopes, and sound effects;
- physics and gameplay tuning tables.

A format is stable only after:

```text
binary -> decoded representation -> encoded binary
```

reproduces the original bytes. Normal preservation builds must never regenerate
or overwrite editable local documents implicitly.

### 9. Preservation Source 1.0 - Planned

Declare the first stable reconstruction release when:

- the modular native source rebuilds the reference ROM exactly;
- major routines have verified purpose and useful contracts;
- core RAM fields, constants, formats, and state machines are documented;
- uncertainty is explicit and searchable;
- debugger navigation and focused runtime scenarios work;
- contributors can modify one subsystem without mentally reconstructing the
  complete 32 KiB PRG.

Tag this state before normalizing behavior-changing work.

### 10. Isolated Fixed-Layout ROM-Hack Variants - Planned

Introduce separate entrypoints and outputs:

```text
make build          # preservation ROM
make verify         # exact original bytes
make build-hack     # explicitly modified fixed-layout ROM
make verify-hack    # only manifest-declared differences are permitted
make validate-hack  # prove intended behavior in an emulator
```

Small hacks may use changed constants, tables, or proven unused space. The
preservation entrypoint must never define hack feature flags.

### 11. Expanded-ROM Architecture - Planned

Super Mario Bros. already occupies a complete NROM-256 PRG address space, so the
Pac-Man NROM-128-to-NROM-256 expansion technique cannot be reused directly.

Before implementing an expanded build, write and review an architecture decision
record comparing:

- reclaiming proven unused bytes while retaining Mapper 0;
- moving to an appropriate bank-switching mapper;
- preservation of `$C000..$FFFF`, vectors, NMI behavior, and fixed operands;
- safe bank switching during gameplay and interrupts;
- CHR-ROM versus CHR-RAM requirements;
- emulator and cartridge compatibility.

The expanded layout must have a separate linker configuration and entrypoint.
It must preserve the original build as the default and mechanically validate
every fixed-bank operand and allowed patch site.

### 12. Content Authoring Tools - Planned

Build editors only on top of stable tested codecs. Candidate focused tools are:

- World/Area Studio for object and enemy streams;
- Physics Studio for player and object tuning tables;
- Graphics Studio for local CHR, metatiles, palettes, and sprite mappings;
- Screen Studio for title, text, HUD, and PPU packets;
- Sound Studio for music and SFX streams.

Editors save ignored local assets atomically, expose capacity/format limits,
compare original and edited content, invoke the shared build pipeline, and never
invent a second encoding implementation.

### 13. Official Multi-Revision Builds - Planned

After the canonical reconstruction is mature, evaluate locally available
official revisions. Each supported profile must have:

- a tracked revision identifier and exact hashes;
- an isolated output directory;
- one shared semantic source selected by compile-time flags;
- source-level alternatives instead of post-link patches;
- byte-identical verification against its own private reference;
- focused regional runtime gates where timing or rendering differs.

Facts must not be transferred between revisions by matching addresses alone.

### 14. Source Reconstruction 2.0 - Planned

A later release may combine the stable preservation source with reversible
content authoring, isolated expanded-ROM support, and verified official revision
profiles. Its release audit must keep Source Reconstruction 1.0 and the default
reference `make verify` contract intact.

## Permanent Project Invariants

- Original ROM images and raw extracted CHR data are never tracked.
- The default source and build reproduce the canonical reference byte for byte.
- Module order preserves the original CPU address layout.
- Names and comments distinguish evidence from inference.
- Preservation, fixed-layout hacks, and expanded builds have separate outputs
  and acceptance rules.
- Extraction is explicit; ordinary builds never overwrite local assets.
- Editable formats have deterministic encoders and round-trip tests.
- Runtime claims are backed by static evidence, traces, or controlled experiments.
- Convenience tooling may grow, but it never becomes the source of truth for
  the original program.
