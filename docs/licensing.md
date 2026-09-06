# Licensing and Distribution Status

This repository separates technical provenance from permission to distribute
copyrighted material. Byte identity, source attribution, and a recorded hash do
not grant a license.

## Reconstructed Game Source

No license to Nintendo's original game code, graphics, music, characters, ROM
images, disk images, or FDS BIOS is granted by this repository. The assembly is
published as a reverse-engineering and preservation work; users are responsible
for obtaining required inputs lawfully and for complying with applicable law.
Original ROM/FDS/BIOS files and extracted proprietary assets are ignored and
must not be committed.

The project-specific documentation, Python tools, Lua helpers, and original
editor code currently have no separate repository-wide license grant. Their
presence in the repository does not by itself grant redistribution rights.

## Third-Party Material

- Bundled `ca65.exe` and `ld65.exe` are cc65 tools distributed under the zlib
  license reproduced in `bin/cc65-LICENSE.txt`; exact build provenance and
  hashes are recorded in `bin/README.md`.
- FCEUX is an external, unbundled dependency. Its source commit and the tested
  binary hash are pinned by `config/release_toolchain_3_0.json`; FCEUX remains
  governed by its upstream licenses.
- Runtime movie provenance and its CC BY 2.0 source are recorded in
  `movies/README.md`.
- Referenced editors and research sources are evidence only. Their license
  status is recorded where they are cited and their code is not imported unless
  an explicit provenance record says otherwise.

## Release Rule

Every new imported tool, fixture, data table, image, or other third-party file
must record its origin, applicable license or explicit `license_not_granted`
status, and a stable hash when byte identity matters. Release audits verify the
presence of these records; they do not make a legal determination.
