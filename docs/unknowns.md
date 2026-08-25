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

- **Status:** Open
- **Confidence:** Medium
- **Location:** `src/game/enemies/stream_and_initialization.asm`
- **Evidence:** The masked enemy-stream byte is compared with `$2E`; the
  surrounding path and original comments suggest an abandoned or earlier
  object-range check.
- **Experiment:** Trace every enemy-stream command in the reference levels and
  record whether the comparison can change control flow.

### CODE-003 Residual miscellaneous-object collision entry

- **Status:** Open
- **Confidence:** Medium
- **Location:** `src/game/collisions/bounding_boxes.asm`
- **Evidence:** The entry is retained next to miscellaneous-object bounding-box
  code, but no direct caller explains the original intended background-collision
  role.
- **Experiment:** Build a complete direct/indirect reference report and trace
  miscellaneous object slots during fireball, hammer, and power-up scenarios.

### CODE-004 Overwritten enemy sprite attribute write

- **Status:** Resolved
- **Confidence:** High
- **Location:** `src/game/enemies/special_behaviors.asm`
- **Evidence:** The written attribute byte is overwritten on every reachable
  path before actor rendering consumes it.
- **Resolution:** Preserve the instruction as original residual behavior and
  label the source comment `!(UNUSED)`.

### DATA-001 Possible TIME UP clear packet

- **Status:** Open
- **Confidence:** Low
- **Location:** `src/rendering/screens.asm`
- **Evidence:** Four bytes resemble a short PPU update packet, while the original
  comment only proposes that it may clear the TIME UP text.
- **Experiment:** Break on reads of the data address during timer-expiration and
  death transitions and capture the destination VRAM writes.

### RAM-001 Sprite-data offset control role

- **Status:** Open
- **Confidence:** Medium
- **Location:** `src/game/modes.asm`
- **Evidence:** `ram_spr_data_offset_ctrl` participates in the demo/title enemy
  setup path, but the exact bit-level contract is not documented.
- **Experiment:** Watch writes and reads during title, demo startup, and normal
  gameplay initialization, then compare resulting OAM allocation offsets.

### SND-001 Timer-tick shared square-channel path

- **Status:** Open
- **Confidence:** Medium
- **Location:** `src/audio/sound_effects.asm`
- **Evidence:** The timer-tick effect executes a comparison also used by another
  square-channel path; the branch mechanics are visible but the reason for
  sharing this point is not established.
- **Experiment:** Capture square-register writes for timer tick and the adjacent
  effect with the same initial channel state.

### SND-002 Residual square-2 music offset store

- **Status:** Open
- **Confidence:** Medium
- **Location:** `src/audio/music_engine.asm`
- **Evidence:** A store to `ram_music_offset_square2` is described as residual,
  but static source alone does not prove whether a later frame can observe it.
- **Experiment:** Trace the field across every music-header load and channel
  restart, including interrupted event music.
