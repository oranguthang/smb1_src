# SMB2 Late-FDS Revision Reconstruction

Japanese Super Mario Bros. 2 / The Lost Levels entered Source Reconstruction
3.0 as an independently verified sibling engine. Post-release instruction-flow
comparison established that it and ANN are revisions of one late-FDS engine.
They retain independent payload entrypoints and byte-identity contracts while
shared code is promoted only where equivalence has been measured.

The first shared promotion is complete: the upside-down-pipe runtime,
hard-course loader, and checkpoint initializer now live under
`src/platforms/late_fds/common/`. Together they cover the complete
168-instruction hard-course match measured between ANN and SMB2; revision-owned
tables and wind/spring extensions remain separate.

The feasibility evidence connects 40,349 of 52,075 same-ID payload bytes to
ANN, and the corresponding FDS images use the same eight file roles. The low
same-address ratios nevertheless prove that the main program and overlays have
their own layouts. The project therefore reuses infrastructure and reviewed
knowledge, not an engine-wide web of `.if SMB2` alternatives.

## Source Boundary

SMB2 payload entrypoints live under `src/revisions/smb2/`, symmetrically with
ANN. Its current implementation modules live under
`src/platforms/late_fds/smb2/`; independently proven common modules are promoted
to `src/platforms/late_fds/common/`. The cartridge-era SMB1 modules keep their
Source Reconstruction 2.0 meaning and may not acquire SMB2 selection
conditionals. Modules remain small enough to review while representing complete
responsibilities rather than dozens of tiny instruction fragments.

Each program payload has an independent entrypoint and linker contract:

| Payload | Load address | Size | Role |
| --- | ---: | ---: | --- |
| `SM2MAIN` | `$6000` | 32,768 | Main engine and worlds 1-4 |
| `SM2DATA2` | `$C470` | 3,631 | Worlds 5-8 and loaded gameplay extensions |
| `SM2DATA3` | `$C5D0` | 3,279 | Ending, World 9, and FDS music |
| `SM2DATA4` | `$C2B4` | 3,916 | Worlds A-D and loaded gameplay extensions |

The private identity boundary remains available as a bootstrap check. Run
`make split-smb2-assets` explicitly to hash-check the original disk, create a
zeroed private template, and retain its records beneath ignored
`assets/generated/smb2/`. Ordinary builds never split or overwrite those inputs.
`make build-smb2-identity` and `make verify-smb2-identity` reproduce the complete
65,500-byte disk side from those retained payloads.

The normal reconstruction no longer uses private program payloads. The pinned
listings are normalized into 52 source files across the SMB2 revision and
late-FDS platform trees, with the largest responsibility-owned module remaining
below 700 lines. Implementation modules use `.asm`; `.inc` is reserved for
declarations and interfaces. `make build-smb2-source`
assembles one scoped ca65 unit so cross-overlay imports retain their original
meaning, then emits `SM2MAIN`, `SM2DATA2`, `SM2DATA3`, and `SM2DATA4` as four
separate files. `make verify-smb2-source` checks every payload identity without
requiring the FDS image. `make verify-smb2` additionally composes the source-built
programs with the private license, CHR, and save records and requires SHA-1
`20e50128742162ee47561db9e82b2836399c880c` for the complete disk side.

## Runtime Evidence

`make validate-smb2-runtime` starts the complete source-built FDS image through
the pinned 8 KiB BIOS and waits 1,200 frames. It requires the stable title-mode
RAM contract recorded in `config/smb2_platform_profile.json`; this proves that
the independent reconstruction reaches the ordinary engine rather than merely
forming the right disk bytes.

`make validate-smb2-overlays` performs three additional clean emulator boots.
Each run selects one normal operating-mode transition and lets the game's own
FDS loader fetch `SM2DATA2`, `SM2DATA3`, or `SM2DATA4`. The validator derives a
16-byte distinguishing signature from the already hash-checked source payload,
observes it at the payload's declared CPU load address, and requires the disk
task to finish. Signatures are selected against the resident `SM2MAIN` bytes,
which avoids treating the shared prefix of `SM2DATA4` as evidence of a load.

`make validate-smb2-gameplay` presses Start through the emulated controller,
enters World 1-1 through the normal mode tree, and supplies a deterministic
Right+B input sequence with two jumps. The accepted 360-frame slice remains in
the active game loop throughout and advances Mario by 472 pixels into page 2.

## Relocation Evidence

The main program contains 83 source-declared unused `$FF` bytes immediately
before the save byte at `$D29F`. `make test-smb2-relocation` generates an
isolated candidate with eight `$EA` probes distributed across the system,
frame, area, player, enemy, collision, disk, and course boundaries. It consumes
only eight bytes of that padding and keeps the save byte and `$D29F..$DFF9`
audio ABI fixed. The vector slots remain at `$DFFA..$DFFF`, while their operands
follow the shifted NMI, RESET, and IRQ handlers.

The accepted candidate moves 1,860 `SM2MAIN` labels and preserves 316 overlay
label addresses. All four program hashes change because imports in
`SM2DATA2`, `SM2DATA3`, and `SM2DATA4` follow the shifted main engine within the
same ca65 scope. `make validate-smb2-relocation` then repeats title startup,
all three real FDS overlay loads, and the deterministic World 1-1 slice with
execute traps at every probe. The final gameplay state must match the
byte-identical baseline exactly.

These gates prove all four executable programs participate in the running disk
image and survive controlled address movement independently from ANN.

Executable payloads must be visible assembly; `.incbin` is forbidden for code.
CHR, license data, and the save byte remain ignored private assets extracted
from the hash-checked original disk. No raw ROM, FDS, or CHR image is tracked.

## Verification Reference

The ignored `references/threecreepio-smb2j` checkout is the ca65 port of
doppelganger's comprehensive SMB2J disassembly at commit
`9c40114626ecd07f13e16d5e67e217b98482d7af`. Its README provides the source
as-is. Building it locally with the project's ca65/ld65 produces SHA-1
`20e50128742162ee47561db9e82b2836399c880c`, exactly matching the private FDS
reference. It is a verification oracle and naming aid, not a directory layout
to copy. The much more fragmented `segaloco-smb` meta-disassembly remains a
secondary cross-check for relationships between SMB2 and ANN.

`scripts/import_smb2_source.py` pins the SHA-1 of each reference listing and
records all 2,383 original colon labels plus three callable FDS BIOS constants
in `docs/provenance/smb2_label_renames.json`. Records use payload, original name,
current semantic name, and current path; line numbers are intentionally omitted
so comment and formatting changes cannot invalidate provenance. Exact original
matches reuse 1,935 already reviewed SMB1 semantic stems while recomputing their
roles for SMB2; another 112 later-engine-only abbreviations have direct reviewed
expansions. The remaining records retain descriptive SMB2 reference semantics,
primarily course, message, and music data, instead of inventing unsupported
interpretations.

## Promotion Order

1. Add exact disk identity, extraction, private-template, and four-payload build
   contracts.
2. Import and normalize the four program listings into reviewed project source,
   then split them by meaningful responsibility without changing bytes.
3. Apply the project ASM style and semantic snake_case naming while retaining a
   generated original-name mapping.
4. Prove runtime startup, overlay transitions, course behavior, and relocation
   independently from ANN.
5. Add SMB2 to a Studio only after that Studio's pointer tables, capacities,
   and output composition are proven for all relevant payloads.

Code is shared only after independent static and runtime evidence establishes
equivalence. `make later-engine-source-overlap` supplies the instruction-level
promotion map; similar bytes, matching addresses, or a common historical
ancestor are not sufficient promotion criteria.
