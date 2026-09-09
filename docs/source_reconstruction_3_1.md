# Source Reconstruction 3.1

Source Reconstruction 3.1 is a compatible repository-modernization release.
Its project version remains 3.1, while its quality boundary follows the 2.x
line: it strengthens structure, evidence ownership, reproducibility, and
release metadata without introducing a new game profile, platform ABI,
relocation model, or sibling engine.

The predecessor is the published `source-reconstruction-3.0` tag at commit
`4b0d6f8`. All seven accepted profiles, their byte-identical outputs, direct
runtime coverage, relocation proofs, authoring workflows, and SMB2 sibling
source are inherited unchanged. Original ROMs, FDS images, BIOS data, CHR, and
extracted payloads remain ignored private inputs.

## Modernization Delta

- The root Makefile is a short stable interface. Workflow implementation lives
  in bounded files under `mk/`.
- Authoring, debugger, linker, reconstruction, and release configuration have
  explicit owners under `config/`.
- Tests mirror the `scripts/` responsibility packages and use package-aware
  discovery so identical package names cannot shadow production modules.
- `make help` exposes the principal public commands, while a command-level test
  protects that interface.
- The public 3.1 manifest is self-contained and records predecessor, scope,
  complete delta, profiles, runtime coverage, toolchain, artifacts, licensing,
  layout decisions, and aggregate gates.
- Lint rejects Cyrillic in current tracked public text. The release audit also
  checks new commit language, authorship, nonempty trees, message structure,
  and monotonic author and committer dates.
- Repository-layout evidence records every intentionally short ASM module and
  reviews each Python tool above the project threshold.
- Documentation-corpus evidence inventories each public Markdown document,
  records reader journeys and consolidation decisions, and reviews filename
  clusters and oversized documents.
- One configuration-owned label registry covers both reconstructed source
  families; workflow tools and tests consume its named sections.
- ANN supplemental and hard-course sources name generated assets independently
  of repository depth, while both assembly commands supply the validated cache
  as ca65's binary-include root. A disposable-project integration test exercises
  each production entrypoint independently from an absent default cache, and
  the ANN relocation manifest forwards the same root for both payload wrappers.

## Repository and Evidence Boundaries

`config/reconstruction/repository_layout.json` owns the measurable layout
policy. Short entrypoints, fixed vectors, declaration interfaces, and proven
shared adapters remain small because merging them would obscure their ABI or
address boundary. Large Python tools retain one public command only when their
domain transaction is cohesive and lower-level codecs or models are already
separate.

The historical 3.0 manifest remains readable from its tag. The current tree
removes superseded review metadata, but published commits and tags are not
rewritten. This release does not claim that historical blobs were erased; it
ensures all new or changed public content is English and self-contained.

## Verification

The quick structure-only gate does not require private ROMs:

```bash
make scaffold-check
```

The full release gate first reruns the complete published 3.0 gate, including
the inherited Preservation 1.0 and Source 2.0 gates, then validates the 3.1
layout, language, history, metadata, and pinned toolchain:

```bash
make source-3-1-check
```

`make source-2-minor-check` is the compatibility alias for the same gate.
Before tagging, `make source-3-1-pre-tag` additionally requires a clean rewrite
branch, a nonempty reviewed candidate commit, and absence of the future local tag.
After an annotated tag is published, `make source-3-1-post-tag` verifies its
message and peeled local/remote target.

The candidate is in `development` while the hard-course direct and relocation
assembly paths are corrected and the complete inherited gate is rerun from
clean generated state. Its commits retain neutral factual titles; the eventual
release milestone remains an owner-managed annotated tag rather than a
completion claim in commit history.
