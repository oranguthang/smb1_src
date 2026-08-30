# SMB2 Sibling Reconstruction

Japanese Super Mario Bros. 2 / The Lost Levels is included in Source
Reconstruction 3.0 as a sibling engine. It is not an additional conditional
profile of the existing SMB1 source.

The feasibility evidence connects 40,349 of 52,075 same-ID payload bytes to
ANN, and the corresponding FDS images use the same eight file roles. The low
same-address ratios nevertheless prove that the main program and overlays have
their own layouts. The project therefore reuses infrastructure and reviewed
knowledge, not an engine-wide web of `.if SMB2` alternatives.

## Source Boundary

All SMB2-owned assembly lives below `src/smb2/`. The existing SMB1 modules keep
their Source Reconstruction 2.0 meaning and may not acquire SMB2 selection
conditionals. The planned groups are `system`, `game`, `rendering`, `audio`,
`data`, and `overlays`; files should remain small enough to review but represent
complete responsibilities rather than dozens of tiny instruction fragments.

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
listings are normalized into 52 source files under `src/smb2`, with the largest
responsibility-owned module remaining below 700 lines. `make build-smb2-source`
assembles one scoped ca65 unit so cross-overlay imports retain their original
meaning, then emits `SM2MAIN`, `SM2DATA2`, `SM2DATA3`, and `SM2DATA4` as four
separate files. `make verify-smb2-source` checks every payload identity without
requiring the FDS image. `make verify-smb2` additionally composes the source-built
programs with the private license, CHR, and save records and requires SHA-1
`20e50128742162ee47561db9e82b2836399c880c` for the complete disk side.

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
4. Prove runtime startup, course loading, overlay transitions, and relocation
   independently from ANN.
5. Add SMB2 to a Studio only after that Studio's pointer tables, capacities,
   and output composition are proven for all relevant payloads.

Code is shared only after independent static and runtime evidence establishes
equivalence. Similar bytes, matching addresses, or a common historical ancestor
are not sufficient promotion criteria.
