# Official Revision Profiles

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

The locally available European REV0 and REVA images were evaluated separately
and their exact component hashes are recorded in config/revision_profiles.json.
They are deliberately not supported profiles. REV0 has a known independently
reproducible PAL source reference, but porting it requires reviewed timing,
physics, audio, collision, level-data, and padding alternatives across 21
source areas. REVA also has distinct PRG and CHR data. Neither is approximated
by address matching or a binary patch.
