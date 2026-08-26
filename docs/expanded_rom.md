# Expanded-ROM Build

The make build-expanded command produces
build/expanded/cnrom_chr_16k/smb.nes, an iNES Mapper 3 image with the exact
canonical 32 KiB PRG and two 8 KiB CHR banks. Both banks initially contain the
validated local canonical CHR, so the image is safe regardless of the mapper's
power-on CHR-bank value.

The make verify-expanded command enforces the reviewed layout in
config/expanded_rom.json: Mapper 3, vertical mirroring, no PRG differences, and
exact hashes for both CHR banks. Because the entire CPU window is compared, this
also validates vectors, NMI/reset code, and every fixed operand.

The make validate-expanded command plays the tracked FM2 and observes active
World 1-1 RAM state in FCEUX. The expanded build has its own entrypoint, linker
configuration, manifest, and output directory. It does not alter or replace the
default Mapper 0 preservation build.

The rationale and the explicit boundary around future PRG banking are recorded
in docs/adr/0001-expanded-rom-architecture.md.
