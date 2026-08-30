; ANN OVERLAY GAMEPLAY EXTENSIONS

con_ann_piranha_plant_b_object = $04
con_ann_spring_special_acceleration = $e0

.include "shared_interface.inc"
.include "../../common/gameplay/upside_down_pipe.asm"

sub_ann_hard_mode_spring:
    LDY ram_world_number
    CPY #$01
    BEQ bra_use_ann_special_spring_acceleration
    CPY #$02
    BNE bra_exit_ann_hard_mode_spring

bra_use_ann_special_spring_acceleration:
    LDA #con_ann_spring_special_acceleration

bra_exit_ann_hard_mode_spring:
    RTS

sub_ann_hard_mode_render_spring:
    LDY ram_world_number
    CPY #$01
    BEQ bra_shift_ann_spring_render_frame
    CPY #$02
    BNE bra_exit_ann_hard_mode_render_spring

bra_shift_ann_spring_render_frame:
    LSR

bra_exit_ann_hard_mode_render_spring:
    RTS

.assert * - handler_late_fds_upside_down_pipe_high = $a9, error, "ANN overlay gameplay code must be 169 bytes"
