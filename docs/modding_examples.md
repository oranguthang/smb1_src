# Modding Examples

This file keeps a few practical examples of small gameplay edits you can make
in `src/game/player/physics.asm` and the other subsystem modules.

## Changing Mario's Physics

Mario's physics are controlled by these data tables:

```asm
tbl_jump_vertical_force:
    .byte $20, $20, $1e, $28, $28, $0d, $04

tbl_fall_vertical_force:
    .byte $70, $70, $60, $90, $90, $0a, $09

tbl_initial_player_y_speed:
    .byte $fc, $fc, $fc, $fb, $fb, $fe, $ff

tbl_initial_player_y_move_force:
    .byte $00, $00, $00, $00, $00, $80, $00

tbl_maximum_left_speed:
    .byte $d8, $e8, $f0

tbl_maximum_right_speed:
    .byte $28, $18, $10
    .byte $0c  ; used for pipe intros

tbl_horizontal_friction:
    .byte $e4, $98, $d0
```

- **tbl_jump_vertical_force** - Controls jump arc decay when moving upward. Larger values = shorter jumps
- **tbl_fall_vertical_force** - Controls fall speed. Larger values = faster falling
- **tbl_initial_player_y_speed** - Initial jump force (negative signed value) based on running speed. Values below `$fa` result in very high jumps
- **tbl_maximum_left_speed** / **tbl_maximum_right_speed** - Running, walking, and water-walking speeds
- **tbl_horizontal_friction** - Friction applied at different speeds (fastest to slowest)

## Enabling Mid-Air Jumping

In `sub_update_player_physics`, replace:

```asm
    LDA SwimmingFlag  ; if swimming flag not set, jump to do something else
    BEQ bra_skip_jump_initialization  ; to prevent midair jumping, otherwise continue
```

With:

```asm
    NOP
    NOP
    NOP
    NOP
    NOP
```

This allows Mario to jump unlimited times in mid-air (like in the Air hack).

**Note:** You need exactly 5 `nop` instructions to match the byte count of the original code (`lda` = 3 bytes, `beq` = 2 bytes).

## Creating Reviving Goombas

In the enemy runtime data, modify:

```asm
RevivalRateData:
    .byte $10, $0b
```

The first value determines how long a stomped enemy takes to change state. Set it to `$0d` or lower to make Goombas revive after being stomped. The second value is used in Second Quest.
