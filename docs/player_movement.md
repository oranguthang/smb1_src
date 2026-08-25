# Player Movement and Physics

This document is the reference subsystem pass for player movement in the
preservation build. It describes the selected SMB1 revision only and keeps
static observations separate from later emulator-backed evidence.

## Frame Ownership

The movement transaction spans several address-ordered modules:

```text
NMI controller sample
  -> current-player input selection
  -> button-class split and scripted overrides
  -> state-specific physics and position integration
  -> scrolling, relative position, and bounding box
  -> player/background collision and state correction
```

`!(OBS)` `sub_read_joypads` shifts eight serial bits from each controller into
`ram_saved_joypad1_bits` and `ram_saved_joypad2_bits`. At the start of the game
core, the active player's byte is copied to `ram_saved_joypad_bits`.

`handler_player_control` divides that byte into A/B, up/down, and left/right
working fields. Scripted entrances call `sub_auto_control_player`, which writes
an artificial controller byte before entering the same handler. Water areas
also suppress input while the player is outside the playable vertical band.

After movement, the handler updates scrolling and relative coordinates, builds
the player bounding box, and calls `sub_player_bg_collision`. Collision owns
landing correction, head and side blocking, climbing acquisition, coin contact,
pipe entry, and the final movement-state correction for the frame.

## Input Edges

The active-low NES serial protocol is normalized into the following masks:

| Bit | Constant | Working field |
| ---: | --- | --- |
| 7 | `con_btn_a` | `ram_a_b_buttons` |
| 6 | `con_btn_b` | `ram_a_b_buttons` |
| 3 | `con_btn_up` | `ram_up_down_buttons` |
| 2 | `con_btn_down` | `ram_up_down_buttons` |
| 1 | `con_btn_left` | `ram_left_right_buttons` |
| 0 | `con_btn_right` | `ram_left_right_buttons` |

`!(OBS)` `ram_previous_a_b_buttons` is updated near the end of the game-engine
frame. Jump, swim-stroke, fireball, and jumpspring code therefore recognize a
new press when the current bit is set and the corresponding previous bit is
clear. Variable jump height keeps the jump gravity while A remains set in both
current and previous samples; releasing A selects fall gravity after at least
one pixel of upward displacement.

## Movement States

`sub_update_player_movement` dispatches `ram_player_state` through
`tbl_player_state_movement_handlers`:

| State | Handler | Responsibility |
| ---: | --- | --- |
| `$00` | `handler_player_on_ground` | Animation timing, facing, friction, and horizontal integration |
| `$01` | `handler_player_jumping_or_swimming` | Variable jump height, swim motion, air control, and vertical integration |
| `$02` | `handler_player_falling` | Select fall gravity, then use the shared airborne path |
| `$03` | `handler_player_climbing` | Vine-relative vertical motion and side switching |

Background collision starts most non-swimming frames in falling state and
restores state `$00` only after a valid feet collision. This makes landing a
collision result rather than a prediction made by the movement routine.

## Horizontal Motion

`sub_update_player_physics` selects the current speed limits and friction
increment. `sub_apply_player_horizontal_friction` updates the signed integer
speed byte and `ram_player_x_speed_fraction`; changing direction doubles the
selected friction value before applying it. The routine also records the
absolute speed used by jump-profile and animation selection.

The reference speed-limit bytes are interpreted by horizontal integration as a
signed 4.4 displacement:

| Profile | Left limit | Right limit | Approximate pixels/frame |
| ---: | ---: | ---: | ---: |
| 0 | `$D8` | `$28` | `-2.5 / +2.5` |
| 1 | `$E8` | `$18` | `-1.5 / +1.5` |
| 2 | `$F0` | `$10` | `-1.0 / +1.0` |
| Pipe intro | n/a | `$0C` | `+0.75` |

`sub_move_player_horizontally` selects player slot zero and enters the shared
object integrator. The speed's low nibble contributes fractional displacement;
its signed high nibble and the fractional carry update pixel and page position.
The returned signed integer displacement is copied to `ram_player_x_scroll`.

## Jump and Swimming Profiles

Jump initialization chooses one of five ground profiles from
`ram_player_x_speed_absolute`, or one of two water profiles:

| Index | Selection | Jump gravity | Fall gravity | Initial Y speed | Initial speed fraction |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | speed `$00-$08` | `$20` | `$70` | `$FC` (-4) | `$00` |
| 1 | speed `$09-$0F` | `$20` | `$70` | `$FC` (-4) | `$00` |
| 2 | speed `$10-$18` | `$1E` | `$60` | `$FC` (-4) | `$00` |
| 3 | speed `$19-$1B` | `$28` | `$90` | `$FB` (-5) | `$00` |
| 4 | speed `$1C-$FF` | `$28` | `$90` | `$FB` (-5) | `$00` |
| 5 | swimming | `$0D` | `$0A` | `$FE` (-2) | `$80` |
| 6 | whirlpool swimming | `$04` | `$09` | `$FF` (-1) | `$00` |

`!(OBS)` the gravity byte is added to the fractional velocity every frame. Its
carry changes the signed Y-speed byte. Position integration first accumulates
the fractional velocity in `ram_player_y_position_fraction`, then adds Y speed
and carry to the pixel/page coordinate. Downward player speed is capped at four
pixels per frame by the shared gravity routine.

## Climbing, Pipes, and Automatic Motion

Climbing uses a three-entry speed/fraction table selected from up/down input.
Horizontal input is intersected with `ram_player_collision_bits`; after the
side-switch timer expires, the player is moved to the other side of the vine
and facing is inverted.

Pipe and entrance code do not create a second physics path. They set scripted
controller bits, player state, collision-disable flags, or direct Y-axis deltas,
then re-enter the normal control and movement routines. Jumpsprings temporarily
block ordinary player integration and later install their own Y speed.

Injury and death are game-engine tasks rather than additional movement states.
The injury-blink task resumes `handler_player_control` during its active timer
window. The death task also enters the same handler after its initial delay;
task `$0B` bypasses fresh controller splitting, and airborne movement installs
the death-specific active gravity before vertical integration.

## Deterministic Static Trace

Run the default fastest-ground-jump trace with:

```text
make trace-player
```

The command parses the table bytes directly from `physics.asm`, models the
relevant 6502 carry and N-flag behavior, holds A for eight frames, and prints 24
frames. Selected reference rows are:

| Frame | A | Gravity | Absolute Y | Y speed | Speed fraction |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1 | `$28` | `$017B` | -5 | `$28` |
| 7 | 1 | `$28` | `$015C` | -4 | `$40` |
| 8 | 0 | `$90` | `$0158` | -4 | `$D0` |
| 14 | 0 | `$90` | `$014D` | 0 | `$30` |
| 23 | 0 | `$90` | `$0163` | 4 | `$00` |

The model has unit tests for source-table decoding, exact profile thresholds,
water selection, button-release gravity, fixed-point carry, and signed-speed
handling. It is a deterministic static reference, not yet an emulator trace;
milestone 6 will compare it with captured runtime RAM values.

## Source Map

| Responsibility | Source |
| --- | --- |
| Controller serial input | `src/system/hardware_io.asm` |
| Input split, automatic control, frame transaction | `src/game/core.asm` |
| State dispatch, jump profiles, friction | `src/game/player/physics.asm` |
| Shared fixed-point integration and gravity | `src/game/physics/movement.asm` |
| Player/background collision and pipe/climb ownership | `src/game/collisions/player_background.asm` |
| Fireballs, jumpsprings, vines, and flagpole motion | `src/game/objects/projectiles_and_interactions.asm` |
