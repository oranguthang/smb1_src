# Revision Profiles

The profile system supports two locally verified official configurations:

| Profile | Engine payload | Additional private payload | Complete SHA-1 |
| --- | --- | --- | --- |
| ju | Canonical Japan/USA PRG and CHR | None | ea343f4e445a9050d4b4fbac2c77d0693b1d0922 |
| pc10 | Same canonical PRG and CHR | 8 KiB platform tail | d48d2c65fda380217ead73ffa6a46cae62939194 |

Each profile has a separate assembly entrypoint defining con_revision_profile,
but both include the same semantic src/main.asm engine. Their outputs live under
build/revisions/PROFILE. No post-link PRG patch is permitted.

The PlayChoice-10 container has an extra 8 KiB payload after the ordinary iNES
header, PRG, and CHR regions. It is treated like CHR: the repository records
only its size and SHA-1. Run make split-revision-assets PROFILE=pc10 once with
the matching private ROM to create the ignored local platform asset. Ordinary
profile builds validate but never overwrite it.

Run make verify-revisions to assemble and compare both complete images against
their own private references. Run make validate-revisions for the shared FCEUX
startup observation. No regional timing gate is claimed because the two
supported profiles share an identical engine PRG.

The locally available European images were evaluated by payload identity rather
than by their historical filenames. The file named `(REV0) [!p]` has complete
SHA-1 `ab30029e...` and contains the verified PAL PRG/CHR payload commonly
identified as European Rev A. The file named `(REVA) [!p]` contains the
historical alternate European candidate formerly catalogued as Rev B with
pending-dump provenance. The profile IDs therefore use `europe_reva` and
`europe_revb_candidate`; the supplied filenames remain recorded only as private
input names.

Both European profiles remain unsupported until their differences are
represented by reviewed source-level alternatives. The PAL profile requires
timing, physics, audio, collision, level-data, and padding alternatives across
the shared engine. The candidate has a mostly Japan/USA-derived PRG and a
distinct CHR payload, but its uncertain provenance must never be promoted to an
official revision merely because it can be reproduced byte for byte.

Platform-specific descendants are tracked separately in
`config/platform_profiles.json` and `docs/platform_profiles.md`. This keeps
ordinary NROM revision facts separate from VS System and Famicom Disk System
layout facts.
