# ANN and SMB2 Source Overlap

`make later-engine-source-overlap` assembles the four ANN and SMB2 FDS program
roles with ca65 listings, retains only instructions emitted by the selected
profiles, and compares their instruction streams in source order. This avoids
false matches from inactive conditional branches, comments, labels, whitespace,
and relocated absolute operands.

The analysis has two normalization levels:

- **Opcode shape** retains the 6502 opcode and addressing mode while ignoring
  every operand value.
- **Opcode and immediates** additionally retains immediate constants while
  continuing to ignore relocated branch, call, and memory operands.

Only ordered continuous runs of at least 12 instructions count toward coverage.
The detailed machine-readable report is written to the ignored
`build/evidence/later_engine_source_overlap.json` file.

## Measured Result

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

## Architectural Consequence

ANN and SMB2 should be treated as revisions of one late FDS engine. Separate
payload identities and load addresses remain necessary, but duplicating the
complete implementation in an unrelated top-level SMB2 tree is no longer
justified by the source evidence.

The intended project layout is:

```text
src/
  revisions/
    ann/
      main.asm
      supplemental_courses.asm
      ending.asm
      hard_courses.asm
    smb2/
      main.asm
      supplemental_courses.asm
      ending.asm
      hard_courses.asm
  platforms/
    late_fds/
      common/
        system/
        game/
        rendering/
        audio/
      ann/
      smb2/
```

Implementation-bearing modules use `.asm`. The `.inc` extension is reserved
for constants, interfaces, macros, and other textual declarations that do not
form independently meaningful address-ordered modules.

The physical names `NSMDATA2`, `NSMDATA3`, `NSMDATA4`, `SM2DATA2`, `SM2DATA3`,
and `SM2DATA4` remain in FDS manifests, provenance, and container composition
because they are original disk-file identities. Source paths and entrypoint
scopes use `supplemental_courses`, `ending`, and `hard_courses` instead of
`data2`, `data3`, and `data4`.

Common extraction must follow the measured matching runs. Revision-specific
instructions should be isolated as complete modules or small explicit hooks;
the common tree must not become a large conditional source containing two
interleaved programs.

## Promotion Status

The first promotion covers the complete measured 168-instruction hard-course
run. The 75-instruction upside-down-pipe and piranha runtime is shared by both
course overlays of both revisions. The 87-instruction hard-course loader and
six-instruction checkpoint initializer are shared by ANN's hard courses and
SMB2 Worlds A-D, while their routing tables and checkpoint values remain owned
by the revisions.

These modules contain no ANN/SMB2 conditionals. Small declaration-only
interfaces bind the common semantic operands to each verified layout. Both
importer reproduction and release audits enforce the boundary, and all affected
payloads retain their original SHA-1 values.
