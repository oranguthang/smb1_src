# Source Reconstruction 3.0

Source Reconstruction 3.0 develops the project beyond the stable, tagged
Source Reconstruction 2.0 contract. The 2.0 commit and tag remain immutable;
all 3.0 experiments use separate entrypoints, outputs, manifests, and
acceptance gates until their evidence is strong enough to become normal
project infrastructure.

## Priorities

The first priority is relocation evidence. The canonical Super Mario Bros.
program fills the complete 32 KiB NROM CPU window, so the Pac-Man relocation
test cannot be copied literally. The source already identifies six unused bytes
at `$F2CA..$F2CF`, immediately before the sound engine. They provide the first
relocation budget while the audio region remains fixed at `$F2D0`.

The canonical music block also ends with three candidate `$FF` bytes before the
fixed note-period table at `$FF00`. They provide a second, audio-only budget
only after the tested music decoder and emulator observation prove that no
supported playback path reads them as music data.

The relocation candidate must insert one non-executed `$EA` byte at each of six
reviewed game/module boundaries and three audio boundaries. Success requires
all of the following:

- the generated candidate differs from the preservation PRG;
- labels in each shifted region move by the exact cumulative insertion count;
- absolute and indirect source references follow their semantic labels;
- the audio region remains fixed while the first six insertions are absorbed;
- the `$FF00..$FFFF` synthesis tables and vectors remain fixed while the three
  audio insertions are absorbed;
- every insertion address is observed and never executed during the complete
  deterministic runtime suite;
- the normal source contains no relocation conditionals or probe bytes;
- `make verify` and the complete Source Reconstruction 2.0 gate remain intact.

Nine inserted bytes exercise independently shifted regions across the complete
game and audio engine. They are not a claim that the original ROM contains
general free space. The six source-declared unused bytes and three candidate
music-tail bytes are separate evidence classes. If the latter cannot be proved
disposable, the audio part of the fixed NROM experiment must fail closed and an
expanded-layout ADR must be written instead.

## Milestones

1. **Relocation architecture.** Record the immutable 2.0 predecessor, exact
   fixed ranges, candidate budget, generated-source boundary, and acceptance
   rules.
2. **Canonical relocation proof.** Build and statically validate the JU/NROM
   candidate, then run the existing debugger and gameplay evidence against it.
3. **Revision relocation matrix.** Extend only where each PC10 and PAL layout
   has independently proven capacity and fixed ranges. A shared address is not
   evidence of shared semantics.
4. **Platform relocation contracts.** Treat Vs., FDS SMB1, ANN main, and ANN
   overlays as distinct layouts. Profiles without safe capacity remain
   explicitly unsupported rather than receiving post-link byte patches.
5. **Platform interfaces.** Consolidate repeated revision selection behind
   small, responsibility-owned interfaces where this reduces conditionals
   without hiding original engine differences.
6. **Semantic and runtime evidence.** Resolve high-value unknowns and add
   behavior scenarios for claims that startup-only gates cannot establish.
7. **Profile-aware authoring.** Let the four Studios select compatible content
   profiles while keeping codecs, capacities, and build outputs manifest-owned.
8. **Later-engine feasibility.** Compare the ANN-derived engine with Japanese
   SMB2 / The Lost Levels. Produce an evidence-backed decision; do not promise
   a shared-source profile when a separate reconstruction would be clearer.
9. **Source Reconstruction 3.0 release.** Promote the release only after every
   accepted profile and tool is covered by aggregate static, byte-identity,
   round-trip, and runtime gates.

## Permanent Boundaries

- Source Reconstruction 2.0 remains reproducible from its annotated tag.
- Private ROMs, disk images, BIOS files, CHR, and extracted authored assets
  remain ignored local inputs.
- Generated relocation sources and binaries remain under `build/`.
- No executable code is hidden in extracted binary assets.
- Platform consolidation must preserve visible source-level alternatives when
  behavior genuinely differs.
- Evidence and inference retain separate documentation and naming treatment.

The development manifest is `config/source_reconstruction_3_0.json`. During
development, `make source-3-audit` validates the release boundary and milestone
state without pretending that the final 3.0 acceptance gate already exists.
