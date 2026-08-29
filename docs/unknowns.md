# Unknowns Registry

This registry prevents uncertain interpretations from becoming source facts.
Each unresolved evidence tag in source or documentation references a stable ID
and the smallest useful next experiment.

## Status Vocabulary

- `Open` - mechanics or purpose remain uncertain
- `Resolved` - the recorded evidence is sufficient for the reference revision
- Confidence is `Low`, `Medium`, or `High`

### CODE-001 Residual gravity entry

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/game/physics/movement.asm`
- **Evidence:** `unused_gravity_block_entry` follows a completed routine and a
  data table. No direct operand or inline dispatch table points to it. Execution
  resumes at the following callable block-gravity entry.
- **Resolution:** Preserve the bytes and explicit `unused_` label. Do not delete
  or reinterpret them as an active block-gravity path.

### CODE-002 Enemy-stream residual range check

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/game/enemies/stream_and_initialization.asm`
- **Evidence:** The masked value is `con_power_up_object`, but power-ups are
  created by the dynamic block-object path rather than enemy-stream data.
  `make audit-enemy-streams` decodes 3,530 records from all 235 streams used by
  JU, PC10, PAL, Vs., FDS SMB, and the three ANN course sets. No non-entrance
  command selects `$2E`, so the equality branch cannot change control flow for
  any supported source profile.
- **Resolution:** Preserve the comparison as original residual behavior and
  mark it `!(UNUSED)`. Custom content that introduces a stream object `$2E`
  remains outside this evidence claim.

### CODE-003 Residual miscellaneous-object collision entry

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/game/collisions/bounding_boxes.asm`
- **Evidence:** `make audit-unreachable-code` finds no ca65 symbolic references
  and no raw little-endian `$E392` address anywhere in the canonical PRG. The
  preceding routine ends immediately before the entry with the unconditional
  `JMP $E3A5`, so execution cannot fall through. The full 17,862-frame trace
  traps execution at `$E392` without firing while observing the active
  miscellaneous-object bounding-box path at frame 304 and hammer processing at
  frame 13,477.
- **Resolution:** Preserve the bytes and `unused_` label as unreachable residual
  code. Its historical intended use remains unknown and is not needed for the
  reachability claim.

### CODE-004 Overwritten enemy sprite attribute write

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/game/enemies/special_behaviors.asm`
- **Evidence:** The written attribute byte is overwritten on every reachable
  path before actor rendering consumes it.
- **Resolution:** Preserve the instruction as original residual behavior and
  label the source comment `!(UNUSED)`.

### DATA-001 TIME UP clear packet

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/rendering/screens.asm`
- **Evidence:** The packet starts at offset `$16` within the world/lives display
  data and encodes a seven-byte repeat at VRAM `$220C`, the same address and
  length used by the one-player TIME UP text. The controlled `time-up-clear`
  trace expires the game timer at frame 250, enters the TIME UP screen path at
  frame 466, reads this packet at frame 597, and writes seven blank `$24` tiles
  to `$220C..$2212` at frame 598.
- **Resolution:** Name the offset `off_time_up_clear_packet` and document its
  exact PPU command. The bytes remain embedded in the world/lives packet because
  that later intermediate screen owns removal of the preceding TIME UP text.

### RAM-001 Block-object slot selector

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/game/modes.asm`
- **Evidence:** Every dedicated access uses the value as index zero or one into
  the two block-object arrays or their two OAM regions. The sole dedicated write
  is `EOR #$01` after a block transaction, alternating the next slot; generic
  game setup initially clears the byte. Vine setup copies from the selected
  block, while floating scores that cannot reuse enemy OAM select the same
  alternate region. The full runtime trace observes slot zero with shuffled OAM
  offset `$A0` and its `0 -> 1` toggle at frame 304, then observes an alternate
  floating-score OAM selection at frame 8,953.
- **Resolution:** Rename the field to `ram_block_object_slot`. It is not a
  title/demo control and it does not contain an OAM byte itself.

### SND-001 Timer-tick shared square-channel path

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/audio/sound_effects.asm`
- **Evidence:** Timer tick and coin intentionally share register setup and the
  continuation/decrement path. Isolated traces start both from a cleared square-2
  SFX state at frame 250. At frame 251 timer tick loads
  `$98,$7F,$71,$08` into `$4004..$4007` with counter `$06`, while coin loads
  `$8D,$7F,$71,$08` with counter `$35`. Timer tick releases the channel at frame
  256 without reaching `$30`; coin reaches `$30` at frame 256, writes its second
  tone, and releases the channel at frame 303.
- **Resolution:** The `$30` comparison belongs to the longer coin envelope. The
  six-frame timer tick safely reuses the shared path but can never take that
  branch.

### SND-002 Residual square-2 music offset store

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/audio/music_engine.asm`
- **Evidence:** The area-header search writes `$08` to
  `ram_music_offset_square2`, performs only the header-index loop and header-field
  loads, then writes `$00` before square-2 playback can read the offset. A memory
  watch observes the `$08 -> $00` pair in the same frame (first at frame 37),
  while a forbidden read trap remains silent through the full 17,862-frame
  movie and controlled event/SFX interruptions.
- **Resolution:** Preserve and mark the `$08` store as overwritten residual
  behavior. The effective square-2 stream offset always begins at zero after a
  header load.
