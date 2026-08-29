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

The canonical music block also ends with three `$FF` bytes before the fixed
note-period table at `$FF00`. The tested music decoder proves that all three
channels finish by `$FEFD`, and the complete runtime suite observes no execution
of their replacement probes. They provide the second, audio-only budget.

The relocation candidate must insert one non-executed `$EA` byte at each of six
reviewed game/module boundaries and three audio boundaries. Success requires
all of the following:

- the generated candidate differs from the preservation PRG;
- labels in each shifted region move by the exact cumulative insertion count;
- absolute and indirect source references follow their semantic labels;
- the audio region remains fixed while the first six insertions are absorbed;
- the `$FF00..$FFF9` synthesis tables remain byte-identical and the vector
  slots remain fixed while their operands follow relocated handlers;
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
Run `make test-relocation` to generate, build, and statically validate the
canonical candidate under `build/relocation/`. `make validate-relocation` also
generates candidate debugger symbols and runs all deterministic scenarios with
execution traps on every inserted byte.

The cartridge revision and platform relocation matrices are complete. Vs. SMB,
FDS SMB, and ANN use profile-specific capacity contracts, container composition,
debug artifacts, focused runtime states, and execute traps. ANN additionally
builds relocated `NSMMAIN` first, generates its imported-symbol interface from
candidate debug labels, rebuilds `NSMDATA2`, `NSMDATA3`, and `NSMDATA4`, and
composes all four payloads into one candidate disk side. The overlay load
addresses remain fixed; their calls and pointers back into `NSMMAIN` follow the
candidate. See `docs/relocation_testing.md` for the exact boundary and commands.

Semantic evidence is also isolated from the frozen 1.0 runtime manifest.
`make semantic-evidence` audits every supported enemy stream and runs the
focused 3.0 emulator scenarios. The first two resolved claims prove that no
accepted stream selects the residual `$2E` power-up comparison and that the
four-byte packet embedded in the world/lives display clears the preceding
seven-tile TIME UP message.

The same aggregate gate proves selected residual code unreachable without
equating limited runtime coverage with absence. `make audit-unreachable-code`
requires zero symbolic and raw-address references plus a terminating predecessor
path; the complete movie then supplies an independent execute trap while active
miscellaneous objects and hammers are observed.

Runtime evidence also replaces the misleading generic sprite-offset name at
`$03EE` with `ram_block_object_slot`. Its only dedicated writer alternates zero
and one after block transactions, and the trace pins both the selected shuffled
OAM region and a later floating-score reuse of that region.

Two isolated square-2 experiments resolve the remaining audio unknowns. Timer
tick and coin begin from an identical cleared effect state, with exact register
writes, counters, second-tone reachability, and release frames pinned by the
scenario manifest. The complete longplay also proves that the residual `$08`
area-header offset is reset to zero before any square-2 stream read.

## Profile-Aware Authoring Contract

`config/content_authoring_profiles.json` is the Source 3.0 compatibility
boundary for the four Studios. It records all six selected game-build profiles,
their program load addresses and payload identities, isolated workspace and
output roots, and the availability of World, Level, Graphics, and Sound Studio.
Run `make list-content-profiles` for the current matrix and
`make content-profile-audit` to validate it.

JU, PC10, PAL, Vs. SMB, and FDS SMB1 now support every Studio through profile-specific
labels, fixed capacities, workspaces, and output images. PC10 preserves its
trailing 8 KiB container data; PAL uses its distinct level, physics, and
1,522-byte music range. The Sound Studio reads only headers emitted by the
selected build and models note-table operands as byte offsets, matching PAL's
valid odd offsets and the FDS `$6000` program load address.

FDS authoring keeps the disk container boundary explicit. The builder checks an
ignored, zeroed private template, fills program records 3 and 4 with source-built
`SMMAIN`, and fills CHR record 2 with the editable pattern table. Independent
hashes protect the template, original CHR, and complete disk side. The Level
Studio receives the profile's actual `.fds` output path for point playtesting.

Vs. authoring preserves its asymmetric 16 KiB CHR layout. Graphics Studio owns
only the first 8 KiB bank. The second bank contains 39 area streams and 39 enemy
streams whose addresses are selected through PRG pointer tables. The profile
resolver reads those tables from the source-built PRG, orders streams by their
physical CHR positions, recognizes the original shared-terminator case, and
keeps every fixed capacity stable. World routing and all 27 emitted music
headers come from the Vs. build. The Level Studio playtest also selects the
arcade-specific game mode and task numbers instead of assuming the console mode
tree.

`make check-content-profiles` exports disposable workspaces, constructs every
headless Studio model, and rebuilds all five accepted images. A zero-edit build
must match the manifest-owned image size and SHA-1. ANN remains planned with an
explicit blocker until its normal and extended content layouts are modeled.
The shared authoring layer already validates named supplemental payloads by
load address, size, and SHA-1; merges their linker labels; extracts CHR from the
private FDS template; and composes `NSMMAIN`, `NSMDATA2`, `NSMDATA3`, and
`NSMDATA4` into their original records. A zero-edit infrastructure probe
reconstructs the exact ANN disk SHA-1, but this container proof does not make
canonical level capacities safe for ANN. Keeping the profile planned prevents
the selector from applying those capacities to its overlay-based layout.
