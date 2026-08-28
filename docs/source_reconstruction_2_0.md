# Source Reconstruction 2.0

Source Reconstruction 2.0 extends the stable preservation source without
weakening it. The default entrypoint, Mapper 0 layout, reference hashes, local
asset boundary, complete runtime suite, and make verify contract remain those
of Source Reconstruction 1.0.

The developing release adds four isolated capability groups:

1. A fixed-layout five-lives demonstrator with a one-byte allowlist and focused
   runtime observation.
2. A conservative CNROM profile with an unchanged 32 KiB PRG, two validated CHR
   banks, an architecture decision record, and Mapper 3 runtime startup.
3. Four purpose-built Tkinter content studios covering ten 2.0 authored-data
   artifacts, editable CHR, and ignored atomic workspaces while retaining the
   original ten-artifact 1.0 evidence manifest unchanged.
4. Exact revision and platform profiles for the selected SMB1 engine family.

The profile family is not complete yet. Japan/USA, PlayChoice-10, the European
PAL revision, and Vs. Super Mario Bros. are exact shared-source builds with
runtime startup gates. The Famicom Disk System SMB1 reissue now has an exact
shared-source `SMMAIN` build and exact complete-disk reconstruction; its FDS
BIOS-backed runtime gate remains pending. All Night Nippon Super Mario Bros.
still requires project-native source integration. The Japanese SMB2 / The Lost
Levels release is outside the 2.0 scope.

The alternate European candidate remains an evaluated provenance record rather
than a required supported release unless independent evidence establishes its
identity. Source Reconstruction 3.0 is reserved for later semantic
consolidation, variant-wide authoring, deeper behavioral evidence, and possible
evaluation of the Japanese SMB2 engine.

The eventual `make source-2-check` command is the aggregate acceptance gate. It
first runs the complete make release-check gate for 1.0. It then validates the
fixed-layout variant, expanded image, and supported profiles statically and in
their target emulators before cross-checking every 2.0 manifest, document,
target, roadmap milestone, and the immutable source-reconstruction-1.0 tag
target. The 2.0 layer also runs `make check-studios` so every ignored GUI
workspace remains encodable without requiring a display server.

The tracked `config/source_reconstruction_2_0.json` manifest remains in
development and is not tag-ready. The release tag will remain an explicit
maintainer action after every profile and aggregate gate is complete. Generated
ROMs, disk images, extracted assets, content workspaces, traces, and emulator
results remain ignored local data.

## ANN Reconstruction Boundary

The shared ANN program is reconstructed through the end of actor positioning at
`$BFBF`. The complete `$B0E2-$BFBF` rendering interval is byte-identical to the
verified `NSMMAIN` payload. The remaining program tail has the following proven
layout:

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

This tail must be switched into the production entrypoint as one address-space
unit. Inserting only the 532-byte loader overflows the fixed 32 KiB FDS image,
because the current temporary ANN build still places the larger SMB1 level bank
at `$BFBF`. Replacing that bank with the compact ANN course/title/save layout
provides the corresponding space and restores every downstream address. This is
an assembly-layout dependency, not a reason to retain opaque program bytes.
