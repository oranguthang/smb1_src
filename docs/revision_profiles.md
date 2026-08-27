# Revision Profiles

The profile system supports three locally verified official configurations:

| Profile | Engine payload | Additional private payload | Complete SHA-1 |
| --- | --- | --- | --- |
| ju | Canonical Japan/USA PRG and CHR | None | ea343f4e445a9050d4b4fbac2c77d0693b1d0922 |
| pc10 | Same canonical PRG and CHR | 8 KiB platform tail | d48d2c65fda380217ead73ffa6a46cae62939194 |
| pal | European Rev A PAL PRG with canonical CHR | None | ab30029efec6ccfc5d65dfda7fbc6e6489a80805 |

Each profile has a separate assembly entrypoint defining con_revision_profile,
but all include the same semantic src/main.asm engine. Their outputs live under
build/revisions/PROFILE. No post-link PRG patch is permitted.

The PlayChoice-10 container has an extra 8 KiB payload after the ordinary iNES
header, PRG, and CHR regions. It is treated like CHR: the repository records
only its size and SHA-1. Run make split-revision-assets PROFILE=pc10 once with
the matching private ROM to create the ignored local platform asset. Ordinary
profile builds validate but never overwrite it.

Run make verify-revisions to assemble and compare all complete images against
their own private references. Run make validate-revisions for the common FCEUX
startup observation. The PAL profile explicitly enables PAL emulation timing;
Japan/USA and PlayChoice-10 retain the NTSC engine path.

The locally available European images were evaluated by payload identity rather
than by their historical filenames. The file named `(REV0) [!p]` has complete
SHA-1 `ab30029e...` and contains the verified PAL PRG/CHR payload commonly
identified as European Rev A. It is the supported `pal` profile and reproduces
the complete ROM byte for byte from reviewed timing, physics, audio, collision,
level-data, and padding alternatives. The file named `(REVA) [!p]` contains the
historical alternate European candidate formerly catalogued as Rev B with
pending-dump provenance. The supplied filenames remain recorded only as private
input names.

The alternate candidate has a mostly Japan/USA-derived PRG and a distinct CHR
payload, but its uncertain provenance must never be promoted to an official
revision merely because it can be reproduced byte for byte. It remains an
evaluated unsupported input and is not required by Source Reconstruction 2.0.

Platform-specific descendants are tracked separately in
`config/platform_profiles.json` and `docs/platform_profiles.md`. This keeps
ordinary NROM revision facts separate from VS System and Famicom Disk System
layout facts.
