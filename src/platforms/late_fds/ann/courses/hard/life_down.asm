; ANN NSMDATA4 LIFE-DOWN EXTENSION

off_ann_life_down_extension_starts:
    .byte $76, $50, $d5, $70, $75, $b0, $00, $00

.include "shared_interface.inc"
.include "../../../common/game/hard_course_checkpoints.asm"

.assert * - off_ann_life_down_extension_starts = $14, error, "ANN DATA4 life-down extension must be 20 bytes"
