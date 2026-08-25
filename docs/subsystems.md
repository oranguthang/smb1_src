# System Architecture

This document is the subsystem-level map of the preservation source. It follows
the address-ordered execution and data flow without pretending that every
residual instruction has a known historical purpose.

## Reset, NMI, Input, and PPU Buffering

`vec_reset_handler` disables interrupts and decimal mode, initializes the stack,
waits for two vblanks, and chooses a warm- or cold-clear range. Warm boot is
accepted only when all six top-score digits are decimal and the validation byte
is `$A5`. Reset then initializes APU/PPU state, hides OAM, clears nametables, and
enables NMI before entering a permanent foreground loop.

`!(OBS)` `vec_nmi_handler` is the sole frame scheduler. Its stable order is:

1. Disable rendering and reset scroll state.
2. DMA CPU `$0200-$02FF` to OAM.
3. Submit the selected PPU update buffer and clear its header.
4. Restore the rendering mask.
5. Advance sound, read controllers, process pause, and update top score.
6. Advance timers, frame counter, and the seven-byte pseudorandom register.
7. Perform sprite-zero synchronization and sprite/OAM preparation when enabled.
8. Restore scroll and dispatch the active operating mode.
9. Re-enable NMI and return with `RTI`.

PPU writes outside reset are expressed as buffered command streams. NMI selects
the stream through `ram_vram_buffer_addr_ctrl`; `sub_update_screen` consumes it
while rendering is disabled. Gameplay code writes the buffer and never races
the visible-frame PPU directly.

## Operating Modes and Game Tasks

`sub_oper_mode_execution_tree` dispatches four top-level modes: title, game,
victory, and game over. Each mode owns a secondary task counter. Game mode then
uses `ram_game_engine_subroutine` to select entrance, ordinary control,
transformation, injury, death, and fire-flower tasks.

Title mode owns menu input, world select, demo startup, and the demo action
stream. Victory mode owns automatic walking, castle messages, retainers,
fireworks, and world advancement. Game-over mode handles timeout/start input and
two-player handoff. These are cooperative frame tasks: they update a small
state value and return to NMI rather than blocking.

## Scrolling, Screens, HUD, and Background Rendering

The screen task dispatcher builds palettes, text packets, title transfers, and
area setup over multiple frames. `sub_scroll_handler` derives player-relative
scroll, while the area parser produces one metatile column at a time.

`RenderAreaGraphics` expands the metatile buffer into four pattern-table indexes
per metatile and accumulates palette quadrants into attribute bytes. The result
is appended to a VRAM update buffer. The HUD uses decimal digit arrays in RAM;
score operations update those arrays first and emit display packets separately.

Palette rotation, block replacement, bridge removal, messages, and status output
all use the same buffered PPU ownership. `DATA-001` records the unresolved
identity of one short screen packet.

## Area and Enemy Streams

World/area tables select an area pointer, type, entrance control, and enemy
stream. Area object data is column-oriented. `sub_decode_area_data` separates
page control, row, object ID, and length information, and the area-object
dispatcher writes metatiles into the current column buffer. Loop commands can
rewind page/column progress for castle maze behavior.

Enemy streams are also page-relative. `sub_enemies_and_loops_core` compares the
next encoded position with the current screen window, handles page changes and
loop commands, finds a free enemy slot, and dispatches initialization by enemy
ID. The source keeps area streams and enemy streams as explicit byte data so
their encoded order remains reviewable. `CODE-002` tracks one residual range
check whose original purpose is not established.

## Gameplay Objects and Transactions

Fireballs, bubbles, blocks, brick chunks, coins, hammers, power-ups, vines,
jumpsprings, flagpole motion, warp zones, and the game timer share fixed object
slots rather than heap allocation. Each frame follows the same broad pattern:
initialize or spawn into a free slot, update state and fixed-point position,
resolve relevant collisions, select graphics, and retain or erase the slot.

Scoring is transaction-oriented. A collision or object event queues a sound,
updates score/coin digits, may spawn a floating number, and changes object state
before rendering consumes it. Block-buffer edits and their PPU packets are kept
together so visible tiles and collision state change coherently.

## Enemy Initialization and Runtime

Enemy IDs select initialization handlers for normal walkers, flying/swimming
actors, firebars, Bowser, grouped enemies, and platforms. Initialization fills
shared slot arrays for identity, state, position, speed, bounding-box control,
and graphics flags.

Runtime dispatch reads the same ID/state and selects movement or special
behavior. Common movement and gravity live in `game/physics/movement.asm`;
firebars, Lakitu/Spiny, Bowser, flame, bridge, goal, and platform behavior remain
in cohesive subsystem modules. Defeat changes state and usually reuses shared
gravity/horizontal motion rather than allocating a new object type.

`CODE-004` records an attribute write proven to be overwritten before rendering.
The instruction remains because preservation is byte-exact.

## Collision Systems

Collision work is layered:

- `bounding_boxes.asm` builds screen-relative boxes and performs generic overlap.
- `projectiles.asm` resolves fireball/enemy, hammer/player, and power-up contact.
- `actors.asm` resolves player/enemy, enemy/enemy, and player/platform contact.
- `player_background.asm` probes head, feet, and sides against the block buffer.
- `enemy_background.asm` applies metatile rules to enemies and fireballs.

Bounding boxes are derived from size-control tables, then clipped or adjusted by
offscreen state. Collision routines update gameplay state; renderer modules only
consume the resulting state. `CODE-003` tracks a residual miscellaneous-object
entry whose original caller is not yet proven.

## Sprite Composition and OAM

World coordinates are first converted to screen-relative positions and
offscreen bits. Actor renderers select tile/attribute layouts and write OAM
staging records under `$0200`. The player renderer selects action, size,
animation, and palette; enemy and miscellaneous renderers perform equivalent
ID/state dispatch.

Sprite shuffling rotates OAM offsets to distribute scanline overflow rather than
always hiding the same actor. Sprite zero is reserved for the status/playfield
split. NMI performs DMA before the next frame's mode logic, so gameplay prepares
the OAM image consumed on the following interrupt.

`RAM-001` tracks the exact title/demo role of one sprite-offset control field.

## Sound Effects and Music

`sub_sound_engine` runs once per NMI before controller sampling. Request queues
are copied into active buffers, and sound effects arbitrate square, triangle,
noise, and DMC control before the music handlers advance their streams.

Music headers provide per-channel offsets into shared byte streams. Channel
handlers decode note/rest values, length codes, envelopes, loop points, and
control events, then write APU shadow/output registers. Event music can replace
area music and later restore or restart it according to buffer state. Pause has
its own short tone sequence and suppresses normal progression where required.

`SND-001` records an unexplained shared timer-tick path. `SND-002` records a
possibly residual square-2 offset store that requires runtime observation.

## Fixed Data and Vectors

Level streams, enemy streams, metatile mappings, PPU packets, sprite layouts,
physics tables, music headers, note streams, envelopes, and sound-effect tables
remain in address order beside their owners or in cohesive data modules. The
linker isolates the six-byte vector segment at `$FFFA-$FFFF`; it points to
`vec_nmi_handler`, `vec_reset_handler`, and the preserved unused IRQ target.

Raw CHR pattern bytes are not source data. They remain an ignored, validated
local asset appended after the reproduced 32 KiB PRG.

## Principal Contracts

| Entry | Contract |
| --- | --- |
| `vec_reset_handler` | Establish a deterministic machine state and enable NMI |
| `vec_nmi_handler` | Own all vblank I/O and advance exactly one cooperative frame |
| `sub_dispatch_inline_handler` | Consume A as an inline word-table index and tail-enter the selected handler |
| `handler_player_control` | Run input, movement, scroll, bounds, and background collision transaction |
| `sub_area_parser_task_handler` | Advance one staged area-column parsing/rendering task |
| `sub_enemies_and_loops_core` | Consume eligible enemy commands and initialize fixed slots |
| `sub_bounding_box_core` | Materialize the selected actor box from relative position and size |
| `sub_sound_engine` | Arbitrate requests and advance all audio channels once per NMI |

Detailed player contracts and fixed-point behavior are in
`docs/player_movement.md`. Data codecs and formal binary round trips are owned
by milestone 8.
