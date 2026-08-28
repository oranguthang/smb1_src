# Source Reconstruction 2.0

Source Reconstruction 2.0 extends the stable preservation source without
weakening it. The default entrypoint, Mapper 0 layout, reference hashes, local
asset boundary, complete runtime suite, and make verify contract remain those
of Source Reconstruction 1.0.

The release adds four isolated capability groups:

1. A fixed-layout five-lives demonstrator with a one-byte allowlist and focused
   runtime observation.
2. A conservative CNROM profile with an unchanged 32 KiB PRG, two validated CHR
   banks, an architecture decision record, and Mapper 3 runtime startup.
3. Four purpose-built Tkinter content studios covering ten 2.0 authored-data
   artifacts, editable CHR, and ignored atomic workspaces while retaining the
   original ten-artifact 1.0 evidence manifest unchanged.
4. Exact revision and platform profiles for the selected SMB1 engine family.

The profile family is complete. Japan/USA, PlayChoice-10, the European PAL
revision, Vs. Super Mario Bros., Famicom Disk System SMB1, and All Night Nippon
Super Mario Bros. are exact shared-source builds with deterministic platform
runtime gates. Both FDS profiles reconstruct their complete 65,500-byte disk
sides from ignored private templates and validate startup with an ignored,
hash-checked 8 KiB FDS BIOS. The Japanese SMB2 / The Lost Levels release is
outside the 2.0 scope.

The alternate European candidate remains an evaluated provenance record rather
than a required supported release unless independent evidence establishes its
identity. Source Reconstruction 3.0 is reserved for later semantic
consolidation, variant-wide authoring, deeper behavioral evidence, and possible
evaluation of the Japanese SMB2 engine.

The `make source-2-check` command is the aggregate acceptance gate. It first
runs the complete make release-check gate for 1.0. It then validates the
fixed-layout variant, expanded image, and supported profiles statically and in
their target emulators before cross-checking every 2.0 manifest, document,
target, roadmap milestone, and the immutable source-reconstruction-1.0 tag
target. The 2.0 layer also runs `make check-studios` so every ignored GUI
workspace remains encodable without requiring a display server.

The tracked `config/source_reconstruction_2_0.json` manifest is tag-ready. The
release tag remains an explicit maintainer action after review of the accepted
commit. Generated ROMs, disk images, extracted assets, content workspaces,
traces, emulator results, and the private FDS BIOS remain ignored local data.

## ANN Reconstruction Boundary

The shared ANN program and its compact platform tail form one exact 32 KiB
`NSMMAIN` payload. The complete `$B0E2-$BFBF` rendering interval is shared
semantic source, and the following `$BFBF-$E000` tail has this proven layout:

| CPU range | Size | Ownership |
| --- | ---: | --- |
| `$BFBF-$C1D3` | 532 bytes | FDS loader, file tables, prompt, and error reporting |
| `$C1D3-$C230` | 93 bytes | ANN game-over menu |
| `$C230-$C26F` | 63 bytes | Later-engine player-physics selectors |
| `$C26F-$C339` | 202 bytes | Course descriptor and loader helpers |
| `$C339-$C42B` | 242 bytes | Course sequence, scenery offsets, and pointer tables |
| `$C42B-$C745` | 794 bytes | Title processing, cursor, demo, initialization, and tile map |
| `$C745-$D13E` | 2,553 bytes | ANN course and enemy data |
| `$D13E-$D2BE` | 384 bytes | Private guest CHR source asset |
| `$D2BE-$D2E4` | 38 bytes | Initialized FDS save record and alignment |
| `$D2E4-$DFFA` | 3,350 bytes | ANN sound engine, effects, music, periods, and envelopes |
| `$DFFA-$E000` | 6 bytes | NMI, reset, and FDS IRQ vectors |

The production entrypoint switches to this complete tail at `$BFBF` rather than
mixing it with the larger SMB1 level bank. `NSMDATA2`, `NSMDATA3`, and
`NSMDATA4` are separate project-native overlays with their own linker maps.
Executable regions, loaders, and address-bearing tables remain semantic ASM.
Private graphics and typed course streams are reproducibly extracted from the
validated reference into ignored content packs, then included through explicit
per-stream boundaries. Together the four exact payloads reconstruct the
complete ANN disk side without retaining opaque executable code.
