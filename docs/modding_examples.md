# Modding Examples

This file keeps a few practical examples of small gameplay edits you can make in `src/smbdis.asm`.

## Changing Mario's Physics

Mario's physics are controlled by data tables starting around line 6016:

```asm
JumpMForceData:
      .byte $20, $20, $1e, $28, $28, $0d, $04

FallMForceData:
      .byte $70, $70, $60, $90, $90, $0a, $09

PlayerYSpdData:
      .byte $fc, $fc, $fc, $fb, $fb, $fe, $ff

InitMForceData:
      .byte $00, $00, $00, $00, $00, $80, $00

MaxLeftXSpdData:
      .byte $d8, $e8, $f0

MaxRightXSpdData:
      .byte $28, $18, $10
      .byte $0c ;used for pipe intros

FrictionData:
      .byte $e4, $98, $d0
```

- **JumpMForceData** - Controls jump arc decay when moving upward. Larger values = shorter jumps
- **FallMForceData** - Controls fall speed. Larger values = faster falling
- **PlayerYSpdData** - Initial jump force (negative signed value) based on running speed. Values below `$fa` result in very high jumps
- **MaxLeftXSpdData** / **MaxRightXSpdData** - Running, walking, and water-walking speeds
- **FrictionData** - Friction applied at different speeds (fastest to slowest)

## Enabling Mid-Air Jumping

Around lines 6076-6077, replace:

```asm
lda SwimmingFlag           ;if swimming flag not set, jump to do something else
beq NoJump                 ;to prevent midair jumping, otherwise continue
```

With:

```asm
nop
nop
nop
nop
nop
```

This allows Mario to jump unlimited times in mid-air (like in the Air hack).

**Note:** You need exactly 5 `nop` instructions to match the byte count of the original code (`lda` = 3 bytes, `beq` = 2 bytes).

## Creating Reviving Goombas

Around line 11495, modify:

```asm
RevivalRateData:
      .byte $10, $0b
```

The first value determines how long a stomped enemy takes to change state. Set it to `$0d` or lower to make Goombas revive after being stomped. The second value is used in Second Quest.
