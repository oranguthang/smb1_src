# Later-Engine Feasibility

This study decides whether Japanese Super Mario Bros. 2 / The Lost Levels can
remain a coherent profile of the SMB1 source reconstructed here. It does not add
the game to the supported build or authoring matrix.

Run `make later-engine-feasibility` with the three ignored original FDS images
named in `config/later_engine_feasibility.json`. The command verifies each whole
disk identity, parses the FDS records, and writes only hashes, sizes, addresses,
and comparison metrics to `build/evidence/later_engine_feasibility.json`. It
does not export ROM bytes into the tracked tree.

## Structural Evidence

FDS SMB1 uses four files. ANN and SMB2 instead use the same eight file IDs and
the same roles: license data, primary and supplemental CHR, a 32 KiB main
program, three dynamically loaded program overlays, and one save byte. Their
main program starts at `$6000`; DATA2 starts at `$C470`; and DATA3 starts at
`$C5D0`. SMB2 moves DATA4 from ANN's `$C296` to `$C2B4`, shortens the secondary
CHR record from 1,120 to 64 bytes, and moves the save byte from `$D2E3` to
`$D29F`.

The analyzer compares corresponding ANN/SMB2 file IDs with order-preserving
binary matching. Matching bytes can move, so this measures ancestry and
reusable reconstruction evidence; it does not claim identical behavior or
source boundaries.

| SMB2 payload | Bytes | ANN counterpart | Matching bytes | SMB2 coverage | Equal at the same CPU address |
| --- | ---: | --- | ---: | ---: | ---: |
| `SM2MAIN` | 32,768 | `NSMMAIN` | 27,054 | 82.6% | 3.5% |
| `SM2CHAR1` | 8,192 | `NSMCHAR1` | 7,063 | 86.2% | 87.9% |
| `SM2CHAR2` | 64 | `NSMCHAR2` | 20 | 31.3% | 10.9% |
| `SM2DATA2` | 3,631 | `NSMDATA2` | 1,000 | 27.5% | 5.0% |
| `SM2DATA3` | 3,279 | `NSMDATA3` | 2,262 | 69.0% | 27.0% |
| `SM2DATA4` | 3,916 | `NSMDATA4` | 2,725 | 69.6% | 12.9% |

Across all same-ID records, 40,349 of 52,075 SMB2 bytes have an
order-preserving ANN match. The license record and save byte match exactly.
The corresponding FDS SMB1 comparison covers only the shared 224-byte license
file by file ID; its best unconstrained matches are weaker and do not share the
later eight-file overlay architecture.

## Decision

SMB2 is a later-engine sibling, not another SMB1 profile. ANN is a strong bridge
for reconstructing it, but the low same-address ratios show that the program and
overlay layouts have already diverged. Folding these alternatives into the
current modules would spread large conditionals across gameplay, course loading,
audio, graphics, and FDS lifecycle code, weakening both engine reconstructions.

Source Reconstruction 3.0 therefore includes SMB2 through a separate sibling
source boundary rather than adding it as another SMB1 profile. The existing FDS
parser/composer, private-template policy, runtime harness, format tooling, and
ANN semantic work can be reused as infrastructure. Actual source, labels,
payload capacities, and runtime contracts remain SMB2-owned until any common
module is independently proven equivalent.

Any future reconstruction should begin with byte-identical builds of `SM2MAIN`,
`SM2DATA2`, `SM2DATA3`, and `SM2DATA4`, then derive semantic diffs against ANN.
Only routines proven equivalent in both source and behavior should move into a
shared module. Address equality, matching bytes, or compatible FDS file IDs are
not sufficient by themselves.

The subsequent ca65-normalized instruction comparison supplies that stronger
source evidence. See `docs/later_engine_source_overlap.md` for the measured
overlap and the planned consolidation of ANN and SMB2 as revisions of one late
FDS engine.
