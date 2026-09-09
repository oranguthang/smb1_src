# Later-Engine Evidence and Source Overlap

This study determines how Japanese Super Mario Bros. 2 / The Lost Levels
relates to the SMB1 source reconstructed here. It combines the initial
container-level feasibility evidence with the later instruction-level overlap
analysis so the architectural conclusion has one owner.

## Container Feasibility

Run `make later-engine-feasibility` with the three ignored original FDS images
named in `config/reconstruction/later_engine_feasibility.json`. The command
verifies each whole disk identity, parses the FDS records, and writes only
hashes, sizes, addresses, and comparison metrics to the ignored
`build/evidence/later_engine_feasibility.json`. It does not export ROM bytes
into the tracked tree.

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

This first pass established that SMB2 was not another SMB1 profile. ANN was a
strong bridge for reconstructing it, while the low same-address ratios required
separate payload identities, load addresses, and evidence. The FDS parser,
composer, private-template policy, runtime harness, and format tooling could be
reused without treating address equality or matching bytes as proof of shared
source.

## Instruction-Level Comparison

`make later-engine-source-overlap` assembles the four ANN and SMB2 FDS program
roles with ca65 listings, retains only instructions emitted by the selected
profiles, and compares their instruction streams in source order. This avoids
false matches from inactive conditional branches, comments, labels,
whitespace, and relocated absolute operands.

The analysis has two normalization levels:

- **Opcode shape** retains the 6502 opcode and addressing mode while ignoring
  every operand value.
- **Opcode and immediates** additionally retains immediate constants while
  continuing to ignore relocated branch, call, and memory operands.

Only ordered continuous runs of at least 12 instructions count toward coverage.
The detailed machine-readable report is written to the ignored
`build/evidence/later_engine_source_overlap.json` file.

| Program role | ANN instructions | SMB2 instructions | Opcode-shape coverage | Immediate-preserving coverage | Longest run |
| --- | ---: | ---: | ---: | ---: | ---: |
| Main engine | 11,105 | 11,129 | 98.41% / 98.19% | 96.90% / 96.69% | 1,020 |
| Supplemental courses | 89 | 142 | 84.27% / 52.82% | 84.27% / 52.82% | 75 |
| Ending | 615 | 613 | 87.64% / 87.93% | 83.41% / 83.69% | 369 |
| Hard courses | 182 | 235 | 92.31% / 71.49% | 92.31% / 71.49% | 168 |

Percentages are reported as ANN / SMB2 because the supplemental and hard-course
SMB2 programs contain an additional 67-instruction wind and upside-down-pipe
extension. The shared 75- and 168-instruction prefixes end at `$C4FD`; the SMB2
extension begins at `$C4FE`.

The main programs are not merely related at the binary-container level. Their
assembled instruction order is almost identical. The largest immediate-stable
runs cover 1,007 instructions at ANN `$9716` / SMB2 `$9712`, 993 instructions at
ANN `$A01C` / SMB2 `$A01F`, and 768 instructions at ANN `$B8FA` / SMB2 `$B8EA`.
The remaining differences are small title, warp, area-selection, block-item,
and wind-specific intervals rather than separate engines.

## Architectural Decision

ANN and SMB2 are revisions of one late-FDS engine. Separate payload identities
and load addresses remain necessary, but duplicating the complete
implementation in an unrelated top-level SMB2 tree is not justified by the
source evidence.

The project layout places revision entrypoints under `src/revisions/ann/` and
`src/revisions/smb2/`, shared implementation under
`src/platforms/late_fds/common/`, and revision-owned integration under the
corresponding `ann/` and `smb2/` platform directories. Implementation-bearing
modules use `.asm`; `.inc` is reserved for declarations that do not form
independently meaningful address-ordered modules.

The physical names `NSMDATA2`, `NSMDATA3`, `NSMDATA4`, `SM2DATA2`, `SM2DATA3`,
and `SM2DATA4` remain in FDS manifests, provenance, and container composition
because they are original disk-file identities. Source paths and entrypoint
scopes use `supplemental_courses`, `ending`, and `hard_courses` instead of
`data2`, `data3`, and `data4`.

Common extraction follows measured matching runs. Revision-specific
instructions remain complete modules or small explicit hooks; the common tree
does not interleave the two programs through broad conditionals.

The first promotion covers the complete measured 168-instruction hard-course
run. The 75-instruction upside-down-pipe and piranha runtime is shared by both
course overlays of both revisions. The 87-instruction hard-course loader and
six-instruction checkpoint initializer are shared by ANN's hard courses and
SMB2 Worlds A-D, while routing tables and checkpoint values remain
revision-owned. These modules contain no ANN/SMB2 conditionals. Declaration-only
interfaces bind common semantic operands to each verified layout, and both the
importer and release audits enforce the boundary while preserving every payload
SHA-1.
