# Platform Profiles

Source Reconstruction 2.0 includes three platform descendants in addition to
the ordinary cartridge revisions. They share verified engine ancestry with
Super Mario Bros. but require independent container, memory-map, asset, and
runtime contracts.

## Vs. Super Mario Bros.

The supplied `VS. Super Mario Bros. (VS).nes` image is the verified GoodNES
payload candidate. Its 32 KiB PRG and 16 KiB CHR payload has been reproduced
byte for byte by the ignored segaloco meta-disassembly reference. That build
differs from the supplied image only in two legacy iNES header bytes, so the PRG
and CHR provide a reliable semantic transfer boundary.

The project build must still originate in this repository. The ignored
reference repository and its generated binaries are evidence, not build
dependencies. The final profile must model VS System input, coin, DIP-switch,
PPU, title, game-over, level, graphics, and audio alternatives in reviewed
source and must reproduce the complete selected private reference.

## Famicom Disk System SMB1

The FDS reissue relocates the early SMB engine into the Disk System memory map,
uses disk files and CHR RAM, and relies on FDS platform services. The supplied
`Super Mario Brothers (Japan).fds` image is a raw 65,500-byte disk side without
the optional 16-byte FDS file header. Its SHA-1 is
`383ad8e3890a95de9595f0a6087648f51177da13`.

The ignored segaloco meta-disassembly reproduces the 32 KiB `SMMAIN` program
payload exactly. This establishes a source-transfer baseline, but the project
profile remains incomplete until the disk memory map, file layout, CHR-RAM
loading, platform services, and build are represented and verified here.

## All Night Nippon Super Mario Bros.

All Night Nippon is an official promotional derivative on the later FDS engine
branch shared with the Japanese SMB2. Its graphics, courses, character physics,
ending, audio, and disk files are not a simple CHR replacement over cartridge
SMB1.

The supplied
`All Night Nippon Super Mario Brothers (Japan) (Promotion Card).fds` image is a
raw 65,500-byte disk side without the optional 16-byte FDS file header. Its
SHA-1 is `f30bdd3c556604d7eaa6d0f4864d5566e519b5d4`. After normalizing that container
difference for the reference extractor, the ignored segaloco meta-disassembly
reproduces all four program payloads (`NSMMAIN` and `NSMDATA2` through
`NSMDATA4`) exactly.

The supplied GoodNES `.nes` image with SHA-1 `51db085d...` remains classified
as an unofficial FDS-to-NROM conversion. It is useful as auxiliary behavioral
and content evidence but is not the identity boundary for the original disk
release.

The Japanese SMB2 / The Lost Levels release profile is outside the 2.0 scope.
Code or data alternatives shared with All Night Nippon may still be introduced
when directly supported by ANN evidence.
