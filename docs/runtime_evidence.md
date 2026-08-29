# Runtime Evidence Scenarios

The runtime workflow replays a deterministic power-on FCEUX movie against the
byte-identical preservation ROM and records compact semantic events from named
source routines. Run the focused scenarios and their validator with:

```bash
make trace-runtime
```

The tracked input fixture is `movies/smb1_any_percent.fm2`, a public TASVideos
user file authored by DJ Incendration. It contains controller input only, not
ROM, CHR, screenshots, audio, or savestates. The scenario manifest pins both the
movie SHA-1 and preservation-ROM SHA-1 before FCEUX starts.
Its original title, source page, CC BY 2.0 license, byte identity, and checksum
are recorded in [`movies/README.md`](../movies/README.md).

## Natural Evidence

The same power-on input deterministically reproduces these World 1-1 events:

| Scenario | Semantic evidence | First frame |
| --- | --- | ---: |
| Title boot | `vec_nmi_handler` | 6 |
| World 1-1 start | `sub_game_core_routine` in game mode | 195 |
| Walking | Grounded horizontal displacement | 202 |
| Jumping | `handler_player_jumping_or_swimming` | 228 |
| Block impact | `sub_bump_block` | 304 |
| Coin collection | `sub_give_one_coin` | 304 |
| Pipe entry and exit | Vertical and side-pipe handlers | 570, 774 |
| Enemy stomp | `loc_enemy_stomped` | 1127 |
| Flagpole completion | Active flagpole state in `sub_flagpole_routine` | 1304 |

The `natural-longplay` scenario retains all 17,862 movie frames and periodic
state checkpoints as a broad mode, position, inventory, and progress regression.

## Controlled Evidence

The source movie does not naturally collect a power-up, lose a life, or expire
the game timer near the beginning of World 1-1. Those scenarios therefore
declare controlled RAM patches in their scenario manifests; the Lua capture
writes every changed address, old value, new value, and reason as a
`controlled_patch` event. The validator rejects missing, extra, or malformed
patches.

`power-up-collection` creates a fully active power-up in enemy slot five at
Mario's current coordinates. The ordinary object/collision pipeline then enters
`loc_handle_power_up_collision` at frame 252 and finishes with Super Mario
status. The patch proves the transaction from collision onward; it is not
evidence for natural block selection, emergence, or movement.

`death-respawn` selects the documented death handler and crosses its vertical
boundary after stable natural play. The ordinary dispatch sequence then enters
`handler_player_death`, `handler_player_lose_life`, and finally
`handler_player_entrance`, decrementing lives from two to one. It proves the
death/respawn transaction after the boundary patch; it is not evidence for a
natural enemy or pit collision.

Source Reconstruction 3.0 keeps later semantic experiments separate from the
frozen twelve-scenario Preservation Source 1.0 contract. Run its focused trace
with:

```bash
make trace-semantic-runtime
```

The `time-up-clear` scenario in
`scenarios/semantic_runtime_scenarios.json` sets the three displayed timer
digits to zero and releases the timer tick at frame 250. The ordinary engine
then enters player death at frame 252, decrements the life at frame 459, and
observes the timer-expired flag in `handler_display_time_up_screen` at frame
466. When the following world/lives screen replaces that message, the renderer
reads `off_time_up_clear_packet` at frame 597 and writes seven blank `$24` tiles
to `$220C..$2212` at frame 598. This resolves `DATA-001` without treating the
similar clear performed during startup as TIME UP evidence.

Generated CSV files remain under `build/runtime/` and
`build/evidence/runtime/`. Exact event frames and final state assertions live
beside patch declarations in the scenario manifests, so a contributor can
reproduce evidence without relying on prose or a saved emulator state.

## Complete Enemy-Stream Audit

Run the cross-profile static evidence gate with:

```bash
make audit-enemy-streams
```

The audit rebuilds every supported revision and platform, then decodes all 235
enemy streams: the shared cartridge/FDS layouts, the Vs. CHR-resident streams,
and ANN primary, supplemental, and extended course payloads. Exact stream and
record counts are manifest-owned. The current evidence covers 3,530 decoded
records and proves that no non-entrance record selects `$2E`.

This resolves `CODE-002`: `$2E` is `con_power_up_object`, but the accepted game
content creates power-ups through the dynamic block path rather than an enemy
stream. The retained comparison is therefore unreachable residual behavior for
all supported profiles. The claim deliberately excludes future custom content
that adds a stream object `$2E`.

`make semantic-evidence` composes the complete enemy-stream audit and the
focused Source Reconstruction 3.0 runtime scenarios.

## Residual-Code Reachability Audit

Run the canonical static proof with:

```bash
make audit-unreachable-code
```

The manifest-owned audit resolves `CODE-003`. It combines ca65's complete
symbol-reference metadata, a scan for raw little-endian target addresses across
the full PRG, and the exact terminating instruction before each candidate
entry. For `unused_misc_object_background_collision_setup`, both reference
counts are zero and the preceding block ends with an unconditional `JMP`.

The `unreachable-code-longplay` runtime scenario adds an execute trap at `$E392`
for the full 17,862-frame movie. The trap remains silent while the trace observes
the active miscellaneous-object bounding-box path at frame 304 and natural
hammer processing at frame 13,477. Runtime coverage supports the static proof;
it does not replace the complete reference and fallthrough analysis.

The same longplay resolves `RAM-001`. At frame 304 the first block transaction
selects slot zero and its current shuffled OAM offset `$A0`, then toggles the
selector from zero to one. At frame 8,953 the floating-score path independently
uses the selected block OAM region because its actor cannot reuse ordinary enemy
OAM. Exact event details are pinned in addition to event frames, matching the
static zero/one indexing and sole `EOR #$01` writer.

## Square-2 Audio Experiments

The `timer-tick-sfx` and `coin-sfx` scenarios start from the same cleared
square-2 effect state and inject only the documented request byte at frame 250.
Both enter the shared setup one frame later, but retain distinct initial duty
and length values:

| Scenario | `$4004..$4007` at frame 251 | Initial counter | Second tone | Channel release |
| --- | --- | ---: | --- | ---: |
| Timer tick | `$98,$7F,$71,$08` | `$06` | Never reaches `$30` | Frame 256 |
| Coin | `$8D,$7F,$71,$08` | `$35` | Counter `$30`, frame 256 | Frame 303 |

The validator requires the exact register tuple, counter values, and release
frames. It also forbids the timer scenario from emitting the coin-only
second-tone event. This resolves `SND-001`: sharing is intentional, while the
`$30` branch is reachable only for the longer coin envelope.

The natural longplay independently watches the area-music header path. Its
first header load writes `$08` and then `$00` to `ram_music_offset_square2` in
frame 37. A read trap is armed only between those exact writes and remains
silent for all 17,862 frames. This resolves `SND-002`: the first square-2 stream
read always sees zero, so the retained `$08` store is overwritten residual
behavior.
