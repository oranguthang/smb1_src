# Preservation Source 1.0

Preservation Source 1.0 is the first stable, navigable reconstruction profile
for Super Mario Bros. (Japan, USA). It is a source-preservation baseline, not a
claim that every residual byte or historical design intention is known.

## Identity

| Property | Value |
| --- | --- |
| Complete ROM SHA-1 | `ea343f4e445a9050d4b4fbac2c77d0693b1d0922` |
| PRG SHA-1 | `fefa1097449a3a11ebf8c6199e905996c5dc8fbd` |
| CHR SHA-1 | `394badaf0b0bdd0ea279a1bca89a9d9ddc00b1b5` |
| Mapper and mirroring | NROM mapper 0, vertical |
| PRG layout | `$8000..$FFF9` plus vectors at `$FFFA..$FFFF` |
| Toolchain | ca65/ld65 2.19, Git `0fca835` |

The repository tracks PRG source and hashes, but no original ROM, CHR, or iNES
header payload. Local assets are validated before use and remain ignored.

## Stable Contract

- `src/main.asm` includes 38 cohesive address-ordered PRG modules and the fixed
  vector block as one ca65 translation unit.
- `make verify-prg` requires the exact 32 KiB PRG without proprietary graphics.
- `make verify` requires the exact complete locally supplied reference ROM.
- Semantic RAM/constants and callable/control-flow prefixes are mechanically
  checked; major subsystem contracts and ownership are documented.
- Material uncertainty remains searchable in `docs/unknowns.md` and is linked
  from evidence-tagged source locations.
- Mesen source records, FCEUX symbols, breakpoint groups, and RAM watch groups
  are generated from the current build rather than copied addresses.
- Twelve runtime scenarios reproduce the main gameplay transactions. Ten are
  natural movie evidence; two declare and trace controlled RAM patches.
- Ten typed authored-data artifacts decode and re-encode to their exact source
  bytes across every milestone-8 format family.

## Release Gate

`make release-check` is the complete 1.0 acceptance command. Its layers are:

1. assembly style, semantic naming, Python syntax, documentation links,
   evidence registry, and hardware-operand lint;
2. focused unit tests for build, formatting, naming, physics, symbols, runtime,
   codecs, and release auditing;
3. typed binary decode/encode round trips;
4. full-ROM SHA-1 and byte comparison;
5. live FCEUX symbol resolution, semantic NMI breakpoint, focused transaction
   traces, and the 17,862-frame movie regression;
6. agreement among release, asset, runtime, toolchain, documentation, roadmap,
   and tracked-payload policies.

Generated build, symbol, JSON, and CSV artifacts are disposable. A fresh clone
plus the matching legal ROM input can recreate them through the documented
commands.

## Evidence Boundary

Byte identity proves faithful assembly output, not that every current name or
comment is historically canonical. Static observations, runtime observations,
assumptions, unknowns, suspected bugs, and unused code remain explicitly
distinct. In particular, controlled power-up and death/respawn scenarios prove
the transaction after their declared boundary; they do not prove natural setup.

The format codecs cover useful representative artifacts and their actual packed
grammars. They are a stable extension pattern, not a promise that all level,
graphics, and audio data already has an editor-facing schema.

## After 1.0

Create the local annotated tag `preservation-source-1.0` at this state before
behavior-changing work. Fixed-layout hacks, mapper expansion, content tools, and
other revisions belong to later roadmap milestones with separate builds and
verification. The preservation entrypoint, hashes, and byte-identity gate remain
the permanent reference.
