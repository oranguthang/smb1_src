# Platform Profiles

Source Reconstruction 2.0 includes three platform descendants in addition to
the ordinary cartridge revisions. They share verified engine ancestry with
Super Mario Bros. but require independent container, memory-map, asset, and
runtime contracts.

## Vs. Super Mario Bros.

The supplied `VS. Super Mario Bros. (VS).nes` image is the verified GoodNES
payload candidate. The repository reconstructs its complete 32 KiB PRG at
SHA-1 `f25ab9354e24e3cd99b6cfd8331f9be40b603c5b`. VS System input, coin,
DIP-switch, PPU, title, game-over, level, rendering, and audio alternatives are
selected from reviewed source by `src/revisions/vs.asm`.

Run `make split-platform-assets PLATFORM=vs_smb` once to extract the private
16-byte header and 16 KiB CHR into the ignored asset directory. Then
`make verify-platform PLATFORM=vs_smb` reconstructs and compares the complete
iNES image at SHA-1 `3546486ba461536545daf9f27c9bcf275fc162da`.
`make validate-platform PLATFORM=vs_smb` additionally checks the deterministic
arcade title state in FCEUX without applying the console input movie. The
ignored reference repositories and their generated binaries remain evidence,
not build dependencies.

## Famicom Disk System SMB1

The FDS reissue relocates the early SMB engine into the Disk System memory map,
uses disk files and CHR RAM, and relies on FDS platform services. The supplied
`Super Mario Brothers (Japan).fds` image is a raw 65,500-byte disk side without
the optional 16-byte FDS file header. Its SHA-1 is
`383ad8e3890a95de9595f0a6087648f51177da13`.

The project-native `src/revisions/fds_smb.asm` entrypoint reconstructs the full
32 KiB `SMMAIN` payload at SHA-1
`3634eb60ad0fbc60a07683cdf98cc6a1701b56a0`. It shares the semantic SMB1 source
with the cartridge profiles while selecting the `$6000-$DFFF` load map, FDS
reset and interrupt contract, BIOS stack workspace, and exact alignment bytes.

Run `make split-platform-assets PLATFORM=fds_smb` once. The extractor validates
the complete private disk and writes an ignored template with both `SMMAIN`
file records zeroed; disk metadata, license data, and CHR-RAM source files stay
in that private template. `make verify-platform PLATFORM=fds_smb` then builds
`SMMAIN` from source, restores its two records, and compares the entire rebuilt
65,500-byte disk side at SHA-1
`383ad8e3890a95de9595f0a6087648f51177da13`.

This profile is supported at the strongest container identity boundary.
`make validate-platform PLATFORM=fds_smb` verifies exact disk reconstruction,
checks the local 8 KiB FDS BIOS contract, and observes the deterministic title
startup state at frame 1200. The BIOS is never stored in the repository; FCEUX
expects the private file as `disksys.rom` beside its executable.

## All Night Nippon Super Mario Bros.

All Night Nippon is an official promotional derivative on the later FDS engine
branch shared with the Japanese SMB2. Its graphics, courses, character physics,
ending, audio, and disk files are not a simple CHR replacement over cartridge
SMB1.

The supplied
`All Night Nippon Super Mario Brothers (Japan) (Promotion Card).fds` image is a
raw 65,500-byte disk side without the optional 16-byte FDS file header. Its
SHA-1 is `f30bdd3c556604d7eaa6d0f4864d5566e519b5d4`. The project-native
`src/revisions/ann.asm` entrypoint and the three data-overlay entrypoints
reproduce all four program payloads exactly: the 32,768-byte `NSMMAIN` at SHA-1
`8f07dfdda5829983a1deec8c82dd26e196826cd9`, the 3,584-byte `NSMDATA2` at
`48447986778a9c39fc8cabf4e5494d99fab7e020`, the 3,346-byte `NSMDATA3` at
`8941894b39a959aab87338728919a8b475e4f691`, and the 3,568-byte `NSMDATA4` at
`eec327d5ebde3891439971986ae23afeefbdd1a7`.

Run `make split-platform-assets PLATFORM=ann_fds` once. The extractor validates
the complete private disk and writes an ignored template with all four program
payloads zeroed. `make verify-platform PLATFORM=ann_fds` then assembles each
payload from reviewed semantic source, restores the corresponding FDS records,
and compares the complete rebuilt disk side against the reference.

`make split-platform-assets PLATFORM=ann_fds` also extracts the 384-byte guest
CHR region embedded in `NSMMAIN` to the ignored
`assets/generated/platforms/ann_fds/source/guest_chr.bin` file. The manifest
records its payload offset, size, and SHA-1
`8b1721dc53856c29637ca03f96b43eb104330ea3`; the authored bitmap bytes never
enter Git. The corresponding 288-byte `NSMDATA2` guest CHR source is extracted
as `guest_chr_data2.bin` at SHA-1
`139bb17536ed774e1f4742087f2fe17212492897`. Tables, course streams, tile maps,
code, and the initialized save record remain readable source rather than being
hidden behind asset slices.

This profile is supported at the complete-container identity boundary.
`make validate-platform PLATFORM=ann_fds` verifies all four payloads and the
complete disk before checking the deterministic ANN title startup state at
frame 1200. The gate uses the same ignored private FDS BIOS contract as FDS
SMB1.

The supplied GoodNES `.nes` image with SHA-1 `51db085d...` remains classified
as an unofficial FDS-to-NROM conversion. It is useful as auxiliary behavioral
and content evidence but is not the identity boundary for the original disk
release.

The Japanese SMB2 / The Lost Levels release profile is outside the 2.0 scope.
Code or data alternatives shared with All Night Nippon may still be introduced
when directly supported by ANN evidence.
